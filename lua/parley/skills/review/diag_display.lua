-- diag_display.lua — inline display of review "why" diagnostics (#133 M6).
--
-- Controls how parley's review explanations render, scoped to parley's OWN
-- diagnostic namespace (never touches the user's LSP / global diagnostics).
-- Default ON: `virtual_lines { current_line = true }`, so the (hard-wrapped) why
-- auto-expands below an edit when the cursor is in that edit's region, and hides
-- otherwise. `:ParleyShowDiagnostics` toggles it.

local M = {}

M.enabled = true -- default on (cursor-region auto-show)

-- Parley's review diagnostic namespace — single-sourced from skill_render (which
-- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
local function ns()
    return require("parley.skill_render").diag_namespace()
end

--- Apply the inline-display config for parley's review namespace.
--- @param on boolean
function M.set(on)
    M.enabled = on and true or false
    vim.diagnostic.config({
        virtual_lines = M.enabled and { current_line = true } or false,
        virtual_text = false,
    }, ns())
end

--- Toggle inline display; returns the new state.
--- @return boolean
function M.toggle()
    M.set(not M.enabled)
    return M.enabled
end

--- Is inline display currently enabled?
--- @return boolean
function M.is_enabled()
    return M.enabled
end

return M
