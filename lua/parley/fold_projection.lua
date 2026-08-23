-- Pure projection of semantic exchange blocks into buffer fold ranges.

local M = {}

local fence = require("parley.fence")

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
---
--- It consumes the fence grammar rather than matching the prefix raw. Since M2,
--- a `💬:` inside a tool body is legitimate CONTENT — tool output routinely
--- quotes transcripts — so a raw match would reject a correct projection and
--- refuse the whole exchange. Only a marker outside the fenced body signals the
--- drift this guard exists to catch.
--- @return boolean ok, integer|nil failed_range_index
function M.verify_anchors(ranges, lines, patterns)
    -- Patterns are required lazily so the module LOADS without a Neovim global.
    -- It does not follow that this function RUNS without one: the anchor check
    -- needs `highlight_structure.classify`, which reaches `parley.define` and
    -- touches `vim`. `verify_starts` and `ranges_within` are callable with vim
    -- absent; `verify_anchors` is not, and claiming otherwise was wrong.
    -- Assigned UNCONDITIONALLY (#203 BR-17). It used to be set only inside the
    -- `not patterns` branch or as a side effect of the classify closure running,
    -- so a caller passing `patterns` WITH M._classify injected — the seam that
    -- line exists for — left it nil, and the first tool range indexed a nil
    -- value. Requiring here is still lazy enough: this is function scope, so the
    -- module continues to LOAD without a Neovim global.
    local highlight_structure = require("parley.highlight_structure")
    patterns = patterns or highlight_structure.patterns()
    local classify = M._classify or function(line, p)
        return highlight_structure.classify(line, p)
    end
    local user_pattern = patterns.user_pattern
    for index, range in ipairs(ranges) do
        local anchor = lines[range.start_0]
        if anchor == nil then return false, index end
        if classify(anchor, patterns).kind ~= M.anchor_kind(range.kind) then
            return false, index
        end
        -- The interior asks one question per row — "is this a user turn?" — so
        -- match the prefix directly rather than running the full classifier.
        -- This runs per streamed chunk over an entire exchange span, and full
        -- classification costs ~10 pattern matches plus a footnote lookup per
        -- line. Any line the classifier would call `user` matches this pattern,
        -- because no earlier branch can claim a line starting with the user
        -- prefix at column 0.
        --
        -- Lines inside the block's fenced body are skipped: there a marker is
        -- content, not a turn (#200 M2).
        -- Only tool blocks have a fenced body, and it opens on the line
        -- immediately after the marker — the serialized shape. Tracking fences
        -- for any kind, or entering body mode anywhere in the range, would let
        -- one grammar-rejected opener (render_buffer emits
        -- ```json {"type": "request"}) desync the scan and silently disable
        -- this guard for the rest of the range.
        -- Body rows from the same depth-aware pass the parser uses, so this
        -- guard cannot disagree with it about where a body is. Depth matters
        -- here too: without it the guard suppressed its own user-pattern check
        -- over rows that were never a body, and a folded question slipped
        -- through M1's last line of defence (BR-43).
        local body_rows = {}
        if range.kind == "tool_use" or range.kind == "tool_result" then
            local window = {}
            for row = range.start_0, range.end_0 do
                window[row - range.start_0 + 1] = lines[row]
            end
            -- One classify per line, memoized: this runs per streamed chunk, and
            -- the two predicates asked the same question twice (#203 BR-7).
            local kind_of = {}
            local function kind(line)
                local k = kind_of[line]
                if k == nil then
                    k = classify(line, patterns).kind
                    kind_of[line] = k
                end
                return k
            end
            local found = fence.scan(window, function(line)
                local k = kind(line)
                return k == "tool_use" or k == "tool_result"
            end, function(line)
                return highlight_structure.is_structural_kind(kind(line))
            end)
            for k in pairs(fence.body_rows(found)) do
                body_rows[range.start_0 + k - 1] = true
            end
        end
        for row = range.start_0 + 1, range.end_0 do
            local line = lines[row]
            if line == nil then return false, index end
            if not body_rows[row] and line:match(user_pattern) then
                return false, index
            end
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
