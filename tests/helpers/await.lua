-- Block a spec on an async call: run fn(done) and wait until it calls
-- done(result). The wait loop lives here once (ARCH-DRY, #237 review); each
-- spec passes its own budget, because the budget belongs to what it waits on.
local M = {}

--- Wait up to `ms` for fn(done) to call done(result). Returns settled, result,
--- for specs that assert on `settled` with their own message.
---@param fn fun(done: fun(result: any))
---@param ms integer
---@return boolean settled
---@return any result
function M.settle(fn, ms)
    local result, got = nil, false
    fn(function(r)
        result = r
        got = true
    end)
    vim.wait(ms, function()
        return got
    end, 20)
    return got, result
end

--- Like settle, but a call that never answers fails the spec. Returns result.
---@param fn fun(done: fun(result: any))
---@param ms integer
---@return any
function M.await(fn, ms)
    local got, result = M.settle(fn, ms)
    assert(got, "async call timed out")
    return result
end

--- Wait for `predicate` while `progress()` keeps changing (#293). A fixed
--- budget can't tell a slow convergence from a stuck one: long repair after a
--- large write can take seconds under load, and a longer blind timeout only
--- hides a real stall for longer. This fails when progress has not moved for
--- `stall_ms`, or at `ceiling_ms` whatever progress reports.
---@param predicate fun(): boolean
---@param progress fun(): any # a value that changes while work is advancing
---@param stall_ms integer
---@param ceiling_ms? integer # default 60000
---@return boolean settled
---@return string? why # "stalled" or "ceiling" when not settled
function M.until_progress(predicate, progress, stall_ms, ceiling_ms)
    local uv = vim.uv or vim.loop
    local start = uv.now()
    local last, moved = progress(), uv.now()
    while true do
        if vim.wait(math.min(50, stall_ms), predicate, 1) then return true end
        uv.update_time()
        local now, current = uv.now(), progress()
        if current ~= last then last, moved = current, now end
        if now - moved >= stall_ms then return false, "stalled" end
        if now - start >= (ceiling_ms or 60000) then return false, "ceiling" end
    end
end

return M
