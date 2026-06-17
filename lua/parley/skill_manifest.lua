-- parley.skill_manifest — the declarative SkillManifest shape + validation.
--
-- A skill is data, not a pipeline: one manifest shape that every provider
-- (disk / user / repo / virtual) emits, and that the per-turn assembly +
-- read_skill tool consume without branching on origin.
--
--   { name, description, scope, activation, source, tools?, elevated?,
--     force_tool?, args?, agent? }
--     name        registry key (non-empty string)
--     description menu entry shown to the model (non-empty string)
--     scope       global | repo | super_repo
--     activation  table of independent boolean flags (always | auto | manual);
--                 non-empty — a skill no one can activate is a config bug
--     source      function(ctx) → string  (the body; unified disk/virtual)
--     tools       list of tool names granted whenever active        (#129)
--     elevated    list of tool names granted only on MANUAL invoke   (#129)
--     force_tool  optional tool name to compel this turn
--     args        optional completable-arg specs (the kept v1 picker)
--     agent       optional model override
--
-- PURE: validation returns (true) or (false, err_msg), mirroring
-- tools/types.lua so callers surface actionable errors at discovery time.

local M = {}

--- Valid `scope` values.
M.SCOPES = { global = true, repo = true, super_repo = true }

--- Valid `activation` flag keys.
M.ACTIVATION_FLAGS = { always = true, auto = true, manual = true }

local function fail(msg)
    return false, msg
end

local function is_string_list(v)
    if type(v) ~= "table" then
        return false
    end
    for _, item in ipairs(v) do
        if type(item) ~= "string" then
            return false
        end
    end
    return true
end

--- Validate a SkillManifest.
--- @param m any
--- @return boolean ok
--- @return string|nil err
function M.validate(m)
    if type(m) ~= "table" then
        return fail("manifest must be a table")
    end
    if type(m.name) ~= "string" or m.name == "" then
        return fail("manifest.name must be a non-empty string")
    end
    if type(m.description) ~= "string" or m.description == "" then
        return fail("manifest.description must be a non-empty string")
    end
    if not M.SCOPES[m.scope] then
        return fail("manifest.scope must be one of global|repo|super_repo")
    end
    if type(m.activation) ~= "table" then
        return fail("manifest.activation must be a table of boolean flags")
    end
    if next(m.activation) == nil then
        return fail("manifest.activation must set at least one flag (always|auto|manual)")
    end
    for flag, val in pairs(m.activation) do
        if not M.ACTIVATION_FLAGS[flag] then
            return fail("manifest.activation has unknown flag '" .. tostring(flag) .. "'")
        end
        if type(val) ~= "boolean" then
            return fail("manifest.activation." .. flag .. " must be a boolean")
        end
    end
    if type(m.source) ~= "function" then
        return fail("manifest.source must be a function(ctx) → string")
    end
    if m.tools ~= nil and not is_string_list(m.tools) then
        return fail("manifest.tools must be a list of tool-name strings")
    end
    if m.elevated ~= nil and not is_string_list(m.elevated) then
        return fail("manifest.elevated must be a list of tool-name strings")
    end
    if m.force_tool ~= nil and type(m.force_tool) ~= "string" then
        return fail("manifest.force_tool must be a tool-name string when present")
    end
    if m.args ~= nil and type(m.args) ~= "table" then
        return fail("manifest.args must be a list when present")
    end
    if m.agent ~= nil and type(m.agent) ~= "string" then
        return fail("manifest.agent must be an agent-name string when present")
    end
    return true
end

return M
