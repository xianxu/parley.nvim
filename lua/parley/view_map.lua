-- Where a position lands when the text under it is rewritten (#356). PURE.
--
-- An agent's write reloads the operator's buffer; without this the cursor kept
-- its line NUMBER, so an edit above it moved the operator to other text. Lines
-- outside the changed hunks shift by the net offset of the hunks above them;
-- a line inside a hunk follows its own text into the new hunk.
local M = {}

local NEEDLE = 25   -- characters each side of the column: about 50 to search for
local MIN_PART = 3  -- a fallback shorter than this matches anywhere, so it isn't tried

local function hunks(old, new)
    local function text(t) return table.concat(t, "\n") .. "\n" end
    return vim.diff(text(old), text(new), { result_type = "indices" })
end

-- The hunk holding `lnum`, or nil and the net line offset of the hunks above it.
-- Hunks are {a_start, a_count, b_start, b_count}; a_count == 0 inserts after
-- a_start, b_count == 0 deletes (b_start is then the line before).
local function locate(hs, lnum)
    local delta = 0
    for _, h in ipairs(hs) do
        local a_start, a_count, _, b_count = unpack(h)
        if a_count == 0 then
            if a_start >= lnum then break end
        elseif lnum < a_start then
            break
        elseif lnum < a_start + a_count then
            return h, delta
        end
        delta = delta + b_count - a_count
    end
    return nil, delta
end

local function clamp(lnum, new)
    return math.max(1, math.min(lnum, math.max(#new, 1)))
end

local function hunk_start(h, new)
    local _, _, b_start, b_count = unpack(h)
    return clamp(b_count == 0 and b_start + 1 or b_start, new)
end

-- Search the new hunk's lines for `part`; the column of its first match.
local function find(h, new, part)
    local _, _, b_start, b_count = unpack(h)
    for l = b_start, b_start + b_count - 1 do
        local at = (new[l] or ""):find(part, 1, true)
        if at then return l, at - 1 end
    end
end

--- The line `lnum` of `old` becomes in `new`, by position alone (a top line).
function M.map_line(old, new, lnum)
    local h, delta = locate(hunks(old, new), lnum)
    if h then return hunk_start(h, new) end
    return clamp(lnum + delta, new)
end

--- Map `pos` ({lnum, col}: 1-based line, 0-based byte column) from `old` to `new`.
function M.map(old, new, pos)
    local lnum, col = pos[1], pos[2]
    local h, delta = locate(hunks(old, new), lnum)
    if not h then return { clamp(lnum + delta, new), col } end
    local line = old[lnum] or ""
    local first = math.max(0, col - NEEDLE)
    local around = line:sub(first + 1, col + NEEDLE)
    local before, after = line:sub(first + 1, col), line:sub(col + 1, col + NEEDLE)
    -- Exact text around the column first, then each side of it alone.
    local tries = { { around, col - first }, { before, #before }, { after, 0 } }
    for i, t in ipairs(tries) do
        if #t[1] >= (i == 1 and 1 or MIN_PART) then
            local l, at = find(h, new, t[1])
            if l then return { l, at + t[2] } end
        end
    end
    return { hunk_start(h, new), 0 }
end

return M
