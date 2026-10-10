-- comment/codec.lua — newline escape for single-line 🤖 markers (#312).
-- A marker never spans lines in the file; a newline inside a turn is `<br>`.
-- A literal `<br>` in a turn (a markdown table cell) is written `\<br>`, so a
-- robot edit to a table row survives acceptance intact.
local M = {}

local HOLD = "\1" -- a control byte that never appears in buffer text (not \0: Lua 5.1 patterns end at NUL)

function M.encode(text)
    return (text:gsub("<br>", "\\<br>"):gsub("\r?\n", "<br>"))
end

function M.decode(text)
    return (text:gsub("\\<br>", HOLD):gsub("<br>", "\n"):gsub(HOLD, "<br>"))
end

return M
