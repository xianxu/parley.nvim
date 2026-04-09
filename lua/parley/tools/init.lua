-- Tool registry for parley's client-side tool-use loop.
--
-- Module-level mutable registry that maps `name → ToolDefinition`.
-- Populated at setup time via `register_builtin_tools()` in
-- `lua/parley/init.lua` (Task 1.3). Validated agents can only select
-- tools that are present in this registry.
--
-- State is intentionally module-level (not global) so multiple Neovim
-- sessions in the same lua_shared state would not see each other's
-- registries. `reset()` is provided for test isolation and for
-- idempotent reinitialization across repeated `parley.setup()` calls.

local types = require("parley.tools.types")

local M = {}

--- @type table<string, ToolDefinition>
local registry = {}

--- Clear all registered tools. Idempotent. Safe to call at the top of
--- `parley.setup()` so repeated setups do not duplicate entries.
function M.reset()
    registry = {}
end

--- Register a ToolDefinition. Validates via `types.validate_definition`;
--- raises on invalid input with the specific validation error.
--- Registering a name that already exists overwrites silently — the
--- caller is responsible for ensuring uniqueness when that matters.
--- @param def ToolDefinition
function M.register(def)
    local ok, err = types.validate_definition(def)
    if not ok then
        error("parley.tools.register: " .. err)
    end
    registry[def.name] = def
end

--- Look up a ToolDefinition by name. Returns nil for unknown names.
--- @param name string
--- @return ToolDefinition|nil
function M.get(name)
    return registry[name]
end

--- List all registered tool names (unsorted).
--- @return string[]
function M.list_names()
    local out = {}
    for name, _ in pairs(registry) do
        table.insert(out, name)
    end
    return out
end

--- Return a list of ToolDefinitions matching the given names, preserving
--- the input order. Raises on the first unknown name with the offending
--- name in the error message so agent-config validation can surface
--- actionable errors to the user.
--- @param names string[]
--- @return ToolDefinition[]
function M.select(names)
    local out = {}
    for _, name in ipairs(names or {}) do
        local def = registry[name]
        if not def then
            error("parley.tools.select: unknown tool '" .. tostring(name) .. "'")
        end
        table.insert(out, def)
    end
    return out
end

return M
