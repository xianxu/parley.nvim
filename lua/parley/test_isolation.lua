-- The one rule that keeps tests away from the operator's real state (#342):
-- under the harness, HOME and every XDG root resolve inside the isolated root
-- the Makefile exports as PARLEY_TEST_ENV_ROOT. The harness init refuses to run
-- a spec when this fails; cliproxy refuses to write outside it in test mode.
local M = {}

--- Every root the harness must pin inside PARLEY_TEST_ENV_ROOT (Makefile.parley
--- TEST_ENV), in check order. A root left unpinned would let an operator's own
--- export of it refuse every harness run.
M.ROOTS = { "HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME" }

local function resolved(path)
    if type(path) ~= "string" or path == "" then return nil end
    local absolute = vim.fn.fnamemodify(path, ":p"):gsub("/+$", "")
    -- A root that does not exist yet still has to be judged: resolve its nearest
    -- existing ancestor, so /tmp vs /private/tmp style links compare alike.
    local real = (vim.uv or vim.loop).fs_realpath(absolute)
    if real then return real end
    local parent, leaf = vim.fs.dirname(absolute), vim.fs.basename(absolute)
    local up = parent ~= absolute and resolved(parent)
    return up and (up .. "/" .. leaf) or absolute
end

--- Whether `path` lies inside `root` (or is it), with links resolved.
---@param root string|nil
---@param path string|nil
---@return boolean
function M.inside(root, path)
    local r, p = resolved(root), resolved(path)
    if not r or not p then return false end
    return p == r or p:sub(1, #r + 1) == r .. "/"
end

--- What is not isolated in `env` (default: the process environment), as
--- reasons; empty means isolated.
---@param env table|nil
---@return string[]
function M.check(env)
    env = env or vim.env
    local root = env.PARLEY_TEST_ENV_ROOT
    if type(root) ~= "string" or root == "" then
        return { "PARLEY_TEST_ENV_ROOT is unset: this is not the harness's isolated environment" }
    end
    local reasons = {}
    for _, name in ipairs(M.ROOTS) do
        local value = env[name]
        if value == nil or value == "" then
            reasons[#reasons + 1] = name .. " is unset"
        elseif not M.inside(root, value) then
            reasons[#reasons + 1] = ("%s=%s is outside %s"):format(name, value, root)
        end
    end
    return reasons
end

return M
