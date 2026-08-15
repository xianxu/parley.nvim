--------------------------------------------------------------------------------
-- Anthropic tool-use wire protocol.
--
-- One of the wire modules behind lua/parley/tools/wire.lua. A wire owns
-- everything about how ONE provider family expresses client-side tool use
-- on the network: how tool definitions are encoded into a request, how a
-- forced tool choice is expressed, and how tool calls are read back out of
-- a streamed response.
--
-- Extracted from providers.lua in #198, when a second wire (wire_openai)
-- made the protocol worth separating from adapter concerns (headers,
-- payload assembly, usage parsing). The bodies here are a verbatim move —
-- the pre-existing anthropic tool specs are unchanged and still pass,
-- which is the proof.
--
-- Contract a wire module implements:
--   encode_tools(ToolDefinition[])        -> provider `tools` entries
--   encode_tool_choice(string)            -> provider `tool_choice` value
--   decode_tool_calls_from_stream(string) -> ToolCall[] {id, name, input}
--   has_tool_calls(string)                -> boolean
--   translate_messages(table[])           -> table[]   (OPTIONAL; only
--       wires whose message shape differs from parley's internal
--       anthropic-shaped content blocks define it)
--
-- PURE: no IO, no Neovim state.
--------------------------------------------------------------------------------

local sse = require("parley.sse")

local M = {}

--- Convert a list of parley ToolDefinitions into the Anthropic payload
--- shape for the `tools` array. Each entry contains only the fields
--- Anthropic cares about: name, description, input_schema. Internal
--- fields (handler, kind, needs_backup) are intentionally dropped.
---
--- Pure. Accepts nil or empty list and returns an empty table.
---@param tool_definitions ToolDefinition[]|nil
---@return table[] anthropic_tools
function M.encode_tools(tool_definitions)
    local out = {}
    for _, def in ipairs(tool_definitions or {}) do
        table.insert(out, {
            name = def.name,
            description = def.description,
            input_schema = def.input_schema,
        })
    end
    return out
end

--- Compel a specific tool this turn. Anthropic spells this
--- `{type = "tool", name = <tool>}`.
---
--- Promoted here from skill_assembly.lua in #198: a forced tool choice is
--- wire knowledge, and the OpenAI spelling differs, so a skill manifest
--- must carry the tool NAME and let the wire shape it.
---@param tool_name string
---@return table
function M.encode_tool_choice(tool_name)
    return { type = "tool", name = tool_name }
end

--- Walk a captured Anthropic SSE response string and extract any
--- client-side tool_use blocks as normalized ToolCall tables.
---
--- Anthropic's streaming shape for tool use (per docs):
---
---     content_block_start  with content_block.type == "tool_use"
---                          → { id, name, input = {} } at .index
---     content_block_delta  with delta.type == "input_json_delta"
---                          and delta.partial_json string chunks
---                          accumulated at the same .index
---     content_block_stop   at .index finalizes the block; we decode
---                          the assembled JSON into the ToolCall.input
---     message_stop         ends the response
---
--- The decoder IGNORES:
---   - text / thinking blocks (not tool calls)
---   - server_tool_use (web_search, web_fetch) — resolved by Anthropic
---     server-side, no client tool_result needed
---   - web_search_tool_result / web_fetch_tool_result (server replies)
---
--- Returns a flat list of ToolCalls in the order they were streamed.
--- Called once after streaming completes by the tool_loop driver,
--- same pattern as `anthropic.parse_usage`.
---
--- @param raw_response string the full captured SSE response
--- @return ToolCall[]
function M.decode_tool_calls_from_stream(raw_response)
    if type(raw_response) ~= "string" or raw_response == "" then
        return {}
    end

    -- index -> { id, name, parts = {} }
    local in_flight = {}
    -- Preserve streaming order of completion.
    local completed = {}

    for line in raw_response:gmatch("[^\n]+") do
        -- Only `data:` lines carry JSON payloads.
        if line:sub(1, 6) == "data: " then
            local decoded = sse.safe_json_decode(sse.strip_data_prefix(line))
            if type(decoded) == "table" then
                local idx = decoded.index or 0
                local t = decoded.type

                if t == "content_block_start" then
                    local block = decoded.content_block
                    if type(block) == "table" and block.type == "tool_use" then
                        -- Only CLIENT-side tool_use. server_tool_use is
                        -- intentionally skipped.
                        in_flight[idx] = {
                            id = block.id,
                            name = block.name,
                            parts = {},
                        }
                    end

                elseif t == "content_block_delta" then
                    local d = decoded.delta
                    if type(d) == "table" and d.type == "input_json_delta"
                       and type(d.partial_json) == "string" then
                        local state = in_flight[idx]
                        if state then
                            table.insert(state.parts, d.partial_json)
                        end
                    end

                elseif t == "content_block_stop" then
                    local state = in_flight[idx]
                    if state then
                        local full_json = table.concat(state.parts)
                        local input = {}
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
                        in_flight[idx] = nil
                    end
                end
            end
        end
    end

    return completed
end

--- Did this stream carry a client tool call at all?
---
--- Cheap plain-text probe, NOT a parse: the dispatcher asks this on every
--- completed response to decide whether an empty text body means "the
--- model said nothing" or "the model spent the turn calling a tool".
--- Promoted from the literal at dispatcher.lua:326 in #198 so the
--- question can be asked per-wire.
---@param raw_response string
---@return boolean
function M.has_tool_calls(raw_response)
    return type(raw_response) == "string"
        and raw_response:find('"type":"tool_use"', 1, true) ~= nil
end

return M
