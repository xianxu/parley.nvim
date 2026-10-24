-- Leaves libuv's cached loop clock behind real time (#421): a busy wait never
-- yields, so the loop cannot refresh its clock. A deadline timer armed right
-- after this, without helper.start_deadline's refresh, starts that far late.
local M = {}
local uv = vim.uv or vim.loop

function M.block(ms)
    local stop = uv.hrtime() + ms * 1e6
    while uv.hrtime() < stop do end
end

return M
