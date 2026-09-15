local M = {}
-- Retire editor ownership before deleting fixture files. Hidden buffers otherwise
-- survive into later edit commands, which can emit E211 for removed artifacts.
function M.remove(dir)
    local prefix = vim.fn.resolve(vim.fn.fnamemodify(dir, ":p")):gsub("/$", "") .. "/"
    for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.fn.resolve(vim.api.nvim_buf_get_name(candidate))
        if name:sub(1, #prefix) == prefix then
            vim.api.nvim_buf_delete(candidate, { force = true })
        end
    end
    vim.fn.delete(dir, "rf")
end

return M
