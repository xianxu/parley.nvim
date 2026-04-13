-- Pure render layer for chat buffer content.
--
-- Inputs are pure data (sections from chat_parser); outputs are line
-- arrays. No buffer access, no nvim API beyond vim.json/vim.tbl_*.
--
-- See workshop/plans/000090-renderer-refactor.md section 4.

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

--- Build the standard agent header lines ("", "🤖: <prefix><suffix>", "").
--- Used by buffer_edit.create_answer_region (Task 1.7).
--- @param agent_prefix string|nil  e.g. "[Claude]"
--- @param agent_suffix string|nil  e.g. "[🔧🌎]"
--- @return string[]
function M.agent_header_lines(agent_prefix, agent_suffix)
    return { "", "🤖: " .. (agent_prefix or "") .. (agent_suffix or ""), "" }
end

--- Build the lines for a raw_request fenced JSON block. The payload is
--- pretty-printed via python3 if available, otherwise emitted as-is.
--- NOT pure-of-system: shells out to python3 via vim.fn.system. Lives
--- here for DRY (the caller would need it anyway). Not on the
--- PURE_FILES arch list.
--- @param payload table
--- @return string[]
function M.raw_request_fence_lines(payload)
    local json_str = vim.json.encode(payload)
    local pretty = vim.fn.system({ "python3", "-m", "json.tool" }, json_str)
    if vim.v.shell_error ~= 0 or not pretty or pretty == "" then
        pretty = json_str
    end
    local out = { "", '```json {"type": "request"}' }
    for line in pretty:gmatch("[^\n]+") do
        table.insert(out, line)
    end
    table.insert(out, "```")
    return out
end

--- Compute the per-section line spans by walking the parsed model.
--- This is a sanity-check projection of what the parser already
--- recorded — used in tests to verify parser/render agreement.
--- @param parsed_chat table
--- @return table { exchanges = [{ question = {l_start,l_end}, answer = {l_start, l_end, sections = [...]} }] }
function M.positions(parsed_chat)
    local result = { exchanges = {} }
    for _, ex in ipairs(parsed_chat.exchanges or {}) do
        local entry = {}
        if ex.question then
            entry.question = {
                line_start = ex.question.line_start,
                line_end = ex.question.line_end,
            }
        end
        if ex.answer then
            entry.answer = {
                line_start = ex.answer.line_start,
                line_end = ex.answer.line_end,
                sections = {},
            }
            for _, s in ipairs(ex.answer.sections or {}) do
                table.insert(entry.answer.sections, {
                    kind = s.kind,
                    line_start = s.line_start,
                    line_end = s.line_end,
                })
            end
        end
        table.insert(result.exchanges, entry)
    end
    return result
end

return M
