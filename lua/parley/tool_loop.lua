-- Tool loop driver for parley's client-side tool-use support.
--
-- This is the glue layer that ties together the independently-tested
-- pieces of M2 into a single "received an SSE response, turn it into
-- a 🔧:/📎: round-trip" operation:
--
--   providers.decode_anthropic_tool_calls_from_stream (Task 2.4)
--     → extracts ToolCalls from the captured raw SSE response
--
--   tools.dispatcher.execute_call (Task 2.3)
--     → cwd-scope check, pcall-guarded handler invocation,
--       truncation, id/name stamping
--
--   tools.serialize.render_call / render_result (Task 2.1)
--     → turns a ToolCall / ToolResult into buffer-ready block text
--
-- chat_respond (Task 2.7) calls process_response in its on_exit
-- callback after each streamed response. If the stream contained
-- tool_use blocks, process_response writes 🔧: and 📎: to the
-- buffer and returns "recurse" — chat_respond then re-submits the
-- updated buffer to continue the conversation. Otherwise it returns
-- "done" and the normal finalization runs (user prompt append,
-- topic generation, cursor placement).
--
-- M2 ships with a hard single-recursion cap inside chat_respond;
-- M4 Task 4.1 lifts that cap using the per-buf iteration counter
-- this module exposes and adds a synthetic `(iteration limit
-- reached)` 📎: result when the cap fires inside process_response
-- instead of silently stopping.
--
-- State is module-level and keyed by bufnr. NO globals.

local M = {}

-- Per-buffer state: { iter = number }
local state_by_buf = {}

--------------------------------------------------------------------------------
-- State accessors (used by chat_respond and M4 lualine indicator)
--------------------------------------------------------------------------------

