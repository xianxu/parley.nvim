-- parley.discovery.registry — `name → TypeDescriptor` plus the pure consumers.
--
-- Two surfaces, both PURE given the descriptor set:
--   query(type, term) → DiscoverySpec   decide the search (noun + optional term)
--   spec_to_command(spec) → string      compile the spec to an rg pipeline
--   render() → string                   noun-vocabulary text (the #128 consumer)
--
-- DiscoverySpec = { roots = {glob…}, content_term = string|nil,
--                   frontmatter = {field, value}|nil }
--
-- The query → spec → command split is the "deterministic shell, thin model"
-- seam: the model only ever decides which noun + which term; the registry
-- compiles the actual search. Execution (running the command) is IO and lives
-- consumer-side (M2) — keep search logic out of the model layer.

local M = {}

local Registry = {}
Registry.__index = Registry

--- Construct a Registry from a list of TypeDescriptors.
--- @param descriptors table list of TypeDescriptor
--- @return table registry
function M.of(descriptors)
    local by_name = {}
    local order = {}
    for _, d in ipairs(descriptors) do
        by_name[d.name] = d
        table.insert(order, d.name)
    end
    return setmetatable({ _by_name = by_name, _order = order }, Registry)
end

--- @param name string
--- @return table|nil descriptor
function Registry:get(name)
    return self._by_name[name]
end

--- @return table list of registered type names (registration order)
function Registry:names()
    local out = {}
    for _, name in ipairs(self._order) do
        table.insert(out, name)
    end
    return out
end

--- Turn a noun + optional content term into a DiscoverySpec.
--- Only a `frontmatter`-kind matcher contributes a frontmatter filter; for
--- the other kinds the `locate` glob alone discriminates (so frontmatter=nil).
--- @param type_name string
--- @param term string|nil
--- @return table|nil spec  nil for an unknown type (mirrors get's miss)
function Registry:query(type_name, term)
    local d = self._by_name[type_name]
    if not d then
        return nil
    end
    local frontmatter = nil
    if d.matcher.kind == "frontmatter" then
        frontmatter = { field = d.matcher.field, value = d.matcher.value }
    end
    return {
        roots = vim.deepcopy(d.locate),
        content_term = term,
        frontmatter = frontmatter,
    }
end

-- A stable, machine-independent "how to find instances" hint derived from the
-- descriptor's matcher/locate — the single source for render()'s search column.
-- For filename/any kinds the hint is the primary `locate` glob; callers that
-- expand globs to absolute roots (RegistryBuilder) must precompute and stash
-- `d.find_hint` from the RELATIVE descriptor BEFORE expansion, so render() never
-- embeds an absolute, machine-specific path (the #128 contract stays
-- deterministic on the *built* registry, not just the base one).
--- @param d table TypeDescriptor (relative locate)
--- @return string
function M.find_hint(d)
    local m = d.matcher
    if m.kind == "frontmatter" then
        return "type: " .. m.value
    elseif m.kind == "frontmatter_present" then
        return "header `" .. m.field .. ":`"
    end
    -- filename / any → the (repo-relative) primary locate glob discriminates.
    return d.locate[1]
end

--- Render the noun-vocabulary text — one bullet per type, sorted by name.
--- This IS the body of parley.nvim#128's virtual `repo_discovery` skill:
--- "what file types (nouns) exist in this repo and how to find their
--- instances." Deterministic; the verbatim-line assertions in the spec guard
--- the format as a contract with #128.
--- @return string
function Registry:render()
    local names = self:names()
    table.sort(names)
    local lines = {}
    for _, name in ipairs(names) do
        local d = self._by_name[name]
        -- Prefer a precomputed relative hint (set by RegistryBuilder before it
        -- expands globs to absolute roots); fall back to deriving from this
        -- descriptor (correct when locate is still relative, e.g. base-only).
        local hint = d.find_hint or M.find_hint(d)
        table.insert(
            lines,
            "- " .. d.label .. " (`" .. d.name .. "`) — " .. d.blurb .. "; find by " .. hint
        )
    end
    return table.concat(lines, "\n")
end

-- Split a locate glob into (search_dir, name_glob): the leading wildcard-free
-- directory prefix becomes an rg positional search PATH; the remainder is the
-- RELATIVE `-g` filename pattern. This is the I-B root-cause fix (#116 M2): on the
-- BUILT registry the locate globs are absolute (repo-prefixed), so the old
-- `rg … -g '<abs>' .` matched nothing (an absolute `-g` glob never matches the
-- relative paths rg walks under `.`). Passing the dir as a positional path makes
-- rg search there, and a relative `-g` matches names at/under it. Pure.
--   "/abs/workshop/issues/*.md" → ("/abs/workshop/issues", "*.md")
--   "**/*.md"                   → (".", "**/*.md")
--   "workshop/issues/*.md"      → ("workshop/issues", "*.md")
--- @param glob string
--- @return string search_dir
--- @return string|nil name_glob  nil when the glob has no wildcard (a literal path)
local function split_glob(glob)
    local wc = glob:find("[%*%?%[]") -- first wildcard byte, or nil
    if not wc then
        return glob, nil -- literal path: search it directly, no -g filter
    end
    -- last '/' at or before the first wildcard → the dir/pattern boundary
    local boundary = glob:sub(1, wc - 1):find("/[^/]*$")
    if not boundary then
        return ".", glob -- wildcard in the first segment → search cwd
    end
    return glob:sub(1, boundary - 1), glob:sub(boundary + 1)
end

--- Compile a DiscoverySpec into a STRUCTURED command (PURE — does not run it):
--- `{ search_dirs = {dir…}, name_globs = {relative glob…}, frontmatter, content_term }`.
--- `search_dirs` are rg positional paths (absolute-safe); `name_globs` are RELATIVE
--- `-g` filters (deduped). render_command turns this into the rg string; execution
--- (vim.fn.system) is the consumer's job. Keeping the compiler structured is the
--- ARCH-PURE seam — pure compiler, thin shellescape renderer.
--- @param spec table DiscoverySpec
--- @return table command
function M.spec_to_command(spec)
    local dirs, globs, seen = {}, {}, {}
    for _, root in ipairs(spec.roots) do
        local dir, name = split_glob(root)
        table.insert(dirs, dir)
        if name and not seen[name] then
            seen[name] = true
            table.insert(globs, name)
        end
    end
    return {
        search_dirs = dirs,
        name_globs = globs,
        frontmatter = spec.frontmatter,
        content_term = spec.content_term,
    }
end

--- Render a structured command (from spec_to_command) into an rg pipeline string,
--- `shellescape`ing every interpolated value (so a value with a quote can't
--- break/inject the command). `name_globs` become `-g` filters; `search_dirs`
--- are positional paths; a frontmatter filter lists matching files first, then
--- greps their content. PURE — vim.fn.system runs the result (consumer side).
--- @param cmd table structured command from spec_to_command
--- @return string
function M.render_command(cmd)
    local parts = {}
    for _, g in ipairs(cmd.name_globs) do
        table.insert(parts, "-g " .. vim.fn.shellescape(g))
    end
    for _, d in ipairs(cmd.search_dirs) do
        table.insert(parts, vim.fn.shellescape(d))
    end
    local scope = table.concat(parts, " ")
    local fm = cmd.frontmatter
    local term = cmd.content_term
    if fm then
        local list = "rg -l " .. vim.fn.shellescape("^" .. fm.field .. ": " .. fm.value) .. " " .. scope
        if term then
            return list .. " | xargs -r rg -il " .. vim.fn.shellescape(term)
        end
        return list
    end
    if term then
        return "rg -il " .. vim.fn.shellescape(term) .. " " .. scope
    end
    return "rg --files " .. scope
end

return M
