-- lua/parley/version_support.lua
--
-- The Neovim versions parley supports (#379), with one owner for the minimum.
-- setup() refuses an older editor, and `make test`'s compat pass asks the
-- installed nvim this same question, so the policy cannot drift between them.
local M = {}

M.MINIMUM = { 0, 11, 0 }

--- Is `version` (shaped like vim.version(): major, minor, patch) at least MINIMUM?
--- @param version {major: integer, minor: integer, patch: integer}
--- @return boolean
function M.supported(version)
    local have = { version.major, version.minor, version.patch }
    for i, want in ipairs(M.MINIMUM) do
        local part = have[i] or 0
        if part ~= want then return part > want end
    end
    return true
end

--- The refusal an unsupported editor shows.
--- @param version {major: integer, minor: integer, patch: integer}
--- @return string
function M.refusal(version)
    return ("parley needs Neovim %s or newer (this is %d.%d.%d)"):format(
        table.concat(M.MINIMUM, "."), version.major, version.minor, version.patch)
end

return M
