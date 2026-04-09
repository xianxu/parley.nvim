-- Provider-agnostic internal types for the tool-use loop.
--
-- These three types are the single canonical shape that flows through
-- the tool loop regardless of which LLM provider is in use. Each
-- provider adapter is responsible for translating its native wire
-- format to/from these types; the loop driver and tool dispatcher only
-- ever see these shapes.
--
-- PURE: no I/O, no state, no hidden dependencies. Validators return
-- (true) on success or (false, err_msg) on failure so callers can
-- surface actionable errors at registration / decode time.

--- @class ToolDefinition
--- @field name string Non-empty tool name used by the LLM and the registry.
--- @field description string Non-empty human-readable description shown to the LLM.
--- @field input_schema table JSON-schema-shaped table describing the tool's arguments.
--- @field handler fun(input: table): ToolResult Pure function from input to result.
--- @field kind string|nil "read" or "write" — defaults to "read" when absent.
--- @field needs_backup boolean|nil True if the tool destroys information
---        on disk and the dispatcher must capture a `.parley-backup`
---        pre-image before execution. Defaults to false when absent.

--- @class ToolCall
--- @field id string Correlation id assigned by the LLM (e.g. "toolu_01ABC").
--- @field name string Tool name, must match a registered ToolDefinition.
--- @field input table Decoded input arguments. May be an empty table.

--- @class ToolResult
--- @field id string Correlation id matching the originating ToolCall.id.
--- @field content string Tool output body (may be empty).
--- @field is_error boolean|nil True if the tool reported an error. Defaults to false.
--- @field name string|nil Optional tool name for convenience; the dispatcher
---        stamps this alongside id so serialization can render it without
---        looking up the originating call.

local M = {}

local function fail(msg)
    return false, msg
end

--- Validate a ToolDefinition.
--- @param def any
--- @return boolean ok
--- @return string|nil err
function M.validate_definition(def)
    if type(def) ~= "table" then
        return fail("definition must be a table")
    end
    if type(def.name) ~= "string" or def.name == "" then
        return fail("definition.name must be a non-empty string")
    end
    if type(def.description) ~= "string" or def.description == "" then
        return fail("definition.description must be a non-empty string")
    end
    if type(def.input_schema) ~= "table" then
        return fail("definition.input_schema must be a table")
    end
    if type(def.handler) ~= "function" then
        return fail("definition.handler must be a function")
    end
    -- Optional kind / needs_backup fields are loosely validated when present;
    -- absent is fine (dispatcher defaults kind = "read", needs_backup = false).
    if def.kind ~= nil and def.kind ~= "read" and def.kind ~= "write" then
        return fail("definition.kind must be 'read' or 'write' when present")
    end
    if def.needs_backup ~= nil and type(def.needs_backup) ~= "boolean" then
        return fail("definition.needs_backup must be boolean when present")
    end
    return true
end

--- Validate a ToolCall.
--- @param call any
--- @return boolean ok
--- @return string|nil err
function M.validate_call(call)
    if type(call) ~= "table" then
        return fail("call must be a table")
    end
    if type(call.id) ~= "string" or call.id == "" then
        return fail("call.id must be a non-empty string")
    end
    if type(call.name) ~= "string" or call.name == "" then
        return fail("call.name must be a non-empty string")
    end
    if type(call.input) ~= "table" then
        return fail("call.input must be a table")
    end
    return true
end

--- Validate a ToolResult.
--- @param res any
--- @return boolean ok
--- @return string|nil err
function M.validate_result(res)
    if type(res) ~= "table" then
        return fail("result must be a table")
    end
    if type(res.id) ~= "string" or res.id == "" then
        return fail("result.id must be a non-empty string")
    end
    if type(res.content) ~= "string" then
        return fail("result.content must be a string")
    end
    if res.is_error ~= nil and type(res.is_error) ~= "boolean" then
        return fail("result.is_error must be boolean or nil")
    end
    return true
end

return M
