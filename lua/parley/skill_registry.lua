-- parley.skill_registry — unions skill providers into one registry.
--
-- The single surface the per-turn assembly + the read_skill tool read. Pure
-- given its providers: `discover(providers)` collects every provider's
-- manifests, validates them (a malformed skill is dropped, not fatal —
-- fix-forward), and dedupes by name.
--
-- Precedence: LAST provider wins. Providers are stacked base→override, so the
-- default stack {plugin, user, repo, virtual} lets a user/repo skill shadow a
-- plugin default of the same name. Insertion order in `names()` is first-
-- appearance (stable display) while the value is last-seen (the override).

local manifest = require("parley.skill_manifest")
local providers = require("parley.skill_providers")

local M = {}

--- Union the providers into a registry { get(name), names(), all() }.
--- @param provider_list table list of providers (each `{ list = fn }`), base→override
--- @return table registry
function M.discover(provider_list)
    local by_name, order = {}, {}
    for _, p in ipairs(provider_list or {}) do
        for _, mf in ipairs(p.list()) do
            if manifest.validate(mf) then
                if by_name[mf.name] == nil then
                    table.insert(order, mf.name) -- first-appearance position
                end
                by_name[mf.name] = mf -- last-wins value (override)
            end
        end
    end
    return {
        get = function(name)
            return by_name[name]
        end,
        names = function()
            local out = {}
            for _, n in ipairs(order) do
                table.insert(out, n)
            end
            return out
        end,
        all = function()
            local out = {}
            for _, n in ipairs(order) do
                table.insert(out, by_name[n])
            end
            return out
        end,
    }
end

--- The default provider stack for the live parley install.
--- @param opts table { plugin_root, user_root?, repo_generators?, virtual_generators? }
--- @return table list of providers (base→override order)
function M.default_stack(opts)
    opts = opts or {}
    local stack = {}
    if opts.plugin_root then
        table.insert(stack, providers.disk(opts.plugin_root)) -- base
    end
    if opts.user_root then
        table.insert(stack, providers.disk(opts.user_root)) -- shadows plugin
    end
    -- repo + virtual seams (empty until later milestones / M5)
    table.insert(stack, providers.virtual(opts.repo_generators or {}))
    table.insert(stack, providers.virtual(opts.virtual_generators or {}))
    return stack
end

--- Discover the registry for the live parley install: the plugin skills root
--- (resolved via runtimepath — no debug.getinfo) ∪ the user config root.
--- @param opts table|nil { virtual_generators?, repo_generators? } (M5 hooks)
--- @return table registry
function M.current(opts)
    opts = opts or {}
    local plugin_root = (vim.api.nvim_get_runtime_file("lua/parley/skills", false) or {})[1]
    local user_root = vim.fn.expand("~/.config/parley/skills")
    return M.discover(M.default_stack({
        plugin_root = plugin_root,
        user_root = (vim.fn.isdirectory(user_root) == 1) and user_root or nil,
        repo_generators = opts.repo_generators,
        virtual_generators = opts.virtual_generators,
    }))
end

return M
