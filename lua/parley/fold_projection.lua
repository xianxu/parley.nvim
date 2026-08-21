-- Pure projection of semantic exchange blocks into buffer fold ranges.

local M = {}

-- The fold policy, stated once: a block kind folds exactly when it has a marker
-- line to anchor on, and this maps each to the kind that line must classify as.
-- Block kinds carry answer_structure's vocabulary; a buffer line is classified
-- with highlight_structure's. They agree except for thinking, whose marker
-- classifies as "reasoning".
--
-- FOLDABLE is derived rather than restated. Two hand-maintained key sets would
-- drift, and the drift is silent and total: a kind foldable here but missing
-- there yields a range whose anchor_kind is nil, verification fails, and the
-- whole exchange refuses to fold (ARCH-DRY).
local ANCHOR_KIND = {
    thinking = "reasoning",
    summary = "summary",
    tool_use = "tool_use",
    tool_result = "tool_result",
}

local FOLDABLE = {}
for kind in pairs(ANCHOR_KIND) do FOLDABLE[kind] = true end

--- Whether a block kind folds. An accessor rather than the live table, so a
--- consumer reads the policy without being able to mutate it.
function M.is_foldable(block_kind)
    return FOLDABLE[block_kind] == true
end

--- The structural kind a foldable block's first line must classify as.
--- @return string|nil  nil when the block kind is not foldable
function M.anchor_kind(block_kind)
    return ANCHOR_KIND[block_kind]
end

--- Validate a whole model's exchange start rows before they are used to
--- install extmark identity.
---
--- Positional reasoning cannot police an *individual* clear — "starts on a
--- question, contains no other" is satisfied equally by a different exchange's
--- rows, which is why identity is anchored rather than computed (#200). But it
--- is exactly right for deciding whether a model is structurally sound enough
--- to anchor FROM: every exchange must begin on a question line, and the starts
--- must be strictly ascending and inside the buffer.
---
--- Exchange 1 is exempt from the question requirement. `chat_parser` fabricates
--- a question block when an answer has no preceding question
--- (`chat_parser.lua:623-635`), leaving that start on prose or a blank line;
--- refusing it would make identity permanently unavailable for such
--- transcripts. Only index 1 can reach that path — it fires when
--- `current_exchange` is nil, and `current_exchange` is never reset to nil.
--- @return boolean
function M.verify_starts(starts_0, lines, patterns)
    patterns = patterns or require("parley.highlight_structure").patterns()
    if #starts_0 == 0 then return false end
    local previous = -1
    for index, row in ipairs(starts_0) do
        if row <= previous then return false end
        previous = row
        local line = lines[row]
        if line == nil then return false end
        if index > 1 and not line:match(patterns.user_pattern) then return false end
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
    -- Required lazily and only when the caller did not supply patterns, so the
    -- module stays callable — not merely loadable — without a Neovim global.
    local highlight_structure
    if not patterns then
        highlight_structure = require("parley.highlight_structure")
        patterns = highlight_structure.patterns()
    end
    local classify = M._classify or function(line, p)
        highlight_structure = highlight_structure or require("parley.highlight_structure")
        return highlight_structure.classify(line, p)
    end
    local user_pattern = patterns.user_pattern
    for index, range in ipairs(ranges) do
        local anchor = lines[range.start_0]
        if anchor == nil then return false, index end
        if classify(anchor, patterns).kind ~= M.anchor_kind(range.kind) then
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

--- Every range must lie inside the rows the exchange owns.
---
--- Verification proves a range matches the buffer's *text*; identity proves
--- which rows belong to this exchange. Only containment proves they describe
--- the same exchange — without it a stale model's ranges can verify against a
--- later exchange's markers while the clear removes this one's rows (#200).
--- @return boolean ok, integer|nil failed_range_index
function M.ranges_within(ranges, first_0, last_0)
    if first_0 == nil or last_0 == nil then return false, nil end
    for index, range in ipairs(ranges) do
        if range.start_0 < first_0 or range.end_0 > last_0 then return false, index end
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
