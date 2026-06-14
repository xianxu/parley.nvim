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
    local managed = M.managed_binary() -- M2 auto-downloaded binary
    if managed then
        return managed
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

-- Root for derived artifacts (rendered config + auto-downloaded binary), under
-- stdpath('data') — NOT in the user's dotfiles repo. The committed Lua setup{}
-- is the source of truth. Tests override this so a bare PlenaryBustedFile run
-- (no XDG_DATA_HOME redirect) can NEVER write to the operator's real dir.
local _data_dir_override = nil

local function data_root()
    return _data_dir_override or (vim.fn.stdpath("data") .. "/parley/cliproxy")
end

--- Test seam: redirect the derived-artifact root (config + bin) to `path`.
--- Pass nil to restore the real stdpath location.
---@param path string|nil
function M._set_data_dir(path)
    _data_dir_override = path
end

local function config_path()
    local dir = data_root()
    vim.fn.mkdir(dir, "p")
    return dir .. "/config.yaml"
end

M._config_path = config_path -- exposed for tests

-- Single place that gathers the render inputs (host:port from the provider
-- endpoint, auth_dir, vault-resolved client secret, raw config passthrough).
-- Consumed by write_rendered_config, config_drift, and status (ARCH-DRY) — add
-- a render field here and all three pick it up.
local function render_opts()
    local host, port = cc.parse_endpoint(endpoint())
    local c = cfg() or {}
    local secret = require("parley.vault").get_secret(
        require("parley.providers").get_secret_name("cliproxyapi"))
    return { host = host, port = port, auth_dir = c.auth_dir, secret = secret, config = c.config }
end

-- Render the merged config from Lua + the resolved secret, write it 0600.
-- Returns (path, host, port, secret) or (nil, err).
local function write_rendered_config()
    local opts = render_opts()
    if not opts.host then
        return nil, "cannot parse host:port from endpoint: " .. tostring(endpoint())
    end
    local rendered, overrides = cc.render(opts)
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
    return path, opts.host, opts.port, opts.secret
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
        if not bin and (cfg() or {}).auto_download then
            vim.notify("cliproxy: downloading binary (one-time)…", vim.log.levels.INFO)
            local dlbin, derr = M.download()
            if not dlbin then
                return on_error("cliproxy: auto_download failed — " .. tostring(derr))
            end
            bin = dlbin
        end
        if not bin then
            return on_error("cliproxy: no cliproxy binary found — `brew install cliproxyapi`, "
                .. "set cliproxy.binary_path, or enable auto_download")
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

