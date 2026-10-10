-- comment/codec.lua — newline escape for single-line 🤖 markers (#312).
-- A marker never spans lines in the file; a newline inside a turn is `<br>`.
-- A literal `<br>` in a turn (a markdown table cell) is written `\<br>`, so a
-- robot edit to a table row survives acceptance intact.
local M = {}

function M.encode(text)
    return (text:gsub("<br>", "\\<br>"):gsub("\r?\n", "<br>"))
end

function M.decode(text)
    -- \1 holds an escaped `<br>` aside: a control byte buffer text never
    -- carries (not \0 — Lua 5.1 patterns end at NUL).
    return (text:gsub("\\<br>", "\1"):gsub("<br>", "\n"):gsub("\1", "<br>"))
end

return M
