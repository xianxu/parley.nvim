-- Pure semantic segmentation for the lines inside one assistant answer.

local M = {}

local fence = require("parley.fence")
local highlight_structure = require("parley.highlight_structure")

-- Derived, not hand-listed (#203 BR-3): this is
-- highlight_structure.STRUCTURAL_KINDS plus `reasoning`. The two sets
-- legitimately differ — a 🧠: TERMINATES a preceding block, so it is a boundary
-- here, but it is not a structural marker a tool body may not span, so it is not
-- in STRUCTURAL_KINDS. Stating that difference once beats maintaining two
-- near-identical tables that drift apart silently (ARCH-DRY).
local BOUNDARY = { reasoning = true }
for kind in pairs(highlight_structure.STRUCTURAL_KINDS) do
    BOUNDARY[kind] = true
end

local function trim_span(lines, first, last)
    while first <= last and not lines[first]:match("%S") do first = first + 1 end
    while last >= first and not lines[last]:match("%S") do last = last - 1 end
    if first > last then return nil end
    return first, last
end

function M.reduce(lines, patterns, opts)
    lines = lines or {}
    opts = opts or {}
    local classify = require("parley.highlight_structure").classify
    local kinds = {}
    for i, line in ipairs(lines) do kinds[i] = classify(line, patterns).kind end

    -- Depth-aware body extents, shared with chat_parser and fold_projection so
    -- the three cannot disagree about where a tool body is (#200 BR-43).
    -- Branch on the MODEL the scan returns, not on a set derived from it:
    -- reconstructing extents by walking body rows is lossy, because an EMPTY
    -- body has no rows and reads as "no body" — the section then falls into the
    -- run-to-next-boundary arm and swallows the prose after it (#200 BR-52).
    local bodies, markers = fence.scan(lines, function(_, row)
        return kinds[row] == "tool_use" or kinds[row] == "tool_result"
    end, function(_, row)
        return highlight_structure.is_structural_kind(kinds[row])
    end)

    local explicit_end_for = {}
    local end_ahead = false
    for i = #lines, 1, -1 do
        local kind = kinds[i]
        if kind == "reasoning" then
            explicit_end_for[i] = end_ahead
        elseif kind == "reasoning_end" then
            end_ahead = true
        elseif BOUNDARY[kind] then
            end_ahead = false
        end
    end

    local sections = {}
    local function add(kind, first, last)
        first, last = trim_span(lines, first, last)
        if first then
            sections[#sections + 1] = { kind = kind, line_start = first, line_end = last }
        end
    end

    local i = 1
    while i <= #lines do
        local kind = kinds[i]
        if kind == "reasoning" then
            local explicit = explicit_end_for[i]
            local last = i
            local cursor = i + 1
            while cursor <= #lines do
                local next_kind = kinds[cursor]
                if explicit and next_kind == "reasoning_end" then
                    last = cursor
                    cursor = cursor + 1
                    break
                elseif BOUNDARY[next_kind] then
                    break
                elseif not explicit and next_kind == "blank" then
                    break
                end
                last = cursor
                cursor = cursor + 1
            end
            add("thinking", i, last)
            i = cursor
        elseif kind == "summary" then
            add("summary", i, i)
            i = i + 1
        elseif (kind == "tool_use" or kind == "tool_result") and markers[i] then
            -- One definition of the body's extent, shared with chat_parser and
            -- fold_projection (BR-43). A body exists only when the opener sits
            -- immediately after the marker AND a matching close exists; without
            -- one, the section stops at the next boundary rather than running
            -- to the end of the answer.
            local close_row = bodies[i] and bodies[i].close
            local last, cursor
            if close_row then
                last, cursor = close_row, close_row + 1
            else
                last, cursor = i, i + 1
                while cursor <= #lines and not BOUNDARY[kinds[cursor]] do
                    last = cursor
                    cursor = cursor + 1
                end
            end
            add(kind, i, last)
            i = cursor
        else
            local first = i
            local last = i
            local cursor = i + 1
            while cursor <= #lines and not BOUNDARY[kinds[cursor]] do
                last = cursor
                cursor = cursor + 1
            end
            add("text", first, last)
            i = cursor
        end
    end

    return { sections = sections, work = { rows_visited = #lines }, streaming = opts.streaming == true }
end

return M
