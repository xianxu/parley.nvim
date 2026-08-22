-- Extmark-anchored identity for chat exchanges.
--
-- A row-span is not an identity. Fold reconciliation clears the rows an
-- exchange owns, and it takes those rows from a live model that can drift from
-- the buffer. Positional checks cannot close that gap: "starts on a question,
-- contains no other question" is satisfied just as well by a *different*
-- exchange's rows, so a drifted span can clear a neighbour's folds and nothing
-- recreates them (#200).
--
-- An extmark per exchange start fixes the identity to a line rather than a row
-- number. Neovim moves marks across ordinary edits and flags one `invalid` only
-- when its own line is deleted, so a mark set from a verified parse keeps
-- pointing at the same exchange through edits the model never saw. Same
-- property `chat_lease` relies on for the streaming insertion point (#138).

local M = {}

local ns_id = vim.api.nvim_create_namespace("parley_exchange_anchors")
local anchors = {}

-- Resolved rows per buffer, keyed by changedtick. span() reads EVERY anchor to
-- detect re-indexing (the round-7 aliasing fix), which makes it O(number of
-- exchanges in the chat) — and reconcile runs it twice per streamed chunk, so
-- on a long chat that cost scales with chat length rather than exchange length.
-- Caching on changedtick is exact: extmarks move only on edits, and every edit
-- bumps the tick.
local resolved = {}

--- Replace every anchor on `buf` with one per exchange start row (0-indexed,
--- ascending). Call only with rows from a model that has verified against the
--- buffer — anchoring a stale parse would install misleading identity.
function M.set(buf, starts_0)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
    local ids = {}
    local line_count = vim.api.nvim_buf_line_count(buf)
    for index, row in ipairs(starts_0 or {}) do
        if row < 0 or row >= line_count then return M.clear(buf) end
        local ok, id = pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, row, 0,
            { invalidate = true })
        if not ok then return M.clear(buf) end
        ids[index] = id
    end
    anchors[buf] = ids
    resolved[buf] = nil
end

--- Live row of anchor `index`, or nil when it is missing or its line was
--- deleted.
local function anchor_row(buf, ids, index)
    local id = ids[index]
    if not id then return nil end
    local mark = vim.api.nvim_buf_get_extmark_by_id(buf, ns_id, id, { details = true })
    if not mark or not mark[1] then return nil end
    if mark[3] and mark[3].invalid then return nil end
    return mark[1]
end

--- The [first_0, last_0] rows exchange `k` owns, read from live mark positions.
--- Returns nil whenever identity cannot be established, so the caller falls
--- back rather than clearing rows it cannot prove it owns.
---
--- `count` is the model's exchange count and must match the anchor count.
---
--- EVERY anchor must still resolve, strictly ascending — not merely the two
--- bounding this exchange. A count check alone is fooled by a compensating
--- edit: delete one exchange and add another and the count is unchanged, but
--- index k now names a different exchange. That is ordinary usage — prune an
--- old exchange to shed context, then ask the next question — and it is the
--- aliasing this module exists to prevent, so a single unresolvable or
--- out-of-order anchor anywhere invalidates the whole mapping.
--- Resolve every anchor once per buffer state. Returns nil when the mapping is
--- no longer trustworthy; the nil is cached too, so a drifted buffer does not
--- re-walk the anchors on every chunk.
local function resolved_rows(buf, ids)
    local tick = vim.api.nvim_buf_get_var(buf, "changedtick")
    local hit = resolved[buf]
    if hit and hit.tick == tick and hit.count == #ids then return hit.rows end

    local rows, previous = {}, -1
    for index = 1, #ids do
        local row = anchor_row(buf, ids, index)
        if not row or row <= previous then rows = nil break end
        rows[index], previous = row, row
    end
    resolved[buf] = { tick = tick, count = #ids, rows = rows }
    return rows
end

function M.span(buf, k, count)
    if not vim.api.nvim_buf_is_valid(buf) then return nil end
    local ids = anchors[buf]
    if not ids or #ids == 0 or #ids ~= count then return nil end
    if k < 1 or k > #ids then return nil end

    local rows = resolved_rows(buf, ids)
    if not rows then return nil end

    if k == #ids then
        return rows[k], math.max(vim.api.nvim_buf_line_count(buf) - 1, rows[k])
    end
    return rows[k], rows[k + 1] - 1
end

function M.clear(buf)
    anchors[buf] = nil
    resolved[buf] = nil
    if vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.api.nvim_buf_clear_namespace, buf, ns_id, 0, -1)
    end
end

return M
