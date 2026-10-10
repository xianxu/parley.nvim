-- comment/thread.lua — PURE marker ↔ thread-float lines (#312).
--
-- The float reads like a parley chat: each turn starts a line with `💬: `
-- (human) or `🤖: ` (robot); a line with neither prefix continues the turn
-- above (a `<br>` inside a turn becomes such a line break). A trailing `💬: `
-- is the reply slot. Writing back joins the turns into ONE marker line
-- (markers are single-line) and re-parses it with the buffer's own section
-- parser, so text that would break the brackets is refused, not written.
local codec = require("parley.comment.codec")

local M = {}

local PREFIX = { user = "💬:", agent = "🤖:" }
local OPEN = { user = "[", agent = "{" }
local CLOSE = { user = "]", agent = "}" }

-- A continuation line that would read as a turn start (`💬: x` inside a
-- turn) is shown with one extra leading `\`; any `\`-run before a prefix
-- gains one, so the float layout stays injective.
local function prefix_led(line)
    local rest = line:gsub("^\\+", "")
    for _, prefix in pairs(PREFIX) do
        if rest:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function escape_line(line) return prefix_led(line) and "\\" .. line or line end

local function unescape_line(line)
    return line:match("^\\") and prefix_led(line) and line:sub(2) or line
end

-- The role a line starts, or nil for a continuation line.
local function role_of(line)
    for role, prefix in pairs(PREFIX) do
        if line:sub(1, #prefix) == prefix then return role, line:sub(#prefix + 1):gsub("^ ", "", 1) end
    end
end

--- Role per float line ("user"|"agent"); a continuation line inherits.
function M.roles(lines)
    local out, role = {}, "user"
    for i, l in ipairs(lines) do
        role = role_of(l) or role
        out[i] = role
    end
    return out
end

--- An existing empty trailing `[]` (a fresh `<M-q>` marker, or `{R}[]` = "go
--- ahead") IS the reply slot; otherwise an empty `💬: ` is appended for it.
--- @return string[] lines, string[] roles
--- @return boolean appended  whether the reply slot was added here
function M.to_lines(marker)
    local lines = {}
    local function add(kind, text)
        local parts = vim.split(codec.decode(text), "\n", { plain = true })
        lines[#lines + 1] = PREFIX[kind] .. " " .. parts[1]
        for i = 2, #parts do lines[#lines + 1] = escape_line(parts[i]) end
    end
    for _, s in ipairs(marker.sections) do add(s.type, s.text) end
    local last = marker.sections[#marker.sections]
    local appended = not (last and last.type == "user" and last.text == "")
    if appended then add("user", "") end
    return lines, M.roles(lines), appended
end

--- @param prefix string  the marker's raw `🤖`, `🤖<X>` or `🤖~D~`
--- @param appended boolean  to_lines added the reply slot: an empty one is
---   dropped. A slot that was already in the marker is kept, empty or not —
---   `{R}[]` means "go ahead".
--- @return string|nil raw, string|nil err
function M.from_lines(prefix, lines, appended)
    local turns = {}
    for _, l in ipairs(lines) do
        local role, text = role_of(l)
        if role then
            turns[#turns + 1] = { type = role, parts = { text } }
        elseif #turns > 0 then
            table.insert(turns[#turns].parts, unescape_line(l))
        elseif l:match("%S") then
            return nil, "text before the first 💬: / 🤖: turn — start it with a prefix"
        end
    end
    for _, t in ipairs(turns) do
        -- Trailing blank lines after a turn are layout, not content: a turn's
        -- trailing `<br>` is normalized away on save (deliberately lossy).
        while #t.parts > 1 and not t.parts[#t.parts]:match("%S") do table.remove(t.parts) end
        t.text = table.concat(t.parts, "\n")
    end
    local last = turns[#turns]
    if appended and last and last.type == "user" and not last.text:match("%S") then
        table.remove(turns)
    end
    local out = { prefix }
    for _, t in ipairs(turns) do
        out[#out + 1] = OPEN[t.type] .. codec.encode(t.text) .. CLOSE[t.type]
    end
    local raw = table.concat(out)
    -- Re-parse: a stray `]` / `}` in a turn would end it early and leak the
    -- rest of the thread into the document.
    local parse = require("parley.skills.review")._parse_marker_sections
    local sections, stop = parse(raw, 1, 4)
    if raw:sub(1, 4) ~= "🤖" then sections = {} end
    local whole = stop == #raw + 1 and #sections == #turns
    if #turns > 0 and not whole then
        return nil, "unbalanced [ ] or { } inside a turn — balance or remove them before saving"
    end
    return raw
end

return M
