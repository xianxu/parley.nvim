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
-- #139: inject the horizontal output-pager params (offset/limit) into a tool's
-- input_schema so the agent can page ANY tool's output the same way read_file
-- pages a file. Skipped for write tools and for self-paginating tools (read_file,
-- which declares its own). Idempotent — won't clobber an existing param.
local function inject_pager_params(def)
    if not types.is_pageable(def) then
        return
    end
    local schema = def.input_schema
    if type(schema) ~= "table" then
        return
    end
    schema.properties = schema.properties or {}
    if schema.properties.offset == nil then
        schema.properties.offset = {
            type = "integer",
            description = "Output pager: 1-indexed line to start the returned window at (default 1).",
        }
    end
    if schema.properties.limit == nil then
        schema.properties.limit = {
            type = "integer",
            description = "Output pager: max lines to return (default 200, max 2000). "
                .. "Re-call with a higher offset to page through, or narrow your query.",
        }
    end
end

function M.register(def)
    local ok, err = types.validate_definition(def)
    if not ok then
        error("parley.tools.register: " .. err)
    end
    inject_pager_params(def)
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

--- Expand a group sentinel (a selector beginning with "@") into the set
--- of registered tools it names. Supported groups:
---   "@all"      → every registered tool.
---   "@readonly" → every registered tool that is NOT a write tool, i.e.
---                 kind == "read" or kind absent (absent defaults to
---                 "read" per the ToolDefinition contract).
--- Expansion is alphabetical by tool name so the resulting payload order
--- is deterministic across sessions. Raises on an unknown group, mirroring
--- the unknown-tool error so a typo'd sentinel surfaces at config
--- validation just like a typo'd name.
--- @param group string
--- @return ToolDefinition[]
local function expand_group(group)
    local keep
    if group == "@all" then
        keep = function() return true end
    elseif group == "@readonly" then
        keep = function(def) return def.kind ~= "write" end
    else
        error("parley.tools.select: unknown tool group '" .. tostring(group) .. "'")
    end
    local names = {}
    for name in pairs(registry) do
        names[#names + 1] = name
    end
    table.sort(names)
    local out = {}
    for _, name in ipairs(names) do
        if keep(registry[name]) then
            out[#out + 1] = registry[name]
        end
    end
    return out
end

--- Return a list of ToolDefinitions for the given selectors, preserving
--- input order. A selector is either a tool name or a group sentinel
--- ("@all" / "@readonly", see `expand_group`). Group selectors expand in
--- place; the combined result is de-duplicated by tool name with the
--- first occurrence winning, so mixing a group with explicit names — or
--- two overlapping groups — never emits a tool twice (providers reject a
--- duplicated tool name). Raises on the first unknown name or group so
--- agent-config validation can surface an actionable error to the user.
--- @param names string[]
--- @return ToolDefinition[]
function M.select(names)
    local out = {}
    local seen = {}
    local function add(def)
        if not seen[def.name] then
            seen[def.name] = true
            out[#out + 1] = def
        end
    end
    for _, name in ipairs(names or {}) do
        if type(name) == "string" and name:sub(1, 1) == "@" then
            for _, def in ipairs(expand_group(name)) do
                add(def)
            end
        else
            local def = registry[name]
            if not def then
                error("parley.tools.select: unknown tool '" .. tostring(name) .. "'")
            end
            add(def)
        end
    end
    return out
end

--- Canonical list of builtin tool names. Single source of truth for
--- which tools ship with parley. Adding a new builtin requires editing
--- this list AND creating the corresponding file under builtin/.
M.BUILTIN_NAMES = {
    "read_file",
    "ls",
    "find",
    "grep",
    "chat_history_search",
    "edit_file",
    "write_file",
    "propose_edits",
    "emit_definition",
}

--- Optional tools that are only registered if the underlying command
--- is available on the system.
M.OPTIONAL_NAMES = {
    "ack",
}

--- Register all builtin tools + any optional tools whose commands are
--- available. Called from `parley.setup()`. Calls `reset()` first so
--- repeated `setup()` invocations do not accumulate stale definitions.
function M.register_builtins()
    M.reset()
    for _, name in ipairs(M.BUILTIN_NAMES) do
        M.register(require("parley.tools.builtin." .. name))
    end
    for _, name in ipairs(M.OPTIONAL_NAMES) do
        local def = require("parley.tools.builtin." .. name)
        if def.available ~= false then
            M.register(def)
        end
    end
end

return M
