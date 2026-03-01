--------------------------------------------------------------------------------
-- Provider parameter schemas and validation.
--
-- Defines what parameters each provider+model supports, their defaults,
-- valid ranges, API-side names, and mutual-exclusion constraints.
--
-- Key concepts:
--   * nil default  → param is NOT sent unless the user explicitly sets it
--   * non-nil default → param is sent with this value when the user omits it
--   * exclusive_group → a set of params where at_most_one / require_one apply
--------------------------------------------------------------------------------

local M = {}

--------------------------------------------------------------------------------
-- Schema definitions
--------------------------------------------------------------------------------

-- Param spec keys:
--   range    = {min, max}   -- clamp value to this range
--   default  = value|nil    -- nil means "don't send if user didn't set"
--   api_name = "name"       -- key name in the API payload (defaults to param name)

local provider_schemas = {
    openai = {
        params = {
            temperature = { range = { 0, 2 } },
            top_p       = { range = { 0, 1 } },
            max_tokens  = { default = 4096 },
        },
    },
    anthropic = {
        params = {
            temperature = { range = { 0, 2 } },
            top_p       = { range = { 0, 1 } },
            max_tokens  = { default = 4096 },
        },
    },
    googleai = {
        params = {
            temperature = { range = { 0, 2 }, api_name = "temperature" },
            top_p       = { range = { 0, 1 }, api_name = "topP" },
            top_k       = { api_name = "topK", default = 100 },
            max_tokens  = { api_name = "maxOutputTokens", default = 8192 },
        },
    },
    ollama = {
        params = {
            temperature = { range = { 0, 2 } },
            top_p       = { range = { 0, 1 } },
            min_p       = {},
            max_tokens  = { default = 4096 },
        },
    },
    copilot = {
        params = {
            temperature = { range = { 0, 2 } },
            top_p       = { range = { 0, 1 } },
            max_tokens  = { default = 4096 },
        },
    },
}

-- Model-specific overrides, applied on top of the provider base schema.
-- Each entry: { pattern = <lua pattern>, override = { ... } }
--
-- override fields:
--   unsupported      = { "param", ... }   -- remove these params from the schema
--   params           = { name = spec }    -- add or replace param specs
--   exclusive_groups = { group, ... }     -- add exclusive-group constraints
--
-- Entries are checked in order; ALL matching entries are applied (not just first).
local model_overrides = {
    -- o1/o3 reasoning models: no temperature/top_p/max_tokens
    {
        pattern = "^o[13]",
        override = {
            unsupported = { "temperature", "top_p", "max_tokens" },
            params = {
                reasoning_effort = { default = "minimal" },
            },
        },
    },
    -- gpt-4o-search-preview: no temperature/top_p/max_tokens (reasoning-like)
    {
        pattern = "^gpt%-4o%-search%-preview$",
        override = {
            unsupported = { "temperature", "top_p", "max_tokens" },
        },
    },
    -- gpt-5: uses max_completion_tokens, has reasoning_effort, no temperature/top_p
    {
        pattern = "^gpt%-5",
        override = {
            unsupported = { "temperature", "top_p" },
            params = {
                max_tokens       = { api_name = "max_completion_tokens", default = 4096 },
                reasoning_effort = { default = "minimal" },
            },
        },
    },
    -- Claude Sonnet 4.6+: temperature and top_p are mutually exclusive.
    -- Adjust the pattern once the real model ID is known.
    {
        pattern = "^claude%-sonnet%-4%-6",
        override = {
            exclusive_groups = {
                { params = { "temperature", "top_p" }, at_most_one = true },
            },
        },
    },
}

-- Keys in the model config table that are NOT API parameters.
local meta_keys = { model = true }

