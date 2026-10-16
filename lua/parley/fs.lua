-- Literal-path filesystem operations; deliberately independent of helper/logger.
local M = {}

-- Create one directory level (no `p`). A failure is success when the level is
-- a directory afterwards: another process created it first.
local function mkdir_level(dir, mode)
    local ok, err
    if mode then
        ok, err = pcall(vim.fn.mkdir, dir, "", mode)
    else
        ok, err = pcall(vim.fn.mkdir, dir)
    end
    if vim.fn.isdirectory(dir) == 1 then
        return
    end
    if not ok then
        error(err, 0)
    end
    error("Cannot create directory: " .. dir, 0)
end

--- Ensure a directory exists, including when another process creates it, or
--- any of its ancestors, first. Walks the path one level at a time instead of
--- `mkdir -p`, which raises E739 when a competitor creates an INTERMEDIATE
--- between its check and its create and leaves the leaf uncreated (#347).
--- @param path string literal directory path (no expansion)
--- @param mode number|nil permissions for newly created directories (every level)
function M.ensure_dir(path, mode)
    if vim.fn.isdirectory(path) == 1 then
        return
    end
    local parent = vim.fn.fnamemodify(path, ":h")
    if parent ~= path and parent ~= "" then
        M.ensure_dir(parent, mode)
    end
    mkdir_level(path, mode)
end

return M
