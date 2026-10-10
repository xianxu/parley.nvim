-- comment/thread.lua — PURE marker ↔ thread-float lines (#312).
--
-- The float shows one turn per line in raw bracket form (`[human]`,
-- `{robot}`), a `<br>` inside a turn becoming a real line break, plus an empty
-- trailing `[]` for the reply. Writing back joins the turns into ONE line
-- (markers are single-line) through the same section parser the buffer uses.
local codec = require("parley.comment.codec")

local M = {}

local OPEN = { user = "[", agent = "{" }
local CLOSE = { user = "]", agent = "}" }
local UNBALANCED = "unbalanced brackets or stray text in the thread — fix it before closing"

--- @return string[] lines, string[] roles  ("user"|"agent" per line)
function M.to_lines(marker)
    local lines, roles = {}, {}
    local function add(kind, text)
        local turn = OPEN[kind] .. codec.decode(text) .. CLOSE[kind]
        for _, part in ipairs(vim.split(turn, "\n", { plain = true })) do
            lines[#lines + 1] = part
            roles[#roles + 1] = kind
        end
    end
    for _, s in ipairs(marker.sections) do add(s.type, s.text) end
    add("user", "")
    return lines, roles
end

--- @param prefix string  the marker's raw `🤖`, `🤖<X>` or `🤖~D~`
--- @return string|nil raw, string|nil err
function M.from_lines(prefix, lines)
    local parse = require("parley.skills.review")._parse_marker_sections
    local rest = table.concat(lines, "\n")
    local sections = {}
    -- The parser's chain stops at the `\n` between float lines, so parse one
    -- adjacent run at a time, skipping the whitespace between turns.
    while true do
        rest = rest:gsub("^%s+", "")
        if rest == "" then break end
        local text = "🤖" .. rest
        local run, stop = parse(text, 1, 4, { budget = #lines })
        if #run == 0 then return nil, UNBALANCED end
        vim.list_extend(sections, run)
        rest = text:sub(stop)
    end
    while #sections > 0 and sections[#sections].text:match("^%s*$") do
        table.remove(sections)
    end
    local out = { prefix }
    for _, s in ipairs(sections) do
        out[#out + 1] = OPEN[s.type] .. codec.encode(s.text) .. CLOSE[s.type]
    end
    return table.concat(out)
end

return M
