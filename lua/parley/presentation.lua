-- Historical round presentation: span metadata overrides round metadata;
-- missing history defaults to highlight. Current document keys are retired.
-- Pure projection; no sidecar/record write or JSON round-trip is performed.
local M = {}

M.MAX_SPANS = 200
local KNOWN = { direct = true, highlight = true, propose = true }

local function mode(value, field)
    if value == nil then return nil end
    if type(value) ~= "string" or not KNOWN[value] then
        return nil, field .. " must be direct, highlight or propose"
    end
    return value
end

--- Stored history only. A present malformed value never becomes a default,
--- including when a valid span value would otherwise override it.
function M.effective(round, span)
    if type(round) ~= "table" or type(span) ~= "table" then return nil, "invalid round/span" end
    local round_mode, err = mode(round.presentation, "round.presentation")
    if err then return nil, err end
    local span_mode, span_err = mode(span.presentation, "span.presentation")
    if span_err then return nil, span_err end
    return span_mode or round_mode or "highlight"
end

-- Coordinates are untrusted known fields. Stale valid coordinates may be
-- re-anchored; malformed coordinates must not fabricate historical placement.
local function position(value)
    if type(value) ~= "table" or rawget(value, 3) ~= nil then return false end
    for i = 1, 2 do
        local n = rawget(value, i)
        if type(n) ~= "number" or n < 0 or n > 9007199254740991 or n % 1 ~= 0 then return false end
    end
    return true
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
--- nearest its old position. A span that can't be placed is dropped. Only
--- effective highlight spans are tinted. Malformed consumed metadata refuses
--- the projection as nil,error; opaque fields remain untouched.
--- @param round table Couch's round
--- @param lines string[]
--- @param current_hash string the hash of `lines` as a file
--- @return table[]|nil, string|nil
function M.decorations(round, lines, current_hash)
    local out = {}
    if type(round) ~= "table" or type(round.spans) ~= "table" then return nil, "invalid round.spans" end
    local _, mode_err = mode(round.presentation, "round.presentation")
    if mode_err then return nil, mode_err end
    if #lines == 0 then return out end
    local text, starts = table.concat(lines, "\n"), line_starts(lines)
    local matched = current_hash == round.result_hash
    for i = 1, math.min(#round.spans, M.MAX_SPANS) do
        local span = round.spans[i]
        if type(span) ~= "table" then return nil, "invalid span " .. i end
        local effective, err = M.effective(round, span)
        if err then return nil, err end
        if type(span.old) ~= "string" or type(span.new) ~= "string" then return nil, "invalid span old/new" end
        if span.explain ~= nil and type(span.explain) ~= "string" then return nil, "invalid span explain" end
        if not position(span.start) or not position(span["end"]) then return nil, "invalid span coordinates" end
        local kind = M.kind(span.old, span.new)
        if effective == "highlight" and kind ~= "delete" then
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
