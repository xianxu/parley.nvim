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

local function glob_flags(roots)
    local parts = {}
    for _, g in ipairs(roots) do
        table.insert(parts, "-g " .. vim.fn.shellescape(g))
    end
    return table.concat(parts, " ")
end

--- Compile a DiscoverySpec to an rg pipeline string (PURE — does not run it).
--- Roots become rg `--glob` filters; a frontmatter filter lists matching files
--- first, then greps their content. Execution is the consumer's (M2) job.
--- All interpolated values (globs, frontmatter pattern, content term) are
--- `shellescape`d so a value containing a quote can't break/inject the command.
--- @param spec table DiscoverySpec
--- @return string
function M.spec_to_command(spec)
    local globs = glob_flags(spec.roots)
    local fm = spec.frontmatter
    local term = spec.content_term
    if fm then
        local list = "rg -l " .. vim.fn.shellescape("^" .. fm.field .. ": " .. fm.value) .. " " .. globs .. " ."
        if term then
            return list .. " | xargs -r rg -il " .. vim.fn.shellescape(term)
        end
        return list
    end
    if term then
        return "rg -il " .. vim.fn.shellescape(term) .. " " .. globs .. " ."
    end
    return "rg --files " .. globs .. " ."
end

return M
