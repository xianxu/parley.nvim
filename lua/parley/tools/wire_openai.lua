--------------------------------------------------------------------------------
-- OpenAI function-calling wire protocol (#198).
--
-- Peer to lua/parley/tools/wire_anthropic.lua; see that file for the
-- contract a wire module implements. Used by the `openai` adapter, by
-- copilot / azure / ollama, and by cliproxyapi's OpenAI route.
--
-- Three things differ from the Anthropic wire, and each is a function here:
--
--   ENCODE     tools go in a `function` envelope, and the schema field is
--              called `parameters` rather than `input_schema`.
--
--   DECODE     streamed tool calls arrive as an ARRAY of partial
--              `delta.tool_calls[]` entries. `id` and `function.name` appear
--              only in the first chunk for a given array index; the
--              `function.arguments` JSON accumulates as string fragments;
--              and — unlike Anthropic's content_block_start/_stop framing —
--              NOTHING closes an individual call.
--
--   MESSAGES   an assistant turn carries `tool_calls[]` alongside its text,
--              and each result comes back as its own `{role = "tool"}`
--              message rather than as content blocks inside a user turn.
--              translate_messages bridges parley's internal (Anthropic-
--              shaped) message list to that.
--
-- Wire shapes verified against captured bytes from cliproxyapi 7.2.110 /
-- gpt-5.6-sol, kept as tests/fixtures/openai_*.sse.
--
-- PURE: no IO, no Neovim state beyond vim.json.
--------------------------------------------------------------------------------

local sse = require("parley.sse")

local M = {}

--------------------------------------------------------------------------------
-- Encode
--------------------------------------------------------------------------------

--- Convert parley ToolDefinitions into OpenAI `tools` entries.
---
--- Internal fields (handler, kind, needs_backup) are dropped — same contract
--- as the Anthropic encoder, different envelope.
---
--- An absent or empty schema becomes `vim.empty_dict()`: an empty Lua table
--- JSON-encodes as `[]`, and OpenAI rejects an array where an object schema
--- belongs.
---@param tool_definitions ToolDefinition[]|nil
---@return table[] openai_tools
function M.encode_tools(tool_definitions)
    local out = {}
    for _, def in ipairs(tool_definitions or {}) do
        local parameters = def.input_schema
        if type(parameters) ~= "table" or not next(parameters) then
            parameters = vim.empty_dict()
        end
        table.insert(out, {
            type = "function",
            -- `function` is a Lua keyword; bracket syntax is required.
            ["function"] = {
                name = def.name,
                description = def.description,
                parameters = parameters,
            },
        })
    end
    return out
end

--- Compel a specific tool this turn. OpenAI spells this with the same
--- `function` envelope it uses for definitions.
---@param tool_name string
---@return table
function M.encode_tool_choice(tool_name)
    return { type = "function", ["function"] = { name = tool_name } }
end

--------------------------------------------------------------------------------
-- Decode
--------------------------------------------------------------------------------

--- Walk a captured OpenAI SSE response and extract client-side tool calls
--- as normalized ToolCall tables ({id, name, input}).
---
--- Assembly rules, from the captured wire:
---   * `choices[1].delta.tool_calls` is a list; each entry's `index` keys it
---     to one logical call, so parallel calls interleave freely.
---   * `id` and `function.name` arrive once, in that call's first chunk.
---   * `function.arguments` is a STRING accumulated across chunks; it parses
---     to the call's input only once complete.
---
--- Deliberately NOT gated on `finish_reason == "tool_calls"`. A truncated
--- stream still yields whatever assembled, and tool_loop already writes
--- synthetic error results for calls it cannot resolve. Gating would drop
--- them silently and strand the buffer with an unmatched tool_use block.
---
--- Never raises: malformed JSON in `arguments` yields an empty input rather
--- than an error, because this runs mid-chat on whatever the network gave us.
---@param raw_response string the full captured SSE response
---@return ToolCall[]
function M.decode_tool_calls_from_stream(raw_response)
    if type(raw_response) ~= "string" or raw_response == "" then
        return {}
    end

    -- index -> { id, name, parts = {} }
    local by_index = {}
    -- Index order of FIRST appearance, so the returned list follows the
    -- stream rather than numeric index. Matches wire_anthropic's contract
    -- and survives a provider that emits indices out of order.
    local order = {}

    for line in raw_response:gmatch("[^\n]+") do
        -- Only `data:` lines carry JSON payloads.
        if line:sub(1, 6) == "data: " then
            local decoded = sse.safe_json_decode(sse.strip_data_prefix(line))
            local choice = type(decoded) == "table"
                and type(decoded.choices) == "table"
                and decoded.choices[1]
            local tool_calls = type(choice) == "table"
                and type(choice.delta) == "table"
                and choice.delta.tool_calls

            if type(tool_calls) == "table" then
                for _, tc in ipairs(tool_calls) do
                    local idx = tc.index or 0
                    local state = by_index[idx]
                    if not state then
                        state = { parts = {} }
                        by_index[idx] = state
                        table.insert(order, idx)
                    end

                    if tc.id then
                        state.id = tc.id
                    end

                    local fn = tc["function"]
                    if type(fn) == "table" then
                        if fn.name then
                            state.name = fn.name
                        end
                        if type(fn.arguments) == "string" then
                            table.insert(state.parts, fn.arguments)
                        end
                    end
                end
            end
        end
    end

    local completed = {}
    for _, idx in ipairs(order) do
        local state = by_index[idx]
        local input = {}
        local full_json = table.concat(state.parts)
        if full_json ~= "" then
            local ok, parsed = pcall(vim.json.decode, full_json)
            if ok and type(parsed) == "table" then
                input = parsed
            end
        end
        table.insert(completed, {
            id = state.id,
            name = state.name,
            input = input,
        })
    end

    return completed
end

--- Did this stream carry a client tool call at all? Cheap plain-text probe,
--- not a parse. See wire_anthropic.has_tool_calls for why it exists.
---@param raw_response string
---@return boolean
function M.has_tool_calls(raw_response)
    return type(raw_response) == "string"
        and raw_response:find('"tool_calls"', 1, true) ~= nil
end

return M
