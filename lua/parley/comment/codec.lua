-- comment/codec.lua — newline escape for single-line 🤖 markers (#312).
-- A marker never spans lines in the file; a newline inside a turn is `<br>`.
-- A literal `<br>` in a turn (a markdown table cell) is written `\<br>`, so a
-- robot edit to a table row survives acceptance intact.
--
-- Only a backslash run right before `<br>` is an escape: k text backslashes
-- become 2k, plus one more for a literal `<br>`. So an odd run decodes to a
-- literal `<br>`, an even run to a newline, and every text round-trips
-- (`a\` + newline is `a\\<br>`, not the literal `a\<br>`). Backslashes
-- anywhere else are verbatim.
local M = {}

function M.encode(text)
    return (text:gsub("(\\*)<br>", function(b) return b .. b .. "\\<br>" end)
        :gsub("(\\*)\r?\n", function(b) return b .. b .. "<br>" end))
end

function M.decode(text)
    return (text:gsub("(\\*)<br>", function(b)
        return ("\\"):rep(math.floor(#b / 2)) .. (#b % 2 == 1 and "<br>" or "\n")
    end))
end

return M
