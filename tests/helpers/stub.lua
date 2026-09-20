-- Replace a table field for the length of `body`, restoring it on every path
-- (#261 M4 review, family `stub-restored-outside-finally`). A stub restored
-- after its assertions leaks into every later case when one of them fails.
local M = {}

---@param tbl table
---@param key any
---@param value any # the stand-in while `body` runs
---@param body function
function M.with_stub(tbl, key, value, body)
    local original = tbl[key]
    tbl[key] = value
    local ok, err = pcall(body)
    tbl[key] = original
    if not ok then error(err, 0) end
end

return M
