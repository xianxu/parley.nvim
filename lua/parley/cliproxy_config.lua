--------------------------------------------------------------------------------
-- Pure config core for the managed cliproxyapi instance (issue #131).
--
-- No IO: every function here is deterministic and unit-tested without mocks
-- (ARCH-PURE). The IO shell — binary discovery, spawn, health probe, the
-- :ParleyProxy commands — lives in parley/cliproxy.lua and injects these.
--------------------------------------------------------------------------------

local M = {}

--- Parse host:port out of a provider endpoint URL.
--- The provider endpoint is the single source of truth for host:port
--- (spec §"host:port — single source of truth"); everything downstream
--- derives from it, so there is deliberately no separate `cliproxy.port` knob.
---
--- NB: a port-less endpoint resolves to 80/443 — it will NOT silently fall
--- back to cliproxy's 8317 default. The canonical endpoint carries `:8317`.
---@param endpoint string
---@return string|nil host, number|nil port
function M.parse_endpoint(endpoint)
    if type(endpoint) ~= "string" then
        return nil, nil
    end
    local host, port = endpoint:match("^https?://([^:/]+):(%d+)")
    if host and port then
        return host, tonumber(port)
    end
    local scheme, h = endpoint:match("^(https?)://([^:/]+)")
    if scheme and h then
        return h, scheme == "https" and 443 or 80
    end
    return nil, nil
end

--- Merge the raw `config` passthrough with parley's wiring fields and the
--- resolved client secret. Pure — the secret is passed in already resolved;
--- this never touches the vault (ARCH-PURE). Unknown keys pass through
--- untouched (ARCH-DRY: we do not re-model cliproxy's schema).
---
--- Returns the config table plus a list of any raw-config keys it clobbered,
--- so the IO caller can warn (keeping the *decision* pure and the *act* of
--- warning at the boundary).
---@param opts table # { host, port, auth_dir?, secret?, config? }
---@return table config_table, string[] overrides
function M.render(opts)
    local cfg = vim.deepcopy(opts.config or {})
    local overrides = {}
    if cfg.host ~= nil and cfg.host ~= opts.host then
        table.insert(overrides, "host")
    end
    if cfg.port ~= nil and cfg.port ~= opts.port then
        table.insert(overrides, "port")
    end
    cfg.host = opts.host
    cfg.port = opts.port
    if opts.auth_dir ~= nil then
        cfg["auth-dir"] = opts.auth_dir
    end
    if opts.secret ~= nil and opts.secret ~= "" then
        cfg["api-keys"] = { opts.secret } -- non-empty → encodes as a JSON array
    else
        -- Omit, never {} — vim.json.encode({}) emits `{}` (object), which
        -- cliproxy would read as a malformed api-keys.
        cfg["api-keys"] = nil
    end
    return cfg, overrides
end

--- Emit the config as a string cliproxy's --config can read. JSON is valid
--- YAML 1.2, so we emit JSON and skip a YAML emitter (spec §Emission; the
--- gating task in the plan validates a real cli-proxy-api accepts it).
---@param config_table table
---@return string
function M.encode(config_table)
    return vim.json.encode(config_table)
end

return M
