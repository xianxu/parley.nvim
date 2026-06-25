-- Per-buffer lease state for pending chat responses.
--
-- A lease records the buffer changedtick that is valid for the next async
-- callback. Guarded Parley-owned writes call commit() with the new tick; any
-- other tick drift invalidates the lease so late callbacks do not mutate a
-- transcript whose structure may have changed under the live exchange_model.

local M = {}

local leases = {}
local next_generation = 0

local function stale_reason()
    return "stale chat lease generation"
end

function M.begin(buf, changedtick, meta)
    next_generation = next_generation + 1
    leases[buf] = {
        generation = next_generation,
        baseline_changedtick = changedtick,
        valid = true,
        reason = nil,
        meta = meta or {},
    }
    return next_generation
end

function M.current(buf)
    return leases[buf]
end

function M.validate(buf, generation, current_changedtick)
    local lease = leases[buf]
    if not lease then
        return false, "missing chat lease"
    end
    if lease.generation ~= generation then
        return false, stale_reason()
    end
    if not lease.valid then
        return false, lease.reason or "invalid chat lease"
    end
    if lease.baseline_changedtick ~= current_changedtick then
        lease.valid = false
        lease.reason = "chat transcript changed during pending request"
        return false, lease.reason
    end
    return true
end

function M.commit(buf, generation, changedtick)
    local lease = leases[buf]
    if not lease or lease.generation ~= generation or not lease.valid then
        return false
    end
    lease.baseline_changedtick = changedtick
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
        leases[buf] = nil
    end
end

function M._reset()
    leases = {}
    next_generation = 0
end

return M
