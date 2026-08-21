-- The canonical fenced-block grammar for tool bodies.
--
-- A tool body opens on a run of >= 3 backticks, optionally followed by an info
-- string (`json`, `lua`), and closes only on a BARE run of the SAME length.
-- The same-length rule is what lets a body contain ``` blocks of its own: the
-- writer picks a fence strictly longer than anything inside the content, so
-- nothing in the body can terminate it.
--
-- This rule had three independent implementations (#200). `tools/serialize`
-- had it right on the writer side and restated it twice more as `%1`
-- backreferences on the reader side; `answer_structure` closed on *any*
-- >= 3-backtick run, so a nested ``` truncated a tool section; `chat_parser`
-- carried its own correct-but-separate tracker. One source, three consumers
-- deriving from it (ARCH-DRY).
--
-- Pure: no Neovim API, no state.

local M = {}

M.MIN = 3

--- Length of the fence this line opens, or nil when it opens none.
---
--- The info string is a bare word (`json`, `py_3`), matching what the writer
--- emits and what chat_parser's tracker already accepted. Prose after the
--- ticks is not a fence — "``` see below" is content, not an opener.
--- @param line string
--- @return integer|nil
function M.open_len(line)
    if type(line) ~= "string" then return nil end
    local ticks = line:match("^(`+)[%w_%-]*%s*$")
    if not ticks or #ticks < M.MIN then return nil end
    return #ticks
end

--- Whether this line closes a fence of length `n`.
---
--- Exactly `n` backticks and nothing else. A shorter run is body content; a
--- longer one belongs to some other pair, and treating it as a close is how a
--- reader can terminate a body early.
--- @param line string
--- @param n integer
--- @return boolean
function M.closes(line, n)
    if type(line) ~= "string" or type(n) ~= "number" then return false end
    return line:match("^(`+)%s*$") ~= nil and #(line:match("^(`+)")) == n
end

--- Longest run of backticks anywhere in `s`.
--- @return integer
function M.longest_run(s)
    if type(s) ~= "string" or s == "" then return 0 end
    local longest = 0
    for run in s:gmatch("`+") do
        if #run > longest then longest = #run end
    end
    return longest
end

--- A fence strictly longer than any run in `content`, floored at MIN.
---
--- The invariant this exists to guarantee: no line of `content` can close the
--- fence returned for it.
--- @param content string
--- @return string
function M.for_content(content)
    local longest = M.longest_run(content)
    if longest < M.MIN then return string.rep("`", M.MIN) end
    return string.rep("`", longest + 1)
end

--- Extract the body of the first complete fenced block in `lines`.
---
--- Scans for an opener, then for the matching close of the same length. This is
--- the reader half of the grammar, shared so that reader and writer cannot
--- disagree about what "the same pair" means.
--- @param lines string[]
--- @param from integer|nil  1-based index to start scanning at (default 1)
--- @return string|nil body, integer|nil open_index, integer|nil close_index
function M.extract_body(lines, from)
    local open_len, first
    for index = from or 1, #lines do
        if not open_len then
            open_len = M.open_len(lines[index])
            if open_len then first = index + 1 end
        elseif M.closes(lines[index], open_len) then
            return table.concat(lines, "\n", first, index - 1), first - 1, index
        end
    end
    return nil
end

return M
