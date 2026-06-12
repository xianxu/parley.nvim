-- parley.discovery.local_types — grep-backed discovery of a repo's NOVEL types.
--
-- The cheap *production* behind the registry interface: discover the `type:`
-- frontmatter values present in a repo, subtract the parley-shipped base, and
-- synthesize a minimal `local` TypeDescriptor for each survivor. This is the
-- "repo declares only its delta" half — the effective registry is base ∪ local.
--
-- rg is invoked following grep.lua's pattern (load-time detection +
-- vim.fn.system, NOT vim.system) — see lua/parley/tools/builtin/grep.lua. The
-- swap point for a future datatype-binary-maintained index is this module: same
-- output shape (a list of descriptors), a different producer.

local M = {}

-- Detect rg once at load (grep.lua idiom). Discovery needs rg's `-o` match
-- extraction; if rg is absent we degrade to "no local types" (base still works).
local has_rg = vim.fn.executable("rg") == 1

-- Hyphen-safe: datatype `type:` values are hyphenated (meeting-notes,
-- travel-plan), so the class must include '-' — `\w+` would truncate them.
local TYPE_PATTERN = "^type: [A-Za-z0-9_-]+"

--- Synthesize a minimal `local` descriptor for a novel type value.
--- @param value string the `type:` value
--- @return table descriptor
function M.synthesize(value)
    return {
        name = value,
        label = value,
        scope = "local",
        locate = { "**/*.md" },
        matcher = { kind = "frontmatter", field = "type", value = value },
        blurb = "a repo-local `" .. value .. "` document",
    }
end

--- Discover novel `type:` values under `root`, minus `base_names`.
--- @param root string directory to scan
--- @param base_names table list of base type names to subtract
--- @return table list of synthesized `local` TypeDescriptors (unique, by name)
function M.discover(root, base_names)
    if not has_rg or type(root) ~= "string" or root == "" then
        return {}
    end

    local base_set = {}
    for _, n in ipairs(base_names or {}) do
        base_set[n] = true
    end

    local cmd = "rg -o --no-filename " .. vim.fn.shellescape(TYPE_PATTERN) .. " " .. vim.fn.shellescape(root)
    local out = vim.fn.system(cmd)
    -- rg: 0 = matches, 1 = no matches (fine), >=2 = error. On error, degrade.
    if vim.v.shell_error >= 2 then
        return {}
    end

    local seen = {}
    local result = {}
    for line in (out or ""):gmatch("[^\n]+") do
        local value = line:match("^type:%s+([A-Za-z0-9_-]+)")
        if value and not base_set[value] and not seen[value] then
            seen[value] = true
            table.insert(result, M.synthesize(value))
        end
    end
    return result
end

return M
