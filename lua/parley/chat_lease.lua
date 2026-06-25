-- Per-buffer lease state for pending chat responses.
--
-- A lease guards the streaming insertion point against *structural* drift: it
-- anchors an extmark (created `invalidate = true`) on the response block's start
-- line. nvim moves that anchor across ordinary edits — typing into the buffer,
-- streaming content into the block, growing/editing other lines — so those do
-- NOT invalidate the lease. Only deleting the anchor line (e.g. undo/redo of the
-- inserted placeholder, or the user removing the `🤖:` block) marks the extmark
-- invalid, which fails validation so late async callbacks don't mutate a
-- transcript whose insertion point no longer exists. (#138 — replaces the #137
-- `changedtick` baseline, which conflated Parley's own writes/spinner frames with
-- genuine out-of-band edits and false-positive-cancelled valid requests.)
--
-- generation guards against stale callbacks from a *previous* request on the
-- same buffer; the anchor extmark guards structural validity.

local M = {}

local ns_id = vim.api.nvim_create_namespace("parley_chat_lease")
local leases = {}
local next_generation = 0

local function del_anchor(buf, lease)
    if lease and lease.ex_id then
        pcall(vim.api.nvim_buf_del_extmark, buf, ns_id, lease.ex_id)
    end
end

-- Anchor the lease on `anchor_line` (0-indexed): the response block's start line.
function M.begin(buf, anchor_line, meta)
    next_generation = next_generation + 1
    del_anchor(buf, leases[buf]) -- drop any prior lease's anchor on this buffer
    -- invalidate=true → nvim flags the mark `invalid` when its line is deleted;
    -- ordinary edits (incl. streaming into the line) leave it valid and move it.
    local ok, ex_id = pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, anchor_line, 0, { invalidate = true })
    leases[buf] = {
        generation = next_generation,
        ex_id = ok and ex_id or nil,
        valid = true,
        reason = nil,
        meta = meta or {},
    }
    return next_generation
end

function M.current(buf)
    return leases[buf]
end

-- True while this generation's lease is live and its anchor line still exists.
-- The third positional arg (the old changedtick) is accepted but ignored so
-- existing call sites need no change.
function M.validate(buf, generation, _ignored_changedtick)
    local lease = leases[buf]
    if not lease then
        return false, "missing chat lease"
    end
    if lease.generation ~= generation then
        return false, "stale chat lease generation"
    end
    if not lease.valid then
        return false, lease.reason or "invalid chat lease"
    end
    if not lease.ex_id or not vim.api.nvim_buf_is_valid(buf) then
        lease.valid = false
        lease.reason = "chat transcript structure changed during pending request"
        return false, lease.reason
    end
    local mark = vim.api.nvim_buf_get_extmark_by_id(buf, ns_id, lease.ex_id, { details = true })
    if not mark or not mark[1] or (mark[3] and mark[3].invalid) then
        lease.valid = false
        lease.reason = "chat transcript structure changed during pending request"
        return false, lease.reason
    end
    return true
end

-- No-op (#138): structural validity now rides the anchor extmark, so there is no
-- baseline to advance. Retained so guarded-write call sites stay unchanged.
function M.commit(buf, generation, _ignored_changedtick)
    local lease = leases[buf]
    if not lease or lease.generation ~= generation or not lease.valid then
        return false
    end
    return true
end

function M.invalidate(buf, reason)
    local lease = leases[buf]
    if lease then
        lease.valid = false
        lease.reason = reason or "chat lease invalidated"
    end
end

function M.clear(buf, generation)
    local lease = leases[buf]
    if lease and (generation == nil or lease.generation == generation) then
        del_anchor(buf, lease)
        leases[buf] = nil
    end
end

function M._reset()
    leases = {}
    next_generation = 0
end

return M