--------------------------------------------------------------------------------
-- get_schema(provider, model_name) → merged schema table
--------------------------------------------------------------------------------
M.get_schema = function(provider, model_name)
    local base = vim.deepcopy(provider_schemas[provider] or { params = {} })
    base.exclusive_groups = base.exclusive_groups or {}

    for _, entry in ipairs(model_overrides) do
        if model_name and model_name:find(entry.pattern) then
            local ov = entry.override
            if ov.unsupported then
                for _, name in ipairs(ov.unsupported) do
                    base.params[name] = nil
                end
            end
            if ov.params then
                for name, spec in pairs(ov.params) do
                    base.params[name] = spec
                end
            end
            if ov.exclusive_groups then
                for _, group in ipairs(ov.exclusive_groups) do
                    table.insert(base.exclusive_groups, group)
                end
            end
        end
    end

    return base
end

--------------------------------------------------------------------------------
-- resolve_params(provider, model_config) → params table (api_name → value)
--
-- Produces only the parameters that should appear in the API payload.
-- * Skips params the user didn't set AND that have nil default.
-- * Clamps numeric values to declared ranges.
-- * Uses api_name as the key (falls back to param name).
--------------------------------------------------------------------------------
M.resolve_params = function(provider, model_config)
    if type(model_config) ~= "table" then
        return {}
    end

    local model_name = model_config.model or ""
    local schema = M.get_schema(provider, model_name)
    local result = {}

    for param_name, spec in pairs(schema.params) do
        local value = model_config[param_name] -- nil if user didn't set

        -- Apply default when user didn't set
        if value == nil and spec.default ~= nil then
            value = spec.default
        end

        -- Clamp to range
        if value ~= nil and type(value) == "number" and spec.range then
            value = math.max(spec.range[1], math.min(spec.range[2], value))
        end

        -- Only include if we ended up with a value
        if value ~= nil then
            local api_name = spec.api_name or param_name
            result[api_name] = value
        end
    end

    return result
end

--------------------------------------------------------------------------------
-- validate_agent(agent) → { errors = {string,...}, warnings = {string,...} }
--
-- Checks:
--   1. Unknown params (user set a param not in the provider+model schema)
--   2. Exclusive-group violations (at_most_one / require_one)
--   3. Range violations (value outside declared range, before clamping)
--------------------------------------------------------------------------------
M.validate_agent = function(agent)
    local errors = {}
    local warnings = {}

    local provider = agent.provider
    if not provider then
        table.insert(errors, "agent is missing 'provider' field")
        return { errors = errors, warnings = warnings }
    end

    local model_config = agent.model
    if type(model_config) == "string" then
        -- String model has no params to validate
        return { errors = errors, warnings = warnings }
    end
    if type(model_config) ~= "table" then
        table.insert(errors, "agent model must be a string or table")
        return { errors = errors, warnings = warnings }
    end

    local model_name = model_config.model or ""
    local schema = M.get_schema(provider, model_name)

    -- 1. Check for unknown params
    for key, _ in pairs(model_config) do
        if not meta_keys[key] and not schema.params[key] then
            table.insert(warnings,
                string.format("unknown parameter '%s' for provider '%s' model '%s'",
                    key, provider, model_name))
        end
    end

    -- 2. Check exclusive groups
    for _, group in ipairs(schema.exclusive_groups) do
        local set_params = {}
        for _, pname in ipairs(group.params) do
            if model_config[pname] ~= nil then
                table.insert(set_params, pname)
            end
        end

        if group.at_most_one and #set_params > 1 then
            table.insert(errors,
                string.format("at most one of {%s} can be set for model '%s', but found: %s",
                    table.concat(group.params, ", "), model_name,
                    table.concat(set_params, ", ")))
        end

        if group.require_one and #set_params == 0 then
            table.insert(errors,
                string.format("at least one of {%s} must be set for model '%s'",
                    table.concat(group.params, ", "), model_name))
        end
    end

    -- 3. Check range violations
    for param_name, spec in pairs(schema.params) do
        local value = model_config[param_name]
        if value ~= nil and type(value) == "number" and spec.range then
            if value < spec.range[1] or value > spec.range[2] then
                table.insert(warnings,
                    string.format("parameter '%s' value %s is outside range [%s, %s] (will be clamped)",
                        param_name, tostring(value),
                        tostring(spec.range[1]), tostring(spec.range[2])))
            end
        end
    end

    return { errors = errors, warnings = warnings }
end

return M
