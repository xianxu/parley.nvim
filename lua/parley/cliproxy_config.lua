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

--------------------------------------------------------------------------------
-- M2: release asset resolution (pure; consumed by cliproxy.download)
--------------------------------------------------------------------------------

--- Map an os_uname() result to cliproxy's release {os, arch} naming, or nil
--- if this platform has no published release. `uname` is injectable for tests.
---@param uname table|nil # defaults to vim.uv.os_uname()
---@return table|nil # { os = "darwin|linux|freebsd|windows", arch = "aarch64|amd64" }
function M.platform(uname)
    uname = uname or (vim.uv or vim.loop).os_uname()
    local os_map = { Darwin = "darwin", Linux = "linux", FreeBSD = "freebsd", Windows_NT = "windows" }
    local os_name = os_map[uname.sysname]
    local arch
    local m = uname.machine
    if m == "arm64" or m == "aarch64" then
        arch = "aarch64"
    elseif m == "x86_64" or m == "amd64" then
        arch = "amd64"
    end
    if not os_name or not arch then
        return nil
    end
    return { os = os_name, arch = arch }
end

--- Release asset filename for a version + platform, e.g.
--- "CLIProxyAPI_7.1.71_darwin_aarch64.tar.gz" (".zip" on Windows).
--- NB: FreeBSD is best-effort — some releases ship freebsd/aarch64 only as a
--- `_no-plugin` variant, so this canonical name may 404 there (download() will
--- surface the curl error). darwin/linux are the supported targets.
---@param version string # e.g. "7.1.71" (no leading v)
---@param plat table # { os, arch } from platform()
---@return string
function M.asset_name(version, plat)
    local ext = plat.os == "windows" and "zip" or "tar.gz"
    return ("CLIProxyAPI_%s_%s_%s.%s"):format(version, plat.os, plat.arch, ext)
end

--- Pull the sha256 for `asset` out of a checksums.txt body
--- ("<sha256>  <filename>" per line). Returns nil if absent.
---@param text string
---@param asset string
---@return string|nil
function M.parse_checksums(text, asset)
    for line in (text or ""):gmatch("[^\n]+") do
        local sha, name = line:match("^(%x+)%s+%*?(%S+)$")
        if name == asset then
            return sha
        end
    end
    return nil
end

return M
