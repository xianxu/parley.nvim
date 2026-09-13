-- Literal-path filesystem operations; deliberately independent of helper/logger.
local M = {}

--- Ensure a directory exists, including when another process creates it first.
--- @param path string literal directory path (no expansion)
--- @param mode number|nil permissions for newly created directories
function M.ensure_dir(path, mode)
    local ok, err
    if mode then
        ok, err = pcall(vim.fn.mkdir, path, "p", mode)
    else
        ok, err = pcall(vim.fn.mkdir, path, "p")
    end
    if vim.fn.isdirectory(path) == 1 then
        return
    end
    if not ok then
        error(err, 0)
    end
    error("Cannot create directory: " .. path, 0)
end

return M
