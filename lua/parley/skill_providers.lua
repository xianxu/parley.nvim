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
-- path-guessing dance (the deleted skill_runner did this): the path is already
-- in hand at discovery time.

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

local function file_exists(path)
    return vim.loop.fs_stat(path) ~= nil
end

-- Build a manifest from a loaded skill-definition table + its absolute dir.
-- Source resolution (the unified `source(ctx)` contract):
--   1. an explicit `source(ctx)` function (the new declarative field), wrapped so
--      the provider injects `ctx.skill_md` from `<dir>/SKILL.md` — the dir is a
--      discovery-time fact the closure already holds, so a dynamic-body skill
--      (voice_apply) composes `ctx.skill_md ⊕ <extra>` without re-deriving the
--      dir (this is v1's 4th `skill_md` arg, minus the debug.getinfo dance).
--   2. else `<dir>/SKILL.md` read via a closure over `dir`.
-- (No v1 `system_prompt` fallback: that 4-arg contract is retired in M4, and no
-- bundled skill needs it — all ship a SKILL.md. A dir with neither yields
-- source = nil and is validate-dropped by the registry.)
local function manifest_from_def(def, dir)
    local source
    if type(def.source) == "function" then
        local inner = def.source
        source = function(ctx)
            ctx = ctx or {}
            -- Enrich (without mutating the caller's table) with two discovery-time
            -- facts the closure already holds: `skill_md` (the dir's SKILL.md, only
            -- if a SKILL.md exists and the caller didn't supply one) and `skill_dir`
            -- (the absolute dir, whenever absent — independent of SKILL.md, since a
            -- dynamic skill like review reads its modes/ subdir from it). #133.
            local needs_md = ctx.skill_md == nil and file_exists(dir .. "/SKILL.md")
            local needs_dir = ctx.skill_dir == nil
            if needs_md or needs_dir then
                local enriched = {}
                for k, v in pairs(ctx) do
                    enriched[k] = v
                end
                if needs_md then
                    enriched.skill_md = read_file(dir .. "/SKILL.md") or ""
                end
                if needs_dir then
                    enriched.skill_dir = dir
                end
                ctx = enriched
            end
            return inner(ctx)
        end
    elseif file_exists(dir .. "/SKILL.md") then
        source = function()
            return read_file(dir .. "/SKILL.md") or ""
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
--- (no `source`/SKILL.md) yields `source = nil`; the registry is the single
--- validation point and validate-drops such a candidate.
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
                    if file_exists(initpath) then
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
