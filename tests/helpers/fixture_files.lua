-- Native-only cleanup works in the orphan watchdog's fast-event context.
-- Callers establish ownership of the root; links are removed, never followed.
local uv = vim.uv or vim.loop
local M = {}

function M.remove_tree(path)
    local stat, err, code = uv.fs_lstat(path)
    if not stat then return code == 'ENOENT', err end
    if stat.type ~= 'directory' then return uv.fs_unlink(path) end
    local scan, scan_err = uv.fs_scandir(path)
    if not scan then return nil, scan_err end
    while true do
        local name = uv.fs_scandir_next(scan)
        if not name then break end
        local ok, child_err = M.remove_tree(path .. '/' .. name)
        if not ok then return nil, child_err end
    end
    return uv.fs_rmdir(path)
end

return M
