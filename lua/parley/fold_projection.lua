-- Pure projection of semantic exchange blocks into buffer fold ranges.

local M = {}

local FOLDABLE = {
    thinking = true,
    summary = true,
    tool_use = true,
    tool_result = true,
}

--- Whether a block kind folds. An accessor rather than the live table, so a
--- consumer reads the policy without being able to mutate it.
function M.is_foldable(block_kind)
    return FOLDABLE[block_kind] == true
end

-- Block kinds carry answer_structure's vocabulary; a buffer line is classified
-- with highlight_structure's. They agree except for thinking, whose marker
-- classifies as "reasoning". Named once, so the two vocabularies cannot drift.
local ANCHOR_KIND = {
    thinking = "reasoning",
    summary = "summary",
    tool_use = "tool_use",
    tool_result = "tool_result",
}

--- The structural kind a foldable block's first line must classify as.
--- @return string|nil  nil when the block kind is not foldable
function M.anchor_kind(block_kind)
    return ANCHOR_KIND[block_kind]
end

--- Check that an exchange's span really is that exchange: it starts on its own
--- question line and covers no other question.
---
--- The span is the input to fold *destruction*, and it comes from the same
--- possibly-stale model as the fold ranges. Verifying only the ranges leaves
--- the destructive half unchecked — and when an exchange has no foldable block
--- the range list is empty, so range verification passes vacuously while a
--- drifted span still gets cleared. That deletes a neighbouring exchange's
--- fold, which nothing recreates (`hydrate_window` latches per buf/win), so the
--- "always folded" invariant breaks for the rest of the session (#200 C1).
--- @return boolean
function M.verify_span(first_0, last_0, lines, patterns)
    patterns = patterns or require("parley.highlight_structure").patterns()
    local first = lines[first_0]
    if first == nil or not first:match(patterns.user_pattern) then return false end
    for row = first_0 + 1, last_0 do
        local line = lines[row]
        if line == nil then return false end
        if line:match(patterns.user_pattern) then return false end
    end
    return true
end

--- Check that a range really describes the block it claims: its first line
--- carries the block's marker, and no line it covers is a user question.
---
--- `lines` maps a 0-based buffer row to its text for every row the ranges
--- cover; a missing row means the range runs past the end of the buffer. The
--- caller reads the buffer once and hands the map in, so this stays pure.
---
--- The interior scan is what defends "a question is never INSIDE a fold":
--- end-drift can leave a valid anchor while the range overshoots the next
--- exchange's question.
--- @return boolean ok, integer|nil failed_range_index
function M.verify_anchors(ranges, lines, patterns)
    local highlight_structure = require("parley.highlight_structure")
    patterns = patterns or highlight_structure.patterns()
    local user_pattern = patterns.user_pattern
    for index, range in ipairs(ranges) do
        local anchor = lines[range.start_0]
        if anchor == nil then return false, index end
        if highlight_structure.classify(anchor, patterns).kind ~= M.anchor_kind(range.kind) then
            return false, index
        end
        -- The interior only ever asks one question — "is this a user turn?" —
        -- so match that prefix directly instead of running the full classifier
        -- over every covered row. This runs per streamed chunk across an entire
        -- exchange span, and full classification costs ~10 pattern matches plus
        -- a footnote lookup per line. Any line the classifier would call `user`
        -- matches this pattern, because no earlier branch can claim a line that
        -- begins with the user prefix at column 0.
        for row = range.start_0 + 1, range.end_0 do
            local line = lines[row]
            if line == nil then return false, index end
            if line:match(user_pattern) then return false, index end
        end
    end
    return true, nil
end

function M.desired_folds(model, exchange_index)
    local exchange = model.exchanges[exchange_index]
    if not exchange then return {} end

    local ranges = {}
    local exchange_start_0 = model:exchange_start(exchange_index)
    local exchange_end_0 = model:last_nonempty_block_end(exchange_index)
    for block_index, block in ipairs(exchange.blocks) do
        if block.size > 0 and FOLDABLE[block.kind] then
            local start_0 = model:block_start(exchange_index, block_index)
            local end_0 = model:block_end(exchange_index, block_index)
            assert(start_0 >= exchange_start_0 and end_0 <= exchange_end_0,
                "fold range outside exchange bounds")
            ranges[#ranges + 1] = {
                block_index = block_index,
                kind = block.kind,
                start_0 = start_0,
                end_0 = end_0,
            }
        end
    end
    return ranges
end

return M