--- Returns the current iteration count for a buffer (0 for a fresh
--- buffer that hasn't seen a tool round yet).
--- @param bufnr integer
--- @return integer
function M.get_iter(bufnr)
    local s = state_by_buf[bufnr]
    return s and s.iter or 0
end

--- Increment the iteration counter for a buffer.
--- @param bufnr integer
function M.increment_iter(bufnr)
    state_by_buf[bufnr] = state_by_buf[bufnr] or { iter = 0 }
    state_by_buf[bufnr].iter = state_by_buf[bufnr].iter + 1
end

--- Clear all state for a buffer (called on tool-loop-done and
--- whenever the caller wants to start fresh).
--- @param bufnr integer
function M.reset(bufnr)
    state_by_buf[bufnr] = nil
end

--------------------------------------------------------------------------------
-- Buffer append
--------------------------------------------------------------------------------

--- Write synthetic 📎: results for a list of tool_calls that won't be
--- executed (iteration cap or cancellation). Each tool_use gets a 🔧:
--- block AND a matching 📎: with the given reason, preserving the
--- buffer-is-valid-transcript invariant.
function M._write_synthetic_results(bufnr, tool_calls, model, exchange_idx, reason)
    for _, call in ipairs(tool_calls) do
        M._append_section_to_answer(bufnr, model, exchange_idx, {
            kind = "tool_use",
            id = call.id,
            name = call.name,
            input = call.input,
        })
        M._append_section_to_answer(bufnr, model, exchange_idx, {
            kind = "tool_result",
            id = call.id,
            name = call.name,
            content = reason,
            is_error = true,
        })
    end
end

--- Repair unmatched 🔧: blocks in the buffer after cancellation.
--- Scans the active exchange for tool_use blocks without a following
--- tool_result and writes synthetic 📎: results for them.
--- @param bufnr integer
function M.repair_unmatched_tool_blocks(bufnr)
    local chat_parser = require("parley.chat_parser")
    local exchange_model_mod = require("parley.exchange_model")
    local cfg = require("parley.config")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local header_end = chat_parser.find_header_end(lines) or 0
    local parsed = chat_parser.parse_chat(lines, header_end, cfg)
    local model = exchange_model_mod.from_parsed_chat(parsed)

    -- Find the last exchange with an answer
    local ex_idx = nil
    for i = #model.exchanges, 1, -1 do
        if #model.exchanges[i].blocks > 1 then
            ex_idx = i
            break
        end
    end
    if not ex_idx then return end

    -- Scan blocks: every tool_use must be followed by a tool_result
    local blocks = model.exchanges[ex_idx].blocks
    local serialize = require("parley.tools.serialize")
    for i, blk in ipairs(blocks) do
        if blk.kind == "tool_use" then
            -- Check if next block is a tool_result
            local next_blk = blocks[i + 1]
            if not next_blk or next_blk.kind ~= "tool_result" then
                -- Unmatched — read the tool_use to get id/name
                local start_line = model:block_start(ex_idx, i)
                local end_line = model:block_end(ex_idx, i)
                local buf_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
                local text = table.concat(buf_lines, "\n")
                local parsed_call = serialize.parse_call(text)
                if parsed_call then
                    M._append_section_to_answer(bufnr, model, ex_idx, {
                        kind = "tool_result",
                        id = parsed_call.id,
                        name = parsed_call.name,
                        content = "(cancelled by user)",
                        is_error = true,
                    })
                end
            end
        end
    end

    M.reset(bufnr)
end

--- Append a section to the active exchange's answer using the exchange
--- model for position computation. Inserts at model:answer_append_pos(),
--- which is always INSIDE the active answer region — never past the
--- placeholder 💬: of the next exchange.
---
--- @param bufnr integer
--- @param model ExchangeModel  from exchange_model.from_parsed_chat or state
--- @param exchange_idx integer  1-based exchange index
--- @param section table {kind, ...kind-specific fields}
function M._append_section_to_answer(bufnr, model, exchange_idx, section)
    local buffer_edit = require("parley.buffer_edit")
    local render_buffer = require("parley.render_buffer")
    local lines = render_buffer.render_section(section)
    model:add_block(exchange_idx, section.kind, #lines)
    local blk_idx = #model.exchanges[exchange_idx].blocks
    local pos = model:block_start(exchange_idx, blk_idx)
    -- Insert margin + content. The model's block_start is where
    -- the content goes; the margin is one line before it.
    local insert_lines = { "" }  -- margin blank
    for _, l in ipairs(lines) do
        table.insert(insert_lines, l)
    end
    buffer_edit.insert_lines_at(bufnr, pos - 1, insert_lines)
end

--------------------------------------------------------------------------------
-- The driver
--------------------------------------------------------------------------------

--- Process the raw SSE response from a completed Anthropic streaming
--- call. Decodes tool_use blocks, executes each via the dispatcher,
--- and writes 🔧: / 📎: blocks into the buffer in streaming order.
---
--- Returns one of:
---   "done"    — no tool_use in the response (plain text reply),
---               OR iteration cap hit. Caller (chat_respond) should
---               continue with normal finalization (write user
---               prompt at end, topic gen, cursor placement).
---   "recurse" — tool blocks were written. Caller should re-invoke
---               chat_respond on the same buffer to continue the
---               conversation.
---
--- @param bufnr integer the chat buffer
--- @param raw_response string the captured SSE stream from qt.raw_response
--- @param agent_info table|nil { max_tool_iterations, tool_result_max_bytes, cwd? }
--- @param live_model Model|nil  live exchange_model from chat_respond (preferred)
--- @param exchange_idx integer|nil  active exchange index (required when live_model is passed)
--- @return "done"|"recurse"
function M.process_response(bufnr, raw_response, agent_info, live_model, exchange_idx)
    agent_info = agent_info or {}

    local providers = require("parley.providers")
    local tool_calls = providers.decode_anthropic_tool_calls_from_stream(raw_response or "")

    if #tool_calls == 0 then
        -- Plain-text response. Tool loop is done for this submission.
        M.reset(bufnr)
        return "done"
    end

    -- Use the live model from chat_respond if provided. Otherwise
    -- fall back to rebuilding from the buffer (backward compat for
    -- callers that don't pass a model).
    local model = live_model
    local active_exchange_idx = exchange_idx
    if not model then
        local chat_parser = require("parley.chat_parser")
        local exchange_model_mod = require("parley.exchange_model")
        local cfg = require("parley.config")
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local header_end = chat_parser.find_header_end(lines) or 0
        local parsed = chat_parser.parse_chat(lines, header_end, cfg)
        model = exchange_model_mod.from_parsed_chat(parsed)
        -- Find the active exchange (last one with an answer).
        for i = #model.exchanges, 1, -1 do
            -- An exchange has an answer if it has more than just the question block
            if #model.exchanges[i].blocks > 1 then
                active_exchange_idx = i
                break
            end
        end
    end
    if not active_exchange_idx then
        M.reset(bufnr)
        return "done"
    end

    -- Iteration cap check (after model setup so we can write synthetic results).
    local max_iter = agent_info.max_tool_iterations or 20
    if M.get_iter(bufnr) >= max_iter then
        M._write_synthetic_results(bufnr, tool_calls, model, active_exchange_idx,
            "(iteration limit reached — max " .. max_iter .. " rounds)")
        M.reset(bufnr)
        return "done"
    end

    -- Execute each tool call and write 🔧:/📎: blocks in streaming order.
    local dispatcher = require("parley.tools.dispatcher")
    local registry = require("parley.tools")

    local exec_opts = {
        cwd = agent_info.cwd or vim.fn.getcwd(),
        max_bytes = agent_info.tool_result_max_bytes or 102400,
    }

    for _, call in ipairs(tool_calls) do
        -- 🔧: section for the tool_use
        M._append_section_to_answer(bufnr, model, active_exchange_idx, {
            kind = "tool_use",
            id = call.id,
            name = call.name,
            input = call.input,
        })

        -- Execute the tool via the dispatcher (handles cwd-scope,
        -- pcall-guard, truncation, id/name stamping). A raising or
        -- misbehaving handler still returns a well-shaped
        -- is_error=true ToolResult so the buffer stays in a valid
        -- state.
        local result = dispatcher.execute_call(call, registry, exec_opts)

        -- 📎: section for the tool_result
        M._append_section_to_answer(bufnr, model, active_exchange_idx, {
            kind = "tool_result",
            id = result.id,
            name = result.name,
            content = result.content,
            is_error = result.is_error,
        })
    end

    M.increment_iter(bufnr)
    return "recurse"
end

return M
