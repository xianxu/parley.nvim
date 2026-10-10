-- comment/codec.lua — newline escape for single-line 🤖 markers (#312).
-- A marker never spans lines in the file; a newline inside a turn is `<br>`.
local M = {}

function M.encode(text)
    return (text:gsub("\r?\n", "<br>"))
end

function M.decode(text)
    return (text:gsub("<br>", "\n"))
end

return M
