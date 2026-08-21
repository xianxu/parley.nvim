-- Pure semantic segmentation for the lines inside one assistant answer.

local M = {}

local fence = require("parley.fence")

local BOUNDARY = {
    reasoning = true,
    summary = true,
    tool_use = true,
    tool_result = true,
    user = true,
    assistant = true,
    branch = true,
    ["local"] = true,
}

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
        elseif kind == "tool_use" or kind == "tool_result" then
            -- Match the fence by LENGTH, via the shared grammar. Classifying on
            -- `fence` alone closes on any >=3-backtick run, so a nested ``` in
            -- a tool body ended the section early and its tail was emitted as
            -- unfoldable text (#200).
            local last = i
            local open_len = nil
            local closed = false
            local boundary_before_close = nil
            local cursor = i + 1
            while cursor <= #lines do
                local line = lines[cursor]
                if not open_len then
                    open_len = fence.open_len(line)
                    if open_len then
                        last = cursor
                    elseif BOUNDARY[kinds[cursor]] then
                        break
                    else
                        last = cursor
                    end
                elseif fence.closes(line, open_len) then
                    last = cursor
                    closed = true
                    cursor = cursor + 1
                    break
                else
                    -- Remember the first boundary seen inside an open fence: if
                    -- the fence never closes, the section stops here rather
                    -- than swallowing the rest of the answer.
                    if boundary_before_close == nil and BOUNDARY[kinds[cursor]] then
                        boundary_before_close = cursor
                    end
                    last = cursor
                end
                cursor = cursor + 1
            end
            -- Gate on `not closed`, not on running off the end: a body whose
            -- close IS the last line also leaves cursor > #lines, and rewinding
            -- there truncates a correctly closed block at its opener (BR-29).
            if open_len and not closed and boundary_before_close then
                -- Unterminated: rewind to just before the first boundary so the
                -- blocks after it still segment.
                last = boundary_before_close - 1
                cursor = boundary_before_close
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