-- PIDs listening on `port` (best-effort via lsof; empty if lsof is absent).
local function pids_on_port(port)
    if vim.fn.executable("lsof") ~= 1 then
        return {}
    end
    local res = vim.system({ "lsof", "-nP", "-iTCP:" .. port, "-sTCP:LISTEN", "-t" }, { text = true }):wait()
    local pids = {}
    for s in (res.stdout or ""):gmatch("%d+") do
        pids[#pids + 1] = tonumber(s)
    end
    return pids
end

-- Synchronously decide whether host:port is held by a cliproxy — same
-- /v1/models identity as health_probe (reusing classify) — so stop() never
-- reaps a foreign process that merely happens to hold the port. A 401
-- (client_key_mismatch) still means a cliproxy is there, so it counts.
local function port_holds_cliproxy(host, port, secret)
    local args = { "curl", "-s", "-w", "\n%{http_code}", "--max-time", "2" }
    if type(secret) == "string" and secret ~= "" then
        table.insert(args, "-H")
        table.insert(args, "Authorization: Bearer " .. secret)
    end
    table.insert(args, ("http://%s:%s/v1/models"):format(host, port))
    local res = vim.system(args, { text = true }):wait()
    local state = classify(res.code, res.stdout)
    return state == "healthy" or state == "needs_login" or state == "client_key_mismatch"
end

--- Stop the managed proxy. Kills proxies this session spawned AND reaps a
--- leftover cliproxy on the managed port from ANY session (the detached-proxy
--- rough edge: a proxy spawned in an earlier nvim that `_spawned` can't reach).
--- It identity-probes the port first, so a **foreign** process holding the port
--- is left untouched.
---@return number killed
function M.stop()
    local killed = {}
    for pid in pairs(_spawned) do
        pcall(uv.kill, pid, "sigterm")
        killed[pid] = true
    end
    _spawned = {}
    local opts = render_opts()
    if opts.host and opts.port and port_holds_cliproxy(opts.host, opts.port, opts.secret) then
        for _, pid in ipairs(pids_on_port(opts.port)) do
            if not killed[pid] then
                pcall(uv.kill, pid, "sigterm")
                killed[pid] = true
            end
        end
    end
    return vim.tbl_count(killed)
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
    local opts = render_opts()
    if not opts.host then
        return false
    end
    return not vim.deep_equal(on_disk, cc.render(opts))
end

--- Gather a status snapshot. Async (health is probed); calls cb(info).
---@param cb fun(info: table)
function M.status(cb)
    local bin = M.discover_binary()
    local c = cfg() or {}
    local opts = render_opts()
    local source = "none"
    if bin then
        source = (c.binary_path == bin) and "binary_path" or "PATH"
    end
    local info = {
        managed = M.is_managed(),
        binary = bin,
        binary_source = source,
        host = opts.host,
        port = opts.port,
        auth_dir = c.auth_dir,
        config_path = config_path(),
        spawned_by_parley = #M.spawned_pids() > 0,
        config_drift = config_drift(),
    }
    if not opts.host then
        info.health = "unknown"
        return cb(info)
    end
    M.health_probe(opts.host, opts.port, opts.secret, function(state)
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

--- The valid login providers (single source — keys of LOGIN_FLAGS), sorted.
--- The :ParleyProxy completer uses this so it can't drift from login_argv.
---@return string[]
function M.login_providers()
    local list = vim.tbl_keys(LOGIN_FLAGS)
    table.sort(list)
    return list
end

--- Build the argv for an interactive OAuth login for `provider`.
--- Renders the config first so login writes into parley's configured auth-dir
--- (not the cliproxy default), then passes -config.
---@param provider string
---@return string[]|nil argv, string|nil err
function M.login_argv(provider)
    local bin = M.discover_binary()
    if not bin then
        return nil, "no cliproxy binary found — `brew install cliproxyapi` or set cliproxy.binary_path"
    end
    local flag = LOGIN_FLAGS[provider]
    if not flag then
        return nil, "unknown login provider '" .. tostring(provider)
            .. "' — valid: " .. table.concat(M.login_providers(), ", ")
    end
    -- Ensure the rendered config exists so a custom auth_dir is honored even
    -- before any dispatch has run (best-effort; ignore render errors here).
    pcall(write_rendered_config)
    return { bin, "-config", config_path(), flag }
end

--------------------------------------------------------------------------------
-- M3: auth-failure → guided login
--------------------------------------------------------------------------------

local _login_prompt_active = false

function M._reset_login_prompt() -- test helper
    _login_prompt_active = false
end

--- On a cliproxy response, detect a missing/invalid upstream credential and
--- prompt-and-confirm the right `:ParleyProxy login`. The provider is resolved
--- from parley's own `oauth-model-alias` (the channel the model sits under), not
--- from the model name. No-op for non-cliproxy providers + normal responses.
---@param provider string
---@param raw_response string
function M.check_auth_failure(provider, raw_response)
    local ok, providers = pcall(require, "parley.providers")
    if not ok or providers.resolve_name(provider) ~= "cliproxyapi" then
        return
    end
    local failed_model = cc.detect_auth_failure(raw_response)
    if not failed_model or _login_prompt_active then
        return
    end
    local c = cfg() or {}
    local alias = type(c.config) == "table" and c.config["oauth-model-alias"] or nil
    local login = alias and cc.resolve_login_provider(failed_model, alias) or nil
    _login_prompt_active = true
    vim.schedule(function()
        if not login then
            _login_prompt_active = false
            vim.notify(("cliproxy: \"%s\" — unknown provider / missing auth. Add it to "
                .. "cliproxy.config['oauth-model-alias'], or :ParleyProxy login <provider>.")
                :format(failed_model), vim.log.levels.WARN)
            return
        end
        local prefix = (require("parley").config or {}).cmd_prefix or "Parley"
        vim.ui.select({ "Log in (" .. login .. ")", "Not now" }, {
            prompt = ("cliproxy: \"%s\" needs the %s login."):format(failed_model, login),
        }, function(_, idx)
            _login_prompt_active = false
            if idx == 1 then
                vim.cmd(prefix .. "Proxy login " .. login)
            end
        end)
    end)
end

--------------------------------------------------------------------------------
-- M2: auto_download — fetch a pinned release, checksum-verify, extract
--------------------------------------------------------------------------------

local RELEASE_BASE = "https://github.com/router-for-me/CLIProxyAPI/releases/download"
local PINNED_VERSION = "7.1.71" -- pinned, NOT "latest" — reproducible
local BIN_NAME = "cli-proxy-api" -- the executable inside the release tarball

local function bin_dir()
    local dir = data_root() .. "/bin"
    vim.fn.mkdir(dir, "p")
    return dir
end

--- Path to the auto-downloaded binary, if present + executable.
---@return string|nil
function M.managed_binary()
    local p = bin_dir() .. "/" .. BIN_NAME
    if vim.fn.executable(p) == 1 then
        return p
    end
    return nil
end

local function sha256_of(path)
    local cmd = vim.fn.executable("sha256sum") == 1
        and { "sha256sum", path }
        or { "shasum", "-a", "256", path }
    local res = vim.system(cmd, { text = true }):wait()
    return (res.stdout or ""):match("^(%x+)")
end

--- Download + checksum-verify + extract the pinned release into the managed
--- bin dir. Synchronous (one-time setup; used by auto_download / :ParleyProxy
--- update). Refuses to install on a checksum mismatch.
---@param opts table|nil # { version, base_url } — base_url overridable for tests
---@return string|nil binary_path, string|nil err
function M.download(opts)
    opts = opts or {}
    local c = cfg() or {}
    local version = opts.version or c.download_version or PINNED_VERSION
    local base = opts.base_url or RELEASE_BASE
    local plat = cc.platform()
    if not plat then
        return nil, "no published cliproxy release for this platform"
    end
    if plat.os == "windows" then
        return nil, "auto_download does not support Windows (.zip) — install cliproxyapi manually"
    end
    local asset = cc.asset_name(version, plat)
    local tarball_url = ("%s/v%s/%s"):format(base, version, asset)
    local sums_url = ("%s/v%s/checksums.txt"):format(base, version)

    -- Bounded: download() runs synchronously on the main loop (opt-in, one-time),
    -- so a stalled fetch must not freeze the editor indefinitely.
    local tmp = vim.fn.tempname() .. ".tar.gz"
    local dl = vim.system({ "curl", "-fsSL", "--connect-timeout", "10", "--max-time", "300",
        "-o", tmp, tarball_url }, { text = true }):wait()
    if dl.code ~= 0 then
        os.remove(tmp) -- curl -o may have left a partial file
        return nil, "download failed (" .. tarball_url .. "): " .. tostring(dl.stderr)
    end
    local sums = vim.system({ "curl", "-fsSL", "--connect-timeout", "10", "--max-time", "30",
        sums_url }, { text = true }):wait()
    if sums.code ~= 0 then
        os.remove(tmp)
        return nil, "checksums fetch failed: " .. tostring(sums.stderr)
    end
    local expected = cc.parse_checksums(sums.stdout or "", asset)
    if not expected then
        os.remove(tmp)
        return nil, asset .. " not listed in checksums.txt"
    end
    local actual = sha256_of(tmp)
    if not actual or actual ~= expected then
        os.remove(tmp)
        return nil, "checksum mismatch for " .. asset .. " — refusing to install (expected "
            .. expected .. ", got " .. tostring(actual) .. ")"
    end
    local dir = bin_dir()
    local ex = vim.system({ "tar", "-xzf", tmp, "-C", dir, BIN_NAME }, { text = true }):wait()
    os.remove(tmp)
    if ex.code ~= 0 then
        return nil, "extract failed: " .. tostring(ex.stderr)
    end
    local bin = dir .. "/" .. BIN_NAME
    local fs_chmod = uv.fs_chmod or vim.loop.fs_chmod
    fs_chmod(bin, tonumber("755", 8))
    return bin
end

--- Re-fetch the pinned binary (for :ParleyProxy update).
---@return string|nil binary_path, string|nil err
function M.update()
    return M.download()
end

return M
