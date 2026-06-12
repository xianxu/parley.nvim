-- parley.discovery — the RegistryBuilder: composes the effective registry for
-- the current parley mode and exposes the discovery surface.
--
--   global      → base only
--   repo        → base ∪ local(repo_root)
--   super-repo  → base ∪ union(local over members), deduped (base wins ties)
--
-- The MERGE: repo-relative locate globs (issue/vision/note/plan + repo
-- chat/note) are expanded across [repo_root] + members; absolute/global globs
-- (chat/note's chat_dir/notes_dir) pass through unchanged. So query() spans
-- global ⊕ repo ⊕ siblings by reusing parley's existing root union — no
-- separate root-scope enum needed.
--
-- Mode context is INJECTED into build() so it is pure-ish and testable without
-- real cwd; current() reads it from LIVE config — the deepcopy `M.config` that
-- setup() builds and repo-mode detection / super_repo.lua mutate, NOT the
-- pristine default table from `require("parley.config")` (that table never gets
-- repo_root / super_repo_members, so reading it returns global mode always).
-- Live config arrives via setup(parley), the same injection pattern as
-- super_repo.setup / note_dirs.setup. super_repo.compute_members is the reused
-- member-discovery source (populates config.super_repo_members).

local base = require("parley.discovery.base")
local local_types = require("parley.discovery.local_types")
local registry = require("parley.discovery.registry")
local merge = require("parley.discovery.merge")

local M = {}

-- Injected parley module reference (for live config). Set by setup().
local _parley

--- @param parley table the parley module (M from init.lua)
M.setup = function(parley)
    _parley = parley
end

-- The live config: injected parley's deepcopy if available, else the default
-- table (only the no-setup test path lands here, and it wants defaults).
local function live_config()
    return (_parley and _parley.config) or require("parley.config")
end

--- Build the effective registry for an injected mode context.
--- @param ctx table|nil { config?, repo_root?, super_repo_members? }
---        config defaults to the live config (so base globs track user
---        overrides of chat_dir/notes_dir); repo_root/super_repo_members select
---        the mode.
--- @return table Registry
function M.build(ctx)
    ctx = ctx or {}
    local config = ctx.config or live_config()
    local members = ctx.super_repo_members
    local repo_root = ctx.repo_root

    -- Repo roots to discover local types over and to expand globs across.
    -- super_repo members already include the current repo (compute_members
    -- globs parent/*/.parley), so they supersede the lone repo_root.
    local roots = {}
    if members and #members > 0 then
        for _, m in ipairs(members) do
            table.insert(roots, m.path)
        end
    elseif type(repo_root) == "string" and repo_root ~= "" then
        table.insert(roots, repo_root)
    end

    local base_descriptors = base.build(config)
    local base_names = {}
    for _, d in ipairs(base_descriptors) do
        table.insert(base_names, d.name)
    end

    -- Compose base ∪ local (base first → base wins ties). The dedupe + the
    -- glob expansion are pure (merge.lua); this glue only supplies the IO half
    -- (local_types.discover per root) and the per-descriptor find-hint stash.
    local lists = { base_descriptors }
    for _, root in ipairs(roots) do
        table.insert(lists, local_types.discover(root, base_names))
    end

    -- Materialize descriptors with merged locate globs. The render() find-hint
    -- is computed from the RELATIVE descriptor and stashed BEFORE expansion, so
    -- the #128 noun-vocabulary never embeds absolute, machine-specific roots.
    local descriptors = {}
    for _, composed in ipairs(merge.dedupe_compose(lists)) do
        local d = vim.deepcopy(composed)
        d.find_hint = registry.find_hint(d)
        d.locate = merge.expand_locate(d.locate, roots)
        table.insert(descriptors, d)
    end
    return registry.of(descriptors)
end

--- Build the registry for the live parley mode. Reads the LIVE config
--- (repo_root + super_repo_members) populated by repo-mode detection and
--- super_repo.compute_members — NOT the default config table.
--- @return table Registry
function M.current()
    local config = live_config()
    return M.build({
        config = config,
        repo_root = config.repo_root,
        super_repo_members = config.super_repo_members,
    })
end

return M
