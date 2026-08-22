-- Buffer serialization for parley's `🔧:` (tool_use) and `📎:`
-- (tool_result) prefixed blocks.
--
-- This module is the SINGLE SOURCE OF TRUTH for the schema. The chat
-- parser (chat_parser.lua) reads blocks rendered here, and every
-- site that writes a tool block to the buffer (tool_loop.lua,
-- cancellation cleanup, synthetic iteration-cap results) goes
-- through render_call / render_result. Changes to the schema must
-- land in this file AND this file only.
--
-- Schema:
--
--   🔧: <tool_name> id=<id>
--   ```json
--   <input_json>
--   ```
--
--   📎: <tool_name> id=<id>[ error=true]
--   ```<fence-length-backticks>
--   <body>
--   ```<fence-length-backticks>
--
-- The fence length is dynamic: strictly longer than the longest run
-- of backticks in the body (minimum 3). The OPENING fence may carry
-- an optional info string (e.g. "json"); the CLOSING fence is bare
-- backticks of the same length. This lets the parser use the same
-- backtick count as a matching pair, unambiguously surviving LLM
-- output that contains ``` or longer fences.
--
-- PURE: no filesystem, no vim state, no side effects. Safe to call
-- from any context.

local M = {}

local fence = require("parley.fence")

-- Fence selection and matching are the shared grammar's job (ARCH-DRY) — see
-- lua/parley/fence.lua. Both the writer and the two readers below derive from
-- it, so they cannot disagree about what "the same pair" means.
local function fence_for(content)
    return fence.for_content(content)
end

--- Body of the first complete fenced block in `text`, or nil.
---
--- Replaces a `%1` backreference, which is subtly wrong on the reader side: a
--- backreference matches a PREFIX of a longer run, so a body containing a run
--- longer than its own opener was truncated at that line.
local function fenced_body(text)
    return fence.extract_body(vim.split(text, "\n", { plain = true }))
end

--- Render a ToolCall into its buffer representation.
--- @param call ToolCall { id, name, input }
--- @return string block
function M.render_call(call)
    local input_json = vim.json.encode(call.input or {})
    local pair = fence_for(input_json)
    -- Opening fence carries the "json" info string for syntax-highlight
    -- hints; closing fence is bare backticks of the same length.
    return string.format(
        "🔧: %s id=%s\n%sjson\n%s\n%s",
        call.name,
        call.id,
        pair,
        input_json,
        pair
    )
end

--- Parse a rendered ToolCall block back into its canonical table.
--- Returns nil if the text does not start with a recognized header.
--- Tolerant of malformed / missing fenced body (returns empty input).
--- @param text string
--- @return ToolCall|nil
function M.parse_call(text)
    if type(text) ~= "string" then return nil end
    local name, id = text:match("^🔧:%s*(%S+)%s+id=(%S+)")
    if not name then return nil end

    local body = fenced_body(text)

    local input = {}
    if body and body ~= "" then
        local ok, decoded = pcall(vim.json.decode, body)
        if ok and type(decoded) == "table" then
            input = decoded
        end
    end

    return { id = id, name = name, input = input }
end

--- Render a ToolResult into its buffer representation.
--- @param result ToolResult { id, content, is_error?, name? }
--- @return string block
function M.render_result(result)
    local content = result.content or ""
    local pair = fence_for(content)
    local err_tag = result.is_error and " error=true" or ""
    return string.format(
        "📎: %s id=%s%s\n%s\n%s\n%s",
        result.name or "",
        result.id,
        err_tag,
        pair,
        content,
        pair
    )
end

--- Parse a rendered ToolResult block back into its canonical table.
--- Returns nil if the text does not start with a recognized header.
--- @param text string
--- @return ToolResult|nil
function M.parse_result(text)
    if type(text) ~= "string" then return nil end
    local name, id = text:match("^📎:%s*(%S+)%s+id=(%S+)")
    if not name then return nil end

    -- is_error is encoded on the header line only.
    local header = text:match("^([^\n]*)") or ""
    local is_error = header:find("error=true", 1, true) ~= nil

    local body = fenced_body(text)

    return {
        id = id,
        name = name,
        content = body or "",
        is_error = is_error,
    }
end

return M
