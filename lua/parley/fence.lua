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

--- One linear pass over a buffer, answering both questions at once: which rows
--- are inside a tool body, and which tool markers are structural.
---
--- The missing requirement in every earlier attempt was **fence depth**. A
--- `📎:` written inside an ordinary fenced block is not a marker at all, and
--- treating it as one makes the enclosing block's CLOSER look like the body's
--- opener — the scan then latches onto the next block's opener and the "body"
--- spans a real question. That folded a `💬:` line at depth 0 (#200 BR-43).
---
--- The pass:
---   * at depth 0, a tool marker whose NEXT line opens a body consumes through
---     that body's close; the rows between are body;
---   * any other depth-0 opener skips to its own close — everything inside is
---     depth > 0 and yields no markers;
---   * an opener with no matching close is treated as ordinary text rather than
---     swallowing the remainder, so malformed input over-forks instead of
---     silently losing exchanges.
---
--- @param lines string[]                    1-based
--- @param is_tool_marker fun(line, row):boolean  true for 🔧:/📎: at column 0.
---        Receives the 1-based row too, so a caller that already classified
---        every line can index its array instead of reclassifying. The scan
---        skips rows while consuming a body, so a call counter would desync.
--- @return table in_tool_body  set of 1-based rows inside a tool body
--- @return table markers       set of 1-based rows holding a depth-0 tool marker
function M.scan(lines, is_tool_marker)
    local in_tool_body, markers = {}, {}

    local function close_of(open_len, from)
        for row = from, #lines do
            if M.closes(lines[row], open_len) then return row end
        end
        return nil
    end

    local row = 1
    while row <= #lines do
        local line = lines[row] or ""
        if is_tool_marker(line, row) then
            markers[row] = true
            local body_len = M.open_len(lines[row + 1] or "")
            local close = body_len and close_of(body_len, row + 2)
            if close then
                for body = row + 2, close - 1 do in_tool_body[body] = true end
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
    return in_tool_body, markers
end

return M
