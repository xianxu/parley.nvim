-- parley.discovery.descriptor — TypeDescriptor shape + validation.
--
-- A TypeDescriptor is everything deterministic code needs about one type:
--   { name, label, scope, locate, matcher, blurb }
--     name    registry key (non-empty string)
--     label   display name (non-empty string)
--     scope   "base" | "local" — parley-shipped vs grep-discovered
--     locate  non-empty list of path globs (carry extension, e.g. *.md/*.yaml)
--     matcher a Matcher (see matcher.lua); its kind must be in matcher.KINDS
--     blurb   one line for render() — "what it is + how to find it"
--
-- PURE: validation returns (true) or (false, err_msg), mirroring
-- tools/types.lua so callers surface actionable errors at assembly time.

local matcher = require("parley.discovery.matcher")

local M = {}

local function fail(msg)
    return false, msg
end

--- Validate a TypeDescriptor.
--- @param desc any
--- @return boolean ok
--- @return string|nil err
function M.validate(desc)
    if type(desc) ~= "table" then
        return fail("descriptor must be a table")
    end
    if type(desc.name) ~= "string" or desc.name == "" then
        return fail("descriptor.name must be a non-empty string")
    end
    if type(desc.label) ~= "string" or desc.label == "" then
        return fail("descriptor.label must be a non-empty string")
    end
    if desc.scope ~= "base" and desc.scope ~= "local" then
        return fail("descriptor.scope must be 'base' or 'local'")
    end
    if type(desc.locate) ~= "table" or #desc.locate == 0 then
        return fail("descriptor.locate must be a non-empty list of globs")
    end
    for _, glob in ipairs(desc.locate) do
        if type(glob) ~= "string" or glob == "" then
            return fail("descriptor.locate entries must be non-empty strings")
        end
    end
    if type(desc.matcher) ~= "table" then
        return fail("descriptor.matcher must be a table")
    end
    if not matcher.KINDS[desc.matcher.kind] then
        return fail("descriptor.matcher.kind '" .. tostring(desc.matcher.kind) .. "' is not a known matcher kind")
    end
    if type(desc.blurb) ~= "string" or desc.blurb == "" then
        return fail("descriptor.blurb must be a non-empty string")
    end
    return true
end

return M
