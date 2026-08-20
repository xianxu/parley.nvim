-- Pure projection of semantic exchange blocks into buffer fold ranges.

local M = {}

local FOLDABLE = {
    thinking = true,
    summary = true,
    tool_use = true,
    tool_result = true,
}

-- Exported so consumers (the corpus harness) read the policy instead of
-- restating it.
M.FOLDABLE = FOLDABLE

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
    local classify = require("parley.highlight_structure").classify
    for index, range in ipairs(ranges) do
        for row = range.start_0, range.end_0 do
            local line = lines[row]
            if line == nil then return false, index end
            local kind = classify(line, patterns).kind
            if row == range.start_0 then
                if kind ~= M.anchor_kind(range.kind) then return false, index end
            elseif kind == "user" then
                return false, index
            end
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
