-- Pure render layer for chat buffer content.
--
-- Inputs are pure data (sections from chat_parser); outputs are line
-- arrays. No buffer access, no nvim API beyond vim.json/vim.tbl_*.
--
-- See docs/plans/000090-renderer-refactor.md section 4.

local serialize = require("parley.tools.serialize")

local M = {}

-- Split a multi-line string into a Lua table of lines, preserving
-- empty entries (including a trailing empty line if the input ends
-- with "\n"). Used internally by render_section.
local function split_lines(text)
    if text == nil or text == "" then
        return { "" }
    end
    local out = {}
    local start = 1
    while true do
        local nl = text:find("\n", start, true)
        if not nl then
            table.insert(out, text:sub(start))
            break
        end
        table.insert(out, text:sub(start, nl - 1))
        start = nl + 1
    end
    return out
end

-- Render a multi-line string returned by serialize.render_call /
-- render_result into a flat list of lines (no trailing empty line).
local function rendered_string_to_lines(rendered)
    local lines = split_lines(rendered)
    -- serialize functions never end with a trailing newline, so we
    -- don't need to strip a trailing empty entry. Defensive anyway:
    if #lines > 0 and lines[#lines] == "" then
        table.remove(lines)
    end
    return lines
end

--- Render a single section into the lines it would occupy in the buffer.
--- Dispatches by kind. Delegates tool_use/tool_result to
--- lua/parley/tools/serialize.lua (single source of truth for the schema).
--- @param section table {kind, ...kind-specific fields}
--- @return string[] lines
function M.render_section(section)
    if section.kind == "text" then
        return split_lines(section.text or "")
    elseif section.kind == "tool_use" then
        return rendered_string_to_lines(serialize.render_call(section))
    elseif section.kind == "tool_result" then
        return rendered_string_to_lines(serialize.render_result(section))
    end
    error("render_section: unknown kind " .. tostring(section.kind))
end

--- Render a complete exchange (question + optional answer) into the
--- lines it would occupy in the buffer. Used for golden snapshot tests
--- (parse → render == original).
--- @param exchange table
--- @return string[] lines
function M.render_exchange(exchange)
    local out = {}
    table.insert(out, "💬: " .. (exchange.question and exchange.question.content or ""))
    if exchange.answer then
        table.insert(out, "")
        table.insert(out, "🤖:")
        local secs = exchange.answer.sections or {}
        for _, s in ipairs(secs) do
            for _, line in ipairs(M.render_section(s)) do
                table.insert(out, line)
            end
        end
    end
    return out
end

return M
