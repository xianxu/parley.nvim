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

return M
