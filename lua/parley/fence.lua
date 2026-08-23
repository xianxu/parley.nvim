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
-- carried its own correct-but-separate tracker. One source, four consumers
-- deriving from it (ARCH-DRY).
--
-- Pure: no Neovim API, no state.

local M = {}

M.MIN = 3

--- Length of the fence this line opens, or nil when it opens none.
---
--- The info string follows CommonMark: anything after the backticks that does
--- not itself contain a backtick. Being stricter than this is not a harmless
--- conservatism — it is how the whole scanner desyncs. A genuine opener the
--- grammar refuses (`render_buffer` emits ```` ```json {"type": "request"} ````)
--- leaves its CLOSER to be read as an opener, and every consumer downstream
--- shifts by one fence: bodies start in the wrong place, and the guards that
--- defend "a question is never folded" blind themselves (#200 BR-43).
--- @param line string
--- @return integer|nil
function M.open_len(line)
    if type(line) ~= "string" then return nil end
    local ticks, info = line:match("^(`+)([^`]*)$")
    if not ticks or #ticks < M.MIN then return nil end
    return #ticks, info
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

--- @param lines string[]
--- @param is_tool_marker fun(line: string, row: integer): boolean
--- @param is_structural fun(line: string, row: integer): boolean
---   Whether a line is a column-0 structural marker (#203). Every consumer
---   passes it; a caller that omits it silently gets the pre-#203 search, in
---   which a tool body can latch onto a close belonging to another pair.
function M.scan(lines, is_tool_marker, is_structural)
    local bodies, markers = {}, {}

    -- UNBOUNDED, and it must stay that way. This search establishes DEPTH for
    -- ORDINARY fenced blocks. A block that fails to establish depth leaves its
    -- own closer to be read as an opener: the scan desyncs by one fence and a
    -- `📎:` quoted in prose becomes a depth-0 marker — BR-43 exactly. The #203
    -- bound belongs to tool bodies alone; putting it here re-opened the defect
    -- #200 closed, and the whole suite stayed green while it was broken (found
    -- by this issue's own close review, BR-1).
    local function close_of(open_len, from)
        for row = from, #lines do
            if M.closes(lines[row], open_len) then return row end
        end
        return nil
    end

    -- BOUNDED: a TOOL BODY may not span a column-0 structural marker (#203).
    -- Without the bound, an opener that is never closed latches onto some later
    -- unrelated bare fence, and every 💬: in between stops starting an exchange
    -- — the rest of the chat collapses into one, silently.
    --
    -- The bound is safe because a marker inside a body means the content did not
    -- come from a parley tool: the content-echoing tools all prefix their output
    -- (read_file `%5d  `, grep/ack `-H` giving `file:line:`, chat_history_search
    -- `{label}/path:line:`). So the body is hand-edited, truncated, or pasted,
    -- and forking there is the visible degradation chosen over silent swallowing.
    --
    -- NOT a total invariant, and the claim is bounded rather than chased: the
    -- path-echoing tools (ls, find) emit a column-0 marker for a file NAMED like
    -- one, and the shell tools splice raw stderr on error. Both degrade to
    -- over-forking, which is the accepted direction.
    -- tests/integration/tool_output_prefix_spec.lua guards the producer half over
    -- a tool x call-shape product, and records those two exceptions.
    local function body_close_of(open_len, from)
        for row = from, #lines do
            if M.closes(lines[row], open_len) then return row end
            if is_structural and is_structural(lines[row], row) then return nil end
        end
        return nil
    end

    local row = 1
    while row <= #lines do
        local line = lines[row] or ""
        if is_tool_marker(line, row) then
            markers[row] = true
            local body_len = M.open_len(lines[row + 1] or "")
            local close = body_len and body_close_of(body_len, row + 2)
            if close then
                bodies[row] = { first = row + 2, last = close - 1, close = close }
                row = close + 1
            else
                row = row + 1
            end
        else
            local open_len = M.open_len(line)
            local close = open_len and close_of(open_len, row + 1)
            -- Only a CLOSED block establishes depth; an unclosed opener is
            -- ordinary text, so a stray fence cannot hide the rest of the chat.
            row = close and (close + 1) or (row + 1)
        end
    end
    return bodies, markers
end

--- Convenience view: the set of rows lying inside some tool body.
---
--- Derived here rather than by each consumer. Reconstructing extents from a row
--- set is lossy — an EMPTY body has no rows, so a consumer walking the set
--- cannot tell "no body" from "body with nothing in it" and mis-segments
--- (#200 BR-52).
--- @param bodies table  as returned by M.scan
--- @return table       set of 1-based rows
function M.body_rows(bodies)
    local rows = {}
    for _, body in pairs(bodies) do
        for row = body.first, body.last do rows[row] = true end
    end
    return rows
end

return M
