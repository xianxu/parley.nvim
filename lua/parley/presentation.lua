-- Presentation (#383): how a document shows the agent's last round, read from
-- its `presentation:` key, and where that round's spans land in the buffer.
-- PURE: plain line tables in, plain tables out; edit_round draws them.
--
-- A round is Couch's sidecar (pair#661): spans with 0-based [line, byte column]
-- positions in the file the agent wrote. Couch's positions are untrusted input:
-- a span that doesn't check out against the lines is re-found by its text or
-- dropped, never clamped into a wrong place.
local frontmatter = require("parley.frontmatter")

local M = {}

-- The most spans one round places; edit_round says so when a round has more.
M.MAX_SPANS = 200

local KNOWN = { direct = true, highlight = true, propose = true }

--- The document's presentation: direct, highlight or propose. A missing or
--- unknown value is highlight, as Couch reads it.
--- @param lines string[]
--- @return string
function M.value(lines)
    local fm = frontmatter.parse(lines)
    local value = fm and fm.fields.presentation
    return KNOWN[value] and value or "highlight"
end

-- Byte offset of each line's first byte in the lines joined by "\n".
local function line_starts(lines)
    local starts, offset = {}, 0
    for i, line in ipairs(lines) do
        starts[i] = offset
        offset = offset + #line + 1
    end
    return starts
end

-- The 0-based offset of a [line, col] position, or nil when it isn't one.
local function offset_of(position, lines, starts)
    if type(position) ~= "table" then return nil end
    local line, col = rawget(position, 1), rawget(position, 2)
    if type(line) ~= "number" or type(col) ~= "number" or line % 1 ~= 0 or col % 1 ~= 0 then return nil end
    if line < 0 or line >= #lines or col < 0 or col > #lines[line + 1] then return nil end
    return starts[line + 1] + col
end

-- The 0-based [line, col] of an offset inside the joined text.
local function position_of(offset, starts)
    local lo, hi = 1, #starts
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if starts[mid] <= offset then lo = mid else hi = mid - 1 end
    end
    return lo - 1, offset - starts[lo]
end

-- The occurrence of `new` in text nearest `near`, or nil when it's gone.
local function nearest(text, new, near)
    local best, from = nil, 1
    while true do
        local at = text:find(new, from, true)
        if not at then return best end
        if not best or math.abs(at - 1 - near) < math.abs(best - near) then best = at - 1 end
        from = at + 1
    end
end

--- An edit's kind from its old and new text (#387): "delete" when nothing is
--- left, "add" when it replaced nothing, "change" otherwise. The one rule for
--- the agent's round and the review skill's edits alike.
--- @param old string|nil
--- @param new string|nil
--- @return "add"|"change"|"delete"
function M.kind(old, new)
    if new == nil or new == "" then return "delete" end
    return (old == nil or old == "") and "add" or "change"
end

local function message(span)
    return type(span.explain) == "string" and span.explain ~= "" and span.explain or "changed by the agent"
end

--- Where a round's spans land in `lines`: `{lnum, col, end_lnum, end_col,
--- message, kind}` with 0-based positions, for at most MAX_SPANS spans. `kind`
--- is "add" when the span replaced nothing (empty old) and "change" otherwise;
--- a deletion (empty new) leaves no trace, so it yields nothing (#387).
--- When `current_hash` is the round's result_hash, a span is placed where Couch
--- says if its text is there. Otherwise it is re-found by its new text,
--- nearest its old position. A span that can't be placed is dropped.
--- @param round table Couch's round
--- @param lines string[]
--- @param current_hash string the hash of `lines` as a file
--- @return table[]
function M.decorations(round, lines, current_hash)
    local out = {}
    if type(round) ~= "table" or type(round.spans) ~= "table" or #lines == 0 then return out end
    local text, starts = table.concat(lines, "\n"), line_starts(lines)
    local matched = current_hash == round.result_hash
    for i = 1, math.min(#round.spans, M.MAX_SPANS) do
        local span = round.spans[i]
        local kind = type(span) == "table" and type(span.old) == "string" and type(span.new) == "string"
            and M.kind(span.old, span.new)
        if kind and kind ~= "delete" then
            local from = offset_of(span.start, lines, starts)
            local to = offset_of(span["end"], lines, starts)
            local placed
            if matched and from and to and from <= to and text:sub(from + 1, to) == span.new then
                placed = from
            else
                placed = nearest(text, span.new, from or 0)
            end
            if placed then
                local lnum, col = position_of(placed, starts)
                local end_lnum, end_col = position_of(placed + #span.new, starts)
                out[#out + 1] = { lnum = lnum, col = col, end_lnum = end_lnum, end_col = end_col,
                    message = message(span), kind = kind }
            end
        end
    end
    return out
end

return M
