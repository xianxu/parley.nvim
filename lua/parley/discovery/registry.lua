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

local function glob_flags(roots)
    local parts = {}
    for _, g in ipairs(roots) do
        table.insert(parts, "-g '" .. g .. "'")
    end
    return table.concat(parts, " ")
end

--- Compile a DiscoverySpec to an rg pipeline string (PURE — does not run it).
--- Roots become rg `--glob` filters; a frontmatter filter lists matching files
--- first, then greps their content. Execution is the consumer's (M2) job.
--- @param spec table DiscoverySpec
--- @return string
function M.spec_to_command(spec)
    local globs = glob_flags(spec.roots)
    local fm = spec.frontmatter
    local term = spec.content_term
    if fm then
        local list = "rg -l '^" .. fm.field .. ": " .. fm.value .. "' " .. globs .. " ."
        if term then
            return list .. " | xargs -r rg -il '" .. term .. "'"
        end
        return list
    end
    if term then
        return "rg -il '" .. term .. "' " .. globs .. " ."
    end
    return "rg --files " .. globs .. " ."
end

return M
