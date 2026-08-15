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

                    -- sse.str, not `if tc.id then`: an explicit JSON null
                    -- decodes to vim.NIL, which is TRUTHY, so the obvious
                    -- guard would let a continuation chunk overwrite the id
                    -- and name captured in the first chunk with userdata.
                    state.id = sse.str(tc.id) or state.id

                    local fn = tc["function"]
                    if type(fn) == "table" then
                        state.name = sse.str(fn.name) or state.name
                        local args = sse.str(fn.arguments)
                        if args then
                            table.insert(state.parts, args)
                        end
                    end
                end
            end
        end
    end

    local completed = {}
    for _, idx in ipairs(order) do
        local state = by_index[idx]
        -- A nameless entry is not a call. It happens when a stream carries a
        -- continuation fragment whose opening chunk never arrived, and it has
        -- no analogue on the anthropic wire (a call exists there only if
        -- content_block_start named it). Surfacing one would put an
        -- unexecutable ToolCall into the loop, where the registry lookup
        -- concatenates the nil name and raises — breaking the very
        -- never-raise contract this decoder advertises. Dropping it is safe:
        -- nothing was written to the buffer for it, so nothing is left
        -- unmatched.
        if state.name then
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
    end

    return completed
end

--- Did this stream carry a client tool call at all? Cheap plain-text probe,
--- not a parse. See wire_anthropic.has_tool_calls for why it exists.
---
--- A backend that emits `"tool_calls":null` on every delta would make this
--- permanently true. That errs in the benign direction — it suppresses the
--- "response is empty" notice rather than causing one — so it stays a
--- substring probe rather than paying a full parse on every response.
---@param raw_response string
---@return boolean
function M.has_tool_calls(raw_response)
    return type(raw_response) == "string"
        and raw_response:find('"tool_calls"', 1, true) ~= nil
end

--------------------------------------------------------------------------------
-- Messages
--------------------------------------------------------------------------------

--- Prefix marking a failed tool result. OpenAI has no `is_error` field on a
--- tool message, so the signal has to live in the content — otherwise the
--- model cannot distinguish a failed call from a successful one that
--- happened to return error text.
local ERROR_PREFIX = "Error: "

--- Translate parley's internal (Anthropic-shaped) message list into OpenAI
--- shape.
---
--- Parley builds messages Anthropic's way: an assistant turn carries
--- [text, tool_use] content blocks, and the immediately following user turn
--- carries the matching [tool_result] blocks. chat_respond's
--- _emit_content_blocks_as_messages is the single place that shape — and the
--- #155 / #156 invariants that keep it well-formed — is produced. This
--- function consumes that already-validated output rather than duplicating
--- the invariants, which is why the translation lives here and not in the
--- emitter (ARCH-DRY).
---
--- Two structural differences:
---   * tool calls hang off the assistant message as `tool_calls[]`, with
---     `arguments` a JSON STRING rather than an object;
---   * each result becomes its OWN `{role = "tool", tool_call_id = …}`
---     message, so one user turn can fan out into several messages.
---
--- Messages whose `content` is a plain string pass through untouched. That
--- is the majority path — this runs on every openai-family request, not just
--- tool-using ones, because history may carry tool blocks from earlier turns.
---@param messages table[]|nil
---@return table[]
function M.translate_messages(messages)
    local out = {}

    for _, msg in ipairs(messages or {}) do
        if type(msg.content) ~= "table" then
            -- Plain string content (or none): identity.
            table.insert(out, msg)

        elseif msg.role == "assistant" then
            local texts, tool_calls = {}, {}
            for _, block in ipairs(msg.content) do
                if block.type == "text" then
                    table.insert(texts, block.text or "")
                elseif block.type == "tool_use" then
                    local input = block.input
                    if type(input) ~= "table" or not next(input) then
                        input = vim.empty_dict()
                    end
                    table.insert(tool_calls, {
                        id = block.id,
                        type = "function",
                        ["function"] = {
                            name = block.name,
                            arguments = vim.json.encode(input),
                        },
                    })
                end
            end

            local translated = { role = "assistant" }
            -- Left nil (not "") when the turn was tool calls only.
            if #texts > 0 then
                translated.content = table.concat(texts, "\n\n")
            end
            if #tool_calls > 0 then
                translated.tool_calls = tool_calls
            end
            table.insert(out, translated)

        else
            -- A user turn carrying tool_result blocks. Each result becomes
            -- its own message; any stray text blocks collapse into one user
            -- message after them, preserving the batch's relative order.
            local texts = {}
            for _, block in ipairs(msg.content) do
                if block.type == "tool_result" then
                    local content = block.content or ""
                    if block.is_error then
                        content = ERROR_PREFIX .. content
                    end
                    table.insert(out, {
                        role = "tool",
                        tool_call_id = block.tool_use_id,
                        content = content,
                    })
                elseif block.type == "text" then
                    table.insert(texts, block.text or "")
                else
                    -- Unreachable today: parley builds no multimodal blocks, and
                    -- the only table-content non-assistant messages come from
                    -- _emit_content_blocks_as_messages. But dropping content on
                    -- the floor is how a future image/document block would
                    -- vanish from a request with no symptom but a confused
                    -- model, so say so.
                    require("parley.logger").warning(
                        "wire_openai.translate_messages: dropping unsupported "
                        .. tostring(msg.role) .. " content block of type "
                        .. tostring(block.type))
                end
            end
            if #texts > 0 then
                table.insert(out, {
                    role = msg.role or "user",
                    content = table.concat(texts, "\n\n"),
                })
            end
        end
    end

    return out
end

return M
