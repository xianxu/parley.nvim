-- parley.highlight_groups — keep parley's highlight groups across :colorscheme
-- (#386). `:colorscheme` runs `:hi clear`, which drops every group parley
-- defined. Each module that defines groups hands its definer to `keep`, and one
-- ColorScheme autocmd re-runs them all, so a view already on screen keeps its
-- colors. Callers still run their definer themselves when they need it.
local M = {}

-- name -> definer; one per module, so re-registering replaces (no growth).
local definers = {}
local augroup

--- Re-run `define` on every ColorScheme from now on.
--- @param name string   the module's key; a second `keep` under it replaces the first
--- @param define function  sets the module's groups; its return value is ignored
function M.keep(name, define)
    definers[name] = define
    if augroup then return end
    augroup = vim.api.nvim_create_augroup("ParleyHighlightGroups", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = augroup,
        -- Returns nothing: a truthy callback return deletes the autocmd.
        callback = function()
            for _, d in pairs(definers) do d() end
        end,
    })
end

return M
