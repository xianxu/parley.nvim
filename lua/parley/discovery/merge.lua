-- parley.discovery.merge — the PURE heart of base ∪ local composition.
--
-- These two functions carry the merge's whole logic and have no IO, so they are
-- unit-tested directly (no rg, no temp fixtures). The RegistryBuilder
-- (discovery/init.lua) is just the thin glue that feeds them base.build(config)
-- + local_types.discover(root) results.

local M = {}

--- Expand a descriptor's locate globs across the given repo roots.
--- Repo-relative globs (no leading "/") get prefixed with each root; absolute
--- globs pass through once. With no roots (global mode) the globs are returned
--- unchanged. Order: per source glob, all roots in order; duplicates dropped.
--- @param locate table list of path globs
--- @param roots table list of repo-root paths (may be empty)
--- @return table expanded glob list
function M.expand_locate(locate, roots)
    if #roots == 0 then
        return vim.deepcopy(locate)
    end
    local out, seen = {}, {}
    local function push(g)
        if not seen[g] then
            seen[g] = true
            table.insert(out, g)
        end
    end
    for _, glob in ipairs(locate) do
        if glob:sub(1, 1) == "/" then
            push(glob)
        else
            for _, root in ipairs(roots) do
                push(root .. "/" .. glob)
            end
        end
    end
    return out
end

--- Compose descriptor lists into one ordered, name-unique list — FIRST wins.
--- Callers pass base first so base wins ties; since local_types.discover already
--- subtracts base names, a collision can only arise across members (same novel
--- type in two repos) → it appears once.
--- @param lists table list of descriptor-lists (base first, then per-root local)
--- @return table ordered unique-by-name descriptor list
function M.dedupe_compose(lists)
    local by_name, order = {}, {}
    for _, list in ipairs(lists) do
        for _, d in ipairs(list) do
            if not by_name[d.name] then
                by_name[d.name] = d
                table.insert(order, d)
            end
        end
    end
    return order
end

return M
