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

local FENCE_MIN = 3

-- Longest run of backticks in `s`. Used to pick a fence long enough
-- that the body can't accidentally close it.
local function longest_backtick_run(s)
    if not s or s == "" then return 0 end
    local max = 0
    for run in s:gmatch("`+") do
        if #run > max then max = #run end
    end
    return max
end

-- Pick a fence (a string of N backticks) strictly longer than any
-- run of backticks in `content`, with a floor of FENCE_MIN.
local function fence_for(content)
    local n = longest_backtick_run(content or "")
    if n < FENCE_MIN then return string.rep("`", FENCE_MIN) end
    return string.rep("`", n + 1)
end

--- Render a ToolCall into its buffer representation.
--- @param call ToolCall { id, name, input }
--- @return string block
function M.render_call(call)
    local input_json = vim.json.encode(call.input or {})
    local fence = fence_for(input_json)
    -- Opening fence carries the "json" info string for syntax-highlight
    -- hints; closing fence is bare backticks of the same length.
    return string.format(
        "🔧: %s id=%s\n%sjson\n%s\n%s",
        call.name,
        call.id,
        fence,
        input_json,
        fence
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

    -- Match an opening fence of any length >= 3 (optionally followed
    -- by an info string like "json") and a closing fence of the SAME
    -- length (bare backticks). Lua %1 backreference ensures matching
    -- pair. Fallback: no info string on opening fence.
    local _, body = text:match("\n(`+)json%s*\n(.-)\n%1")
    if not body then
        _, body = text:match("\n(`+)%s*\n(.-)\n%1")
    end

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
    local fence = fence_for(content)
    local err_tag = result.is_error and " error=true" or ""
    return string.format(
        "📎: %s id=%s%s\n%s\n%s\n%s",
        result.name or "",
        result.id,
        err_tag,
        fence,
        content,
        fence
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

    -- Match a dynamic-length fence pair for the body.
    local _, body = text:match("\n(`+)%s*\n(.-)\n%1")

    return {
        id = id,
        name = name,
        content = body or "",
        is_error = is_error,
    }
end

return M
