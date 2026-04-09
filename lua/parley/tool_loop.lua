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

--- Append a multi-line block of text to the end of a buffer. Ensures
--- there is a blank line separator between the existing content and
--- the new block so serialized 🔧:/📎: blocks don't concatenate onto
--- trailing non-empty lines.
---
--- @param bufnr integer
--- @param block string multi-line text (no trailing newline required)
function M._append_block_to_buffer(bufnr, block)
    local last = vim.api.nvim_buf_line_count(bufnr)
    local last_line = vim.api.nvim_buf_get_lines(bufnr, math.max(last - 1, 0), last, false)[1] or ""

    local lines_to_insert = {}
    if last_line:match("%S") then
        table.insert(lines_to_insert, "")
    end
    -- Split the block on newlines. `block .. "\n"` ensures the final
    -- line is captured by the ([^\n]*)\n pattern even when block has
    -- no trailing newline.
    for line in (block .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines_to_insert, line)
    end

    vim.api.nvim_buf_set_lines(bufnr, last, last, false, lines_to_insert)
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
--- @return "done"|"recurse"
function M.process_response(bufnr, raw_response, agent_info)
    agent_info = agent_info or {}

    local providers = require("parley.providers")
    local tool_calls = providers.decode_anthropic_tool_calls_from_stream(raw_response or "")

    if #tool_calls == 0 then
        -- Plain-text response. Tool loop is done for this submission.
        M.reset(bufnr)
        return "done"
    end

    -- Iteration cap guard. M2 ships with a hard single-recursion cap
    -- enforced inside chat_respond; this check is defensive and M4
    -- Task 4.1 is where the cap check becomes authoritative.
    local max_iter = agent_info.max_tool_iterations or 20
    if M.get_iter(bufnr) >= max_iter then
        -- TODO(M4): synthesize a "(iteration limit reached)" 📎:
        -- result here for the last unmatched 🔧: so the LLM sees
        -- the cap explicitly on resubmit. For now, just stop.
        M.reset(bufnr)
        return "done"
    end

    -- Execute each tool call and write 🔧:/📎: blocks in streaming order.
    local dispatcher = require("parley.tools.dispatcher")
    local registry = require("parley.tools")
    local serialize = require("parley.tools.serialize")

    local exec_opts = {
        cwd = agent_info.cwd or vim.fn.getcwd(),
        max_bytes = agent_info.tool_result_max_bytes or 102400,
    }

    for _, call in ipairs(tool_calls) do
        -- 🔧: block for the tool_use
        local use_block = serialize.render_call(call)
        M._append_block_to_buffer(bufnr, use_block)

        -- Execute the tool via the dispatcher (handles cwd-scope,
        -- pcall-guard, truncation, id/name stamping). A raising or
        -- misbehaving handler still returns a well-shaped
        -- is_error=true ToolResult so the buffer stays in a valid
        -- state.
        local result = dispatcher.execute_call(call, registry, exec_opts)

        -- 📎: block for the tool_result
        local result_block = serialize.render_result(result)
        M._append_block_to_buffer(bufnr, result_block)
    end

    M.increment_iter(bufnr)
    return "recurse"
end

return M
