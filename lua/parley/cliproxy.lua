--------------------------------------------------------------------------------
-- IO lifecycle shell for the managed cliproxyapi instance (issue #131).
--
-- Thin IO seam (ARCH-PURE): binary discovery, detached spawn, identity-checked
-- health probe, reuse-if-healthy, the :ParleyProxy commands. All pure config
-- transforms live in parley/cliproxy_config.lua and are injected here.
--
-- Reached from the dispatcher via the cliproxyapi adapter's pre_query hook
-- (ARCH-DRY: the same seam copilot uses to prep before a query).
--------------------------------------------------------------------------------

local uv = vim.uv or vim.loop
local cc = require("parley.cliproxy_config")
local logger = require("parley.logger")

local M = {}

-- pid -> uv process handle for proxies PARLEY spawned (so stop() is scoped to
-- our own daemon and never touches a reused/foreign one).
local _spawned = {}

--------------------------------------------------------------------------------
-- Config access
--------------------------------------------------------------------------------

-- The merged user config lives on the `parley` module (init.lua merges
-- top-level setup{} keys into M.config), NOT on this module's M.
local function cfg()
    local ok, parley = pcall(require, "parley")
    if ok and parley and type(parley.config) == "table" then
        return parley.config.cliproxy
    end
    return nil
end

local function endpoint()
    local ok, parley = pcall(require, "parley")
    if ok and parley and parley.dispatcher and parley.dispatcher.providers
        and parley.dispatcher.providers.cliproxyapi then
        return parley.dispatcher.providers.cliproxyapi.endpoint
    end
    return nil
end

--- Is the managed-proxy feature opted into?
---@return boolean
function M.is_managed()
    local c = cfg()
    return c ~= nil and c.manage == true
end

--------------------------------------------------------------------------------
-- Binary discovery
--------------------------------------------------------------------------------

--- Locate the cliproxy binary: explicit binary_path → PATH (brew name
--- `cliproxyapi`, then release-tarball name `cli-proxy-api`). M2 inserts the
--- managed download dir between binary_path and PATH.
---@return string|nil
function M.discover_binary()
    local c = cfg() or {}
    if type(c.binary_path) == "string" and c.binary_path ~= "" then
        if vim.fn.executable(c.binary_path) == 1 then
            return c.binary_path
        end
    end
    for _, name in ipairs({ "cliproxyapi", "cli-proxy-api" }) do
        local p = vim.fn.exepath(name)
        if p ~= nil and p ~= "" then
            return p
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Health probe (identity-checked)
--------------------------------------------------------------------------------

-- Classify a curl result against cliproxy's /v1/models contract (route + body
-- shapes confirmed in issue #131 Task 2.0):
--   down                 connection refused / timeout (no usable response)
--   client_key_mismatch  401 (rendered api-keys != the bearer we sent)
--   healthy              200, {object:"list", data:[non-empty]}
--   needs_login          200, {object:"list", data:[]}  (up, no upstream login)
--   foreign              200 but not the list shape (someone else holds the port)
local function classify(code, stdout)
    if code ~= 0 then
        return "down"
    end
    local out = stdout or ""
    local body, http = out:match("^(.*)\n(%d+)%s*$")
    http = tonumber(http)
    if http == 401 then
        return "client_key_mismatch"
    end
    if http ~= 200 then
        return "foreign"
    end
    local ok, decoded = pcall(vim.json.decode, body or "")
    if ok and type(decoded) == "table" and decoded.object == "list" then
        if type(decoded.data) == "table" and #decoded.data > 0 then
            return "healthy"
        end
        return "needs_login"
    end
    return "foreign"
end

M._classify = classify -- exposed for unit testing

--- Probe http://host:port/v1/models with the client bearer and classify.
--- Async; calls cb(state) on the main loop.
---@param host string
---@param port number
---@param secret string|nil
---@param cb fun(state: string)
function M.health_probe(host, port, secret, cb)
    local url = ("http://%s:%s/v1/models"):format(host, port)
    local args = { "curl", "-s", "-w", "\n%{http_code}", "--max-time", "2" }
    if type(secret) == "string" and secret ~= "" then
        table.insert(args, "-H")
        table.insert(args, "Authorization: Bearer " .. secret)
    end
    table.insert(args, url)
    vim.system(args, { text = true }, function(obj)
        local state = classify(obj.code, obj.stdout)
        vim.schedule(function()
            cb(state)
        end)
    end)
end

--------------------------------------------------------------------------------
-- Rendered config (derived artifact)
--------------------------------------------------------------------------------

-- A derived, machine-local artifact under stdpath('data') — NOT in the user's
-- dotfiles repo. The committed Lua setup{} is the source of truth.
local function config_path()
    local dir = vim.fn.stdpath("data") .. "/parley/cliproxy"
    vim.fn.mkdir(dir, "p")
    return dir .. "/config.yaml"
end

M._config_path = config_path -- exposed for tests

-- Render the merged config from Lua + the resolved secret, write it 0600.
-- Returns (path, host, port) or (nil, err).
local function write_rendered_config()
    local host, port = cc.parse_endpoint(endpoint())
    if not host then
        return nil, "cannot parse host:port from endpoint: " .. tostring(endpoint())
    end
    local c = cfg() or {}
    local secret = require("parley.vault").get_secret(
        require("parley.providers").get_secret_name("cliproxyapi"))
    local rendered, overrides = cc.render({
        host = host,
        port = port,
        auth_dir = c.auth_dir,
        secret = secret,
        config = c.config,
    })
    if #overrides > 0 then
        logger.warning("cliproxy: managed host/port override raw config key(s): "
            .. table.concat(overrides, ", "))
    end
    local path = config_path()
    local f, ferr = io.open(path, "w")
    if not f then
        return nil, "cannot write config: " .. tostring(ferr)
    end
    f:write(cc.encode(rendered))
    f:close()
    local fs_chmod = uv.fs_chmod or vim.loop.fs_chmod
    fs_chmod(path, tonumber("600", 8))
    return path, host, port, secret
end

--------------------------------------------------------------------------------
-- Spawn (detached, PID-tracked)
--------------------------------------------------------------------------------

--- Spawn the proxy detached so it outlives nvim and is shared across instances.
--- Records the pid so stop() is scoped to a parley-spawned daemon only.
---@param binary string
---@param config_file string
---@return number|nil pid, any handle_or_err
function M.spawn(binary, config_file)
    local handle, pid
    handle, pid = uv.spawn(binary, {
        args = { "-config", config_file },
        detached = true,
    }, function(code, _signal)
        local rec = _spawned[pid]
        if rec then
            rec.exited = true
            rec.code = code
        end
    end)
    if not handle then
        return nil, tostring(pid) -- pid carries the error message on failure
    end
    uv.unref(handle)
    _spawned[pid] = { handle = handle, exited = false }
    return pid, handle
end

--- pids of proxies parley spawned (for scoped stop()).
---@return number[]
function M.spawned_pids()
    local pids = {}
    for pid in pairs(_spawned) do
        table.insert(pids, pid)
    end
    return pids
end

--- Test helper: forget all tracked spawns (does not kill them).
function M._reset_spawned()
    _spawned = {}
end

--------------------------------------------------------------------------------
-- ensure_running — reuse-if-healthy, else spawn + poll; never hang
--------------------------------------------------------------------------------

local POLL_INTERVAL_MS = 250
local POLL_BUDGET_MS = 5000

local function poll_until_healthy(host, port, secret, pid, callback, on_error)
    local deadline = uv.now() + POLL_BUDGET_MS
    local function tick()
        local rec = _spawned[pid]
        if rec and rec.exited then
            return on_error("cliproxy: process exited (code " .. tostring(rec.code)
                .. ") right after spawn — check the binary/config")
        end
        M.health_probe(host, port, secret, function(state)
            if state == "healthy" or state == "needs_login" then
                return callback()
            end
            if uv.now() >= deadline then
                return on_error("cliproxy: proxy did not become healthy within "
                    .. (POLL_BUDGET_MS / 1000) .. "s — try :ParleyProxy status")
            end
            vim.defer_fn(tick, POLL_INTERVAL_MS)
        end)
    end
    tick()
end

--- Ensure a healthy managed proxy is reachable, then call `callback`. On any
--- failure call `on_error(msg)` so the dispatch path fails fast (never hangs).
--- No-op pass-through when the feature isn't opted in.
---@param callback fun()
---@param on_error fun(msg: string)|nil
function M.ensure_running(callback, on_error)
    on_error = on_error or function() end
    if not M.is_managed() then
        return callback()
    end

    local path, host, port, secret = write_rendered_config()
    if not path then
        return on_error("cliproxy: " .. tostring(host)) -- host carries the err
    end

    M.health_probe(host, port, secret, function(state)
        if state == "healthy" or state == "needs_login" then
            return callback() -- reuse the already-running (brew service / other nvim)
        end
        if state == "client_key_mismatch" then
            return on_error("cliproxy: client api-key mismatch — the rendered api-keys "
                .. "do not match the bearer parley sends (check api_keys.cliproxyapi)")
        end
        if state == "foreign" then
            return on_error("cliproxy: port " .. port .. " is held by a non-cliproxy process")
        end
        -- down → spawn our own
        local bin = M.discover_binary()
        if not bin then
            return on_error("cliproxy: no cliproxy binary found — `brew install cliproxyapi`, "
                .. "set cliproxy.binary_path, or enable auto_download (M2)")
        end
        local pid, err = M.spawn(bin, path)
        if not pid then
            return on_error("cliproxy: failed to spawn " .. bin .. ": " .. tostring(err))
        end
        poll_until_healthy(host, port, secret, pid, callback, on_error)
    end)
end

--------------------------------------------------------------------------------
-- Commands: status / start / stop / restart / login
--------------------------------------------------------------------------------

M.start = M.ensure_running

--- Stop only proxies parley spawned (a reused/foreign daemon is left alone).
---@return number killed
function M.stop()
    local killed = 0
    for pid in pairs(_spawned) do
        pcall(uv.kill, pid, "sigterm")
        killed = killed + 1
    end
    _spawned = {}
    return killed
end

--- Restart: stop our own daemon, then ensure-running (re-renders config).
function M.restart(callback, on_error)
    M.stop()
    M.ensure_running(callback or function() end, on_error)
end

-- Does the on-disk rendered config differ from a fresh render of the current
-- Lua config? Compares decoded tables (NOT encoded strings — key order is
-- unstable across renders).
local function config_drift()
    local f = io.open(config_path(), "r")
    if not f then
        return false -- nothing rendered yet
    end
    local content = f:read("*a")
    f:close()
    local ok, on_disk = pcall(vim.json.decode, content)
    if not ok then
        return true
    end
    local host, port = cc.parse_endpoint(endpoint())
    if not host then
        return false
    end
    local c = cfg() or {}
    local secret = require("parley.vault").get_secret(
        require("parley.providers").get_secret_name("cliproxyapi"))
    local fresh = cc.render({ host = host, port = port, auth_dir = c.auth_dir, secret = secret, config = c.config })
    return not vim.deep_equal(on_disk, fresh)
end

--- Gather a status snapshot. Async (health is probed); calls cb(info).
---@param cb fun(info: table)
function M.status(cb)
    local bin = M.discover_binary()
    local c = cfg() or {}
    local host, port = cc.parse_endpoint(endpoint())
    local source = "none"
    if bin then
        source = (c.binary_path == bin) and "binary_path" or "PATH"
    end
    local info = {
        managed = M.is_managed(),
        binary = bin,
        binary_source = source,
        host = host,
        port = port,
        auth_dir = c.auth_dir,
        config_path = config_path(),
        spawned_by_parley = #M.spawned_pids() > 0,
        config_drift = config_drift(),
    }
    if not host then
        info.health = "unknown"
        return cb(info)
    end
    local secret = require("parley.vault").get_secret(
        require("parley.providers").get_secret_name("cliproxyapi"))
    M.health_probe(host, port, secret, function(state)
        info.health = state
        cb(info)
    end)
end

-- Per-provider login flags (NOT a `login` subcommand — confirmed Task 2.0).
local LOGIN_FLAGS = {
    claude = "-claude-login",
    codex = "-codex-login",
    ["codex-device"] = "-codex-device-login",
    google = "-login",
    kimi = "-kimi-login",
    xai = "-xai-login",
    antigravity = "-antigravity-login",
}

--- Build the argv for an interactive OAuth login for `provider`.
--- Passes -config so login writes into parley's configured auth-dir.
---@param provider string
---@return string[]|nil argv, string|nil err
function M.login_argv(provider)
    local bin = M.discover_binary()
    if not bin then
        return nil, "no cliproxy binary found — `brew install cliproxyapi` or set cliproxy.binary_path"
    end
    local flag = LOGIN_FLAGS[provider]
    if not flag then
        local valid = vim.tbl_keys(LOGIN_FLAGS)
        table.sort(valid)
        return nil, "unknown login provider '" .. tostring(provider)
            .. "' — valid: " .. table.concat(valid, ", ")
    end
    return { bin, "-config", config_path(), flag }
end

return M
