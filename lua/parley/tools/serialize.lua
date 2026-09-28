-- Buffer serialization for parley's `🔧:` (tool_use) and `📎:`
-- (tool_result) prefixed blocks.
--
-- This module is the SINGLE SOURCE OF TRUTH for the schema. The chat
-- parser (chat_parser.lua) reads blocks rendered here, and every
-- response adapter that writes tool call or result blocks goes
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
--   📎: <tool_name> id=<id>[ error=true][ escaped=true]
--   ```<fence-length-backticks>
--   <body>
--   ```<fence-length-backticks>
--
-- A body line the lexer reads as a structural marker (💬:, 🔧:, 📎: … at
-- column 0) would end the body early (fence.scan), so render_result escapes
-- it (#291): the block is flagged `escaped=true`, and in a flagged block every
-- such line, and every line already starting with `\`, gets one `\`
-- prepended. parse_result strips one from each line of a flagged block. An
-- unflagged block, and every block written before #291, is byte-for-byte
-- unchanged, so no producer needs to know about markers.
--
-- The fence length is dynamic: strictly longer than the longest run
-- of backticks in the body (minimum 3). The OPENING fence may carry
-- an optional info string (e.g. "json"); the CLOSING fence is bare
-- backticks of the same length. This lets the parser use the same
-- backtick count as a matching pair, unambiguously surviving LLM
-- output that contains ``` or longer fences.
--
-- PURE apart from reading the configured marker prefixes: no filesystem,
-- no side effects. Safe to call from any context.

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

local ESCAPE = "\\"
local ESCAPED = "escaped=true"

-- The same predicate fence.scan bounds a body with, under the configured prefixes.
local function structural(line)
    local structure = require("parley.highlight_structure")
    local patterns = structure.patterns(require("parley.config"))
    return structure.is_structural_kind(structure.classify(line, patterns).kind)
end

--- `content` with its structural lines escaped, or nil when none needs it.
local function escape(content)
    local lines = vim.split(content, "\n", { plain = true })
    local needed = false
    for _, line in ipairs(lines) do
        if structural(line) then needed = true; break end
    end
    if not needed then return nil end
    for i, line in ipairs(lines) do
        if structural(line) or line:sub(1, #ESCAPE) == ESCAPE then lines[i] = ESCAPE .. line end
    end
    return table.concat(lines, "\n")
end

local function unescape(content)
    local lines = vim.split(content, "\n", { plain = true })
    for i, line in ipairs(lines) do
        if line:sub(1, #ESCAPE) == ESCAPE then lines[i] = line:sub(#ESCAPE + 1) end
    end
    return table.concat(lines, "\n")
end

--- Render a ToolResult into its buffer representation.
--- @param result ToolResult { id, content, is_error?, name? }
--- @return string block
function M.render_result(result)
    local content = require("parley.tools.result_evidence").publish(result).content
    local escaped = escape(content)
    content = escaped or content
    local pair = fence_for(content)
    local err_tag = (result.is_error and " error=true" or "") .. (escaped and " " .. ESCAPED or "")
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
    -- A flag token after the id, never the name field.
    local escaped = (" " .. (header:match("id=%S+(.*)$") or "") .. " "):find(" " .. ESCAPED .. " ", 1, true) ~= nil

    local body = fenced_body(text)
    if body and escaped then body = unescape(body) end

    return {
        id = id,
        name = name,
        content = body or "",
        is_error = is_error,
    }
end

return M
