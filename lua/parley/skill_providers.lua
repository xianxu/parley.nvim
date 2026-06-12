-- parley.skill_providers — skill sources, all emitting uniform SkillManifests.
--
-- A provider is just `{ list = function() → {SkillManifest…} }`. The registry
-- (skill_registry.lua) unions providers; consumers never branch on origin —
-- the disk/virtual difference lives entirely inside how the provider built the
-- manifest's `source` closure.
--
-- DiskProvider scans a root dir and loads each `<dir>/init.lua` by ABSOLUTE
-- path (`loadfile`, so it works for the plugin root AND `~/.config/parley/
-- skills/` alike — not just package-path requires). The manifest's `source` is
-- a closure capturing that absolute dir, which DELETES the v1 `debug.getinfo`
-- path-guessing dance (skill_runner.lua:226,376-392): the path is already in
-- hand at discovery time.

local M = {}

local function read_file(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local content = f:read("*a")
    f:close()
    return content
end

-- Build a manifest from a loaded skill-definition table + its absolute dir.
-- Source resolution (the unified `source(ctx)` contract):
--   1. an explicit `source` function (the new declarative field), else
--   2. `<dir>/SKILL.md` read via a closure over `dir`, else
--   3. a v1 `system_prompt` function (transitional back-compat).
local function manifest_from_def(def, dir)
    local source
    if type(def.source) == "function" then
        source = def.source
    elseif read_file(dir .. "/SKILL.md") ~= nil then
        source = function()
            return read_file(dir .. "/SKILL.md") or ""
        end
    elseif type(def.system_prompt) == "function" then
        source = function(ctx)
            return def.system_prompt(ctx)
        end
    end
    return {
        name = def.name,
        description = def.description,
        scope = def.scope,
        activation = def.activation,
        source = source,
        tools = def.tools,
        elevated = def.elevated,
        force_tool = def.force_tool,
        args = def.args,
        agent = def.agent,
    }
end

--- A disk provider over `root` (a dir of `<name>/init.lua` skill dirs).
--- Emits CANDIDATE manifests — a dir with a `name` but no resolvable body
--- (no `source`/SKILL.md/`system_prompt`) yields `source = nil`; the registry
--- is the single validation point and validate-drops such a candidate.
--- @param root string absolute directory path
--- @return table provider with a `list()` method
function M.disk(root)
    return {
        list = function()
            local out = {}
            local handle = vim.loop.fs_scandir(root)
            if not handle then
                return out
            end
            while true do
                local name, typ = vim.loop.fs_scandir_next(handle)
                if not name then
                    break
                end
                if typ == "directory" then
                    local dir = root .. "/" .. name
                    local initpath = dir .. "/init.lua"
                    if read_file(initpath) ~= nil then
                        local ok, def = pcall(function()
                            return loadfile(initpath)()
                        end)
                        if ok and type(def) == "table" then
                            -- support both { name, ... } and { skill = { ... } }
                            local skill = def.skill or def
                            if type(skill.name) == "string" then
                                table.insert(out, manifest_from_def(skill, dir))
                            end
                        end
                    end
                    -- dir without a loadable init.lua/name → skipped (not an error)
                end
            end
            return out
        end,
    }
end

--- A virtual provider over a list of generators (`function() → SkillManifest`).
--- The seam for runtime-generated skills (the first, `repo_discovery`, arrives
--- in M5). A generator that errors is skipped (it shouldn't sink discovery).
--- @param generators table list of zero-arg manifest generators
--- @return table provider with a `list()` method
function M.virtual(generators)
    return {
        list = function()
            local out = {}
            for _, gen in ipairs(generators or {}) do
                local ok, m = pcall(gen)
                if ok and type(m) == "table" then
                    table.insert(out, m)
                end
            end
            return out
        end,
    }
end

return M
