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
local ca = require("parley.cliproxy_auth")
local logger = require("parley.logger")

local M = {}

-- pid -> uv process handle for proxies PARLEY spawned (so stop() is scoped to
-- our own daemon and never touches a reused/foreign one).
local _spawned = {}

-- Every pid parley has EVER spawned this session, including ones no longer on
-- the managed port (an endpoint change would otherwise strand them: _spawned is
-- cleared by stop(), and the port sweep only covers the current port).
local _stray_spawned = {}

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

-- Split a curl `-w "\n%{http_code}"` result into body + numeric status.
local function split_status(stdout)
    local body, http = (stdout or ""):match("^(.*)\n(%d+)%s*$")
    return body, tonumber(http)
end

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
    local body, http = split_status(stdout)
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

-- Build the curl argv for a GET against host:port with an optional bearer.
-- Single source of truth for the request shape (ARCH-DRY): the health probe,
-- the stop-time identity check, list_models, and the management-API reader all
-- go through here. `-w "\n%{http_code}"` appends the status code on its own
-- line so callers can split body from code.
---@param route string|nil # defaults to /v1/models
local function api_argv(host, port, secret, route)
    local args = { "curl", "-s", "-w", "\n%{http_code}", "--max-time", "2" }
    if type(secret) == "string" and secret ~= "" then
        table.insert(args, "-H")
        table.insert(args, "Authorization: Bearer " .. secret)
    end
    table.insert(args, ("http://%s:%s%s"):format(host, port, route or "/v1/models"))
    return args
end

--- Probe http://host:port/v1/models with the client bearer and classify.
--- Async; calls cb(state) on the main loop.
---@param host string
---@param port number
---@param secret string|nil
---@param cb fun(state: string)
function M.health_probe(host, port, secret, cb)
    vim.system(api_argv(host, port, secret), { text = true }, function(obj)
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

local function management_key_path()
    local dir = data_root()
    vim.fn.mkdir(dir, "p")
    return dir .. "/management.key"
end

M._management_key_path = management_key_path -- exposed for tests

--- The bearer for cliproxy's management API (#197), read-or-created beside the
--- rendered config at 0600.
---
--- Deliberately NOT in the vault: the vault is in-memory and populated from
--- setup{}, and this key must survive restarts without the operator having to
--- carry a generated secret in their dotfiles. It is a local-loopback
--- credential for a process parley itself launched.
---@return string
function M.management_key()
    local path = management_key_path()
    local f = io.open(path, "r")
    if f then
        local existing = (f:read("*a") or ""):gsub("%s+$", "")
        f:close()
        if existing ~= "" then
            return existing
        end
    end
    local bytes = { string.byte(uv.random(16), 1, 16) }
    local key = table.concat(vim.tbl_map(function(b)
        return ("%02x"):format(b)
    end, bytes))
    -- Create with 0600 directly rather than open-then-chmod: the latter leaves
    -- the key world-readable at the umask default for a brief window.
    local fd, oerr = uv.fs_open(path, "w", tonumber("600", 8))
    if not fd then
        -- Non-fatal: a key we cannot persist still works for this session, it
        -- just forces a proxy restart next time. Better than failing dispatch.
        logger.warning("cliproxy: cannot persist management key: " .. tostring(oerr))
        return key
    end
    uv.fs_write(fd, key)
    uv.fs_close(fd)
    return key
end

-- Single place that gathers the render inputs (host:port from the provider
-- endpoint, auth_dir, vault-resolved client secret, raw config passthrough).
-- Consumed by write_rendered_config, config_drift, and status (ARCH-DRY) — add
-- a render field here and all three pick it up.
local function render_opts()
    local host, port = cc.parse_endpoint(endpoint())
    local c = cfg() or {}
    local secret = require("parley.vault").get_secret(
        require("parley.providers").get_secret_name("cliproxyapi"))
    return {
        host = host,
        port = port,
        auth_dir = c.auth_dir,
        secret = secret,
        config = c.config,
        management_key = M.management_key(),
    }
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
-- Credential health (management API) — issue #197
--------------------------------------------------------------------------------

--- Read credential health for a cliproxy `channel` (e.g. "claude") from the
--- proxy's own /v0/management/auth-files.
---
--- This is the honest replacement for the two inferences that failed on
--- 2026-08-01: a response-body pattern, and the shape of /v1/models (which
--- still lists every model when the credential is dead).
---
--- The 404 is load-bearing rather than an error: cliproxy only registers the
--- management routes when a `remote-management.secret-key` is present in the
--- config it BOOTED with, so a 404 means the running proxy predates the key and
--- should be restarted into the freshly rendered config. That is also why we do
--- not compare the config file on disk to a fresh render — ensure_running
--- rewrites that file before it probes, so such a comparison is always false and
--- never reflects what the running process actually loaded.
---@param cb fun(health: table) # { state, message, account?, failed?, modtime?, reason? }
---@param channel string
function M.auth_files(cb, channel)
    local opts = render_opts()
    if not opts.host then
        return cb({ state = "unknown", reason = "no_endpoint",
            message = "cannot parse host:port from endpoint" })
    end
    vim.system(api_argv(opts.host, opts.port, opts.management_key, "/v0/management/auth-files"),
        { text = true }, function(obj)
            local body, http = split_status(obj.stdout)
            vim.schedule(function()
                if obj.code ~= 0 then
                    return cb({ state = "unknown", reason = "unreachable",
                        message = tostring(obj.stderr or "proxy unreachable") })
                end
                if http == 404 then
                    return cb({ state = "unknown", reason = "no_management_route",
                        message = "proxy is running without the management route" })
                elseif http == 401 then
                    return cb({ state = "unknown", reason = "management_key_mismatch",
                        message = "management key rejected by the running proxy" })
                elseif http ~= 200 then
                    return cb({ state = "unknown", reason = "http_" .. tostring(http),
                        message = "management API returned HTTP " .. tostring(http) })
                end
                local ok, decoded = pcall(vim.json.decode, body or "")
                if not ok or type(decoded) ~= "table" then
                    return cb({ state = "unknown", reason = "undecodable",
                        message = "management API returned an undecodable body" })
                end
                cb(ca.classify_auth_files(decoded.files, channel))
            end)
        end)
end


-- One-shot guard for the management-route repair. Module-local rather than
-- per-call because the repair is per-proxy-lifetime, not per-query.
--
-- It is cleared again as soon as a lookup succeeds, so it bounds *consecutive*
-- repair attempts rather than latching for the session: an operator who runs
-- `brew services restart cliproxyapi` mid-session gets a working repair again,
-- while a proxy that 404s for some other reason still cannot loop
-- (workshop/lessons.md: module-local one-shots leak if they only ever get set).
local _management_restart_done = false

-- The repair budget's terms, in seconds — exposed so a spec can assert the
-- relationship with dispatcher.recovery_timeout_ms rather than trusting a
-- comment (the M1 review re-opened this exact drift twice).
M._repair_budget_sec = { probe = 2, auth_files = 2, stop_probe = 2, port_release = 2,
    ensure_probe = 2, poll_healthy = 5, second_read = 2 }

function M._reset_management_restart() -- test seam
    _management_restart_done = false
end

-- Wait (bounded) for a port to stop answering after SIGTERM. M.stop() returns
-- immediately, and the REAL cliproxyapi shuts down gracefully — so without this
-- the follow-up probe can still see the dying proxy, take ensure_running's
-- reuse-if-healthy branch, and never spawn the replacement. The Python fake
-- dies instantly, which is why a test alone would not surface this.
local function wait_port_released(host, port, secret, cb)
    -- WALL-CLOCK deadline, not a count of sleeps: each health_probe is a curl
    -- with --max-time 2, so counting only the defer interval would let this run
    -- ~43s — past the dispatcher's 15s recovery backstop, which would have
    -- already told the chat leg "timed out" while this kept mutating proxies.
    -- Same shape poll_until_healthy uses. 2s, not 3s: this step is one term in
    -- the repair budget that must stay under dispatcher.recovery_timeout_ms —
    -- see the REPAIR BUDGET note above credential_health.
    local deadline = uv.now() + 2000
    local function poll()
        M.health_probe(host, port, secret, function(state)
            if state == "down" or uv.now() >= deadline then
                return cb(state == "down")
            end
            vim.defer_fn(poll, 150)
        end)
    end
    poll()
end

--- Stop the managed proxy, WAIT for the port to be released, then ensure a new
--- one is running. One sequence, two callers (the management-route repair and
--- the recovery ladder's `restart` rung) — the wait is the part that is easy to
--- omit and impossible to catch with the Python fake, which dies instantly while
--- the real cliproxyapi shuts down gracefully (ARCH-DRY).
---@param on_ready fun()
---@param on_error fun(msg: string)
function M.restart_managed(on_ready, on_error)
    local opts = render_opts()
    M.stop()
    wait_port_released(opts.host, opts.port, opts.secret, function()
        M.ensure_running(on_ready, on_error)
    end)
end


--- Credential health WITH the one repair parley can make unattended: a proxy
--- that booted before the management key existed answers 404, and restarting it
--- into the freshly rendered config is both safe and silent.
---
--- REPAIR BUDGET — the WHOLE claimed path must finish inside the dispatcher's
--- `recovery_timeout_ms`, or the backstop spends the claim's one-shot and the
--- operator is told "recovery timed out" even though parley repaired the proxy
--- and computed a correct diagnosis. Worst case, in order:
---   recover's liveness probe   ≤2s
---   auth_files curl            ≤2s
---   [404 repair] stop() probe  ≤2s   (blocking port_holds_cliproxy)
---   [404 repair] port release   2s
---   [404 repair] ensure probe  ≤2s
---   [404 repair] poll healthy   5s   (POLL_BUDGET_MS)
---   [404 repair] second read   ≤2s
---                            = ≤17s
--- The `start`/`restart` rung is mutually exclusive with the 404 repair (a proxy
--- that answered the management route is running, so `start` cannot follow; a
--- `restart` follows a SUCCESSFUL read, which means no repair ran), and costs
--- ≤11s on its own path. The binding worst case is therefore ≤17s against a 25s
--- backstop — asserted by cliproxy_budget_spec so the two cannot drift apart.
---
--- Restarts at most once per consecutive run of 404s (the guard clears on any
--- successful lookup). A second consecutive 404 is reported rather than retried, so a proxy that 404s for some other reason cannot become a restart
--- loop under every query.
---@param cb fun(health: table)
---@param channel string
function M.credential_health(cb, channel)
    M.auth_files(function(health)
        if health.reason ~= "no_management_route" then
            -- A working lookup means the repair is no longer spent: a proxy
            -- restarted out from under us later in the session can be repaired
            -- again (I2 — the guard bounds consecutive attempts, not the session).
            _management_restart_done = false
            return cb(health)
        end
        if not M.is_managed() then
            -- The proxy is the operator's own (`manage = false`). stop() reaps
            -- whoever holds the port and ensure_running does NOT spawn when
            -- unmanaged, so repairing here would kill their proxy and leave it
            -- dead. Report instead, with the fix they can apply themselves.
            return cb({ state = "unknown", reason = "no_management_route",
                message = "this proxy is not managed by parley — add "
                    .. "remote-management.secret-key to your own cliproxy config so parley "
                    .. "can read credential health" })
        end
        if _management_restart_done then
            return cb(health)
        end
        _management_restart_done = true
        logger.info("cliproxy: proxy is running without the management route — restarting it "
            .. "into the rendered config so credential health can be read")
        M.restart_managed(function()
            M.auth_files(function(second)
                if second.reason ~= "no_management_route" then
                    _management_restart_done = false
                end
                cb(second)
            end, channel)
        end, function(msg)
            cb({ state = "unknown", reason = "no_management_route",
                message = "cannot restart the proxy to enable the management route: " .. tostring(msg) })
        end)
    end, channel)
end

--- Credential health for a LOGIN PROVIDER (`google`), by reading every cliproxy
--- channel that login serves and keeping the healthiest.
---
--- The third axis: `:ParleyProxy models` names providers on the model-owning
--- axis, credential health is keyed by channel, and only five of six coincide —
--- `google` covers gemini / gemini-cli / aistudio. Reading health under "google"
--- finds nothing and fabricates "no credential" for a healthy account.
---@param login string
---@param cb fun(health: table)
function M.credential_health_for_login(login, cb)
    local channels = cc.channels_for_login(login)
    if #channels == 0 then
        return M.credential_health(cb, login) -- not a login-axis name; treat as a channel
    end
    local best, pending = nil, #channels
    for _, channel in ipairs(channels) do
        M.credential_health(function(health)
            if best == nil or ca.healthier(health, best) then
                best = health
            end
            pending = pending - 1
            if pending == 0 then
                cb(best)
            end
        end, channel)
    end
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
    _stray_spawned[#_stray_spawned + 1] = pid
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
    _stray_spawned = {}
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
        -- Surface the rotation race once per session, whichever path we take.
        pcall(function()
            M.warn_about_peers(M.peers())
        end)
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
    local res = vim.system(api_argv(host, port, secret), { text = true }):wait()
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
    -- Parley-spawned proxies on OTHER ports leaked before #197: _spawned only
    -- reaches this session, and the managed-port sweep above only reaches one
    -- port. A proxy this session started on a since-changed endpoint would
    -- otherwise outlive every stop() and keep refreshing the shared auth-dir.
    for _, pid in ipairs(_stray_spawned) do
        if not killed[pid] then
            pcall(uv.kill, pid, "sigterm")
            killed[pid] = true
        end
    end
    _stray_spawned = {}
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

---------------------------------------------------------------------------------
-- Peer proxies (#197 M3) — the rotation race that caused this issue
--------------------------------------------------------------------------------

local _peer_warning_shown = false

function M._reset_peer_warning() -- test seam
    _peer_warning_shown = false
end

--- Every cliproxy process on this machine that parley neither spawned nor
--- manages. Best-effort: an empty list when `ps` is unavailable.
---@return table[] # { pid, started, command }
function M.peers()
    if vim.fn.executable("ps") ~= 1 then
        return {}
    end
    -- pcall: vim.system RAISES (EPERM) rather than returning an error when the
    -- process table is unreadable — sandboxes and hardened runtimes do this.
    -- Peer detection is advisory, so it must never break a dispatch.
    local ok, res = pcall(function()
        return vim.system({ "ps", "ax", "-o", "pid,lstart,command" }, { text = true }):wait()
    end)
    if not ok or not res then
        return {}
    end
    local opts = render_opts()
    local port_pids = (opts.host and opts.port) and pids_on_port(opts.port) or {}
    return ca.parse_peers(res.stdout, M.spawned_pids(), port_pids)
end

--- Warn ONCE per session that peer proxies exist, naming the mechanism rather
--- than just the count — the operator cannot weigh "5 other proxies" without
--- knowing that each runs its own 15-minute refresh loop over the shared
--- auth-dir, and that Claude's refresh tokens rotate on use, so they invalidate
--- each other's credential. That is what happened in #197.
---@param peers table[]
function M.warn_about_peers(peers)
    if _peer_warning_shown or #peers == 0 then
        return
    end
    _peer_warning_shown = true
    local prefix = (require("parley").config or {}).cmd_prefix or "Parley"
    local oldest = peers[1]
    for _, p in ipairs(peers) do
        if p.started < oldest.started then
            oldest = p
        end
    end
    logger.warning(([[cliproxy: %d other cliproxy process(es) are running (oldest since %s).
Each runs its own 15-minute auth refresh over the shared auth-dir, and OAuth
refresh tokens ROTATE on use — so they can invalidate each other's credential
(this is what broke auth in #197). Run `:%sProxy reap` to stop them.]])
        :format(#peers, oldest.started, prefix))
end

--- SIGTERM every peer, after an identity probe per pid so a process that merely
--- shares a name is never killed.
---@return number killed, number skipped
function M.reap()
    local killed, skipped = 0, 0
    for _, peer in ipairs(M.peers()) do
        -- The command line records the config it booted from; a process we
        -- cannot identify as a proxy we started is left alone.
        if peer.command:match("%-config%s") then
            local ok = pcall(uv.kill, peer.pid, "sigterm")
            if ok then
                killed = killed + 1
            else
                skipped = skipped + 1
            end
        else
            skipped = skipped + 1
        end
    end
    return killed, skipped
end

--------------------------------------------------------------------------------
-- Auth-failure recovery (#197) — the single owner of "the query failed for
-- credential reasons". Replaces #131 M3's check_auth_failure, which sat on the
-- success path and matched one stale message.
--------------------------------------------------------------------------------

local _login_prompt_active = false

function M._reset_login_prompt() -- test helper
    _login_prompt_active = false
end

-- Newest mtime among a channel's credential files on disk, in EPOCH SECONDS.
--
-- Epoch, not a formatted string: the proxy reports its loaded credential in
-- local-offset RFC3339 and a string compare against a UTC "…Z" rendering is
-- wrong in a way that depends on the operator's timezone (always-stale west of
-- UTC, never-stale east). cliproxy_auth parses the proxy's side; both are
-- numbers by the time they meet.
local function auth_file_modtime(channel)
    local c = cfg() or {}
    local dir = c.auth_dir
    if type(dir) ~= "string" or dir == "" then
        dir = vim.fn.expand("~/.cli-proxy-api")
    end
    local newest
    for _, name in ipairs(vim.fn.readdir(dir) or {}) do
        if name:sub(1, #channel + 1) == channel .. "-" and name:sub(-5) == ".json" then
            local st = uv.fs_stat(dir .. "/" .. name)
            if st and st.mtime and (not newest or st.mtime.sec > newest) then
                newest = st.mtime.sec
            end
        end
    end
    return newest
end

-- The oauth-model-alias block parley rendered, or nil.
local function alias_block()
    local c = cfg() or {}
    return type(c.config) == "table" and c.config["oauth-model-alias"] or nil
end

-- Ask, once, whether to run the login this failure calls for. `message` is the
-- diagnosis, so the operator decides with the real reason in front of them
-- rather than a bare "needs login".
local function prompt_login(login, message, done)
    if _login_prompt_active then
        return done()
    end
    _login_prompt_active = true
    vim.schedule(function()
        local prefix = (require("parley").config or {}).cmd_prefix or "Parley"
        vim.ui.select({ "Log in (" .. login .. ")", "Not now" }, { prompt = message },
            function(_, idx)
                _login_prompt_active = false
                if idx == 1 then
                    -- Guarded: :ParleyProxy login opens a window and jobstarts a
                    -- terminal, so a constrained layout (E36) or any user
                    -- BufNew/TermOpen autocmd that errors would propagate out of
                    -- this callback and skip done() — stranding the claim until
                    -- the dispatcher's backstop replaces the diagnosis we just
                    -- showed with "recovery timed out".
                    local cmd_ok, cmd_err = pcall(vim.cmd, prefix .. "Proxy login " .. login)
                    if not cmd_ok then
                        logger.error("cliproxy: login command failed: " .. tostring(cmd_err))
                    end
                end
                done()
            end)
    end)
end

--- React to a failed cliproxy query. Registered as the cliproxyapi adapter's
--- `recover_query` hook, so the dispatcher owns the mechanism and this owns the
--- policy.
---
--- CLAIM CONTRACT (dispatcher.lua): returning truthy withholds the terminal
--- on_error and takes on the debt of calling exactly one of `retry`/`give_up`.
--- Every path below therefore ends in one of them — an early return that called
--- neither would hold the chat leg open until the dispatcher's backstop timer.
--- The claim itself is synchronous and cheap because classify_response is pure.
---@param failure table # { http_status, body, model, streamed, attempt, ... }
---@param _retry fun() # unused in M1: this milestone diagnoses, it never repairs.
---   M2's recovery ladder is what turns a verdict into a retry.
---@param give_up fun(msg: string)
---@return boolean claimed
function M.recover(failure, retry, give_up)
    local verdict = ca.classify_response(failure.http_status, failure.body, failure.model)
    if not verdict then
        return false -- not a credential failure: let the normal path report it
    end
    if failure.streamed then
        -- Content already reached the buffer; re-running would duplicate it, so
        -- we decline the claim and let the normal error path report. No
        -- credential lookup here: declining must stay synchronous.
        logger.warning("cliproxy: auth failure after partial content — not claiming (a retry "
            .. "would duplicate the streamed text)")
        return false
    end

    -- CHANNEL vs LOGIN PROVIDER are different namespaces and only coincide for
    -- claude. /v0/management/auth-files reports the CHANNEL (`gemini-cli`,
    -- `aistudio`, …) while several channels share one login (`google`), so
    -- querying health with a login provider silently finds nothing and
    -- fabricates "no credential is loaded".
    --
    -- The failure body's `providers=` field IS the channel, so prefer it; fall
    -- back to resolving the model through oauth-model-alias. If neither
    -- resolves, do NOT guess a channel — reporting another account's health for
    -- the failing model is worse than admitting we don't know.
    local channel = verdict.provider or cc.resolve_channel(verdict.model, alias_block() or {})
    local login = cc.channel_login(channel)
    local attempt = failure.attempt or 0

    if not channel then
        local health = { state = "unknown", reason = "unknown_channel",
            message = ("no cliproxy channel is configured for \"%s\""):format(tostring(verdict.model)) }
        give_up(ca.diagnosis(verdict, health) .. "\nAdd it to "
            .. "cliproxy.config['oauth-model-alias'], or run :ParleyProxy login <provider>.")
        return true
    end

    -- Executes exactly one action and settles the claim exactly once. Every
    -- branch ends in retry() or give_up() — an early return that called neither
    -- would hold the chat leg open until the dispatcher's backstop.
    local function execute(decision, health)
        if decision.action == "retry" then
            return retry()
        end
        if decision.action == "start" or decision.action == "restart" then
            if not M.is_managed() then
                -- Not ours to start or stop (see credential_health's note).
                return give_up(decision.message)
            end
            local function failed(msg)
                give_up(decision.message .. "\n" .. tostring(msg))
            end
            if decision.action == "restart" then
                return M.restart_managed(retry, failed)
            end
            return M.ensure_running(retry, failed)
        end
        if decision.action == "prompt_login" and decision.login_provider then
            return prompt_login(decision.login_provider, decision.message, function()
                give_up(decision.message)
            end)
        end
        local message = decision.message
        if health and health.state == "missing" and not login then
            message = message .. ("\nNo login offered: \"%s\" is in no "):format(tostring(verdict.model))
                .. "cliproxy.config['oauth-model-alias'] channel. Add it there, or run "
                .. ":ParleyProxy login <provider>."
        end
        give_up(message)
    end

    -- Gather the inputs `decide` needs, then let it own the policy.
    local opts = render_opts()
    M.health_probe(opts.host, opts.port, opts.secret, function(state)
        local running = state ~= "down"
        if not running then
            -- No proxy ⇒ no credential state to read; decide on liveness alone.
            local health = { state = "unknown", reason = "proxy_down",
                message = "the proxy is not running" }
            return execute(ca.decide(verdict, health, { running = false }, attempt, login), health)
        end
        M.credential_health(function(health)
            local proxy_state = { running = true, auth_file_modtime = auth_file_modtime(channel) }
            execute(ca.decide(verdict, health, proxy_state, attempt, login), health)
        end, channel)
    end)
    return true
end

--------------------------------------------------------------------------------
-- :ParleyProxy models — list a provider's served models
--------------------------------------------------------------------------------

--- List the models a provider currently serves: ensure_running, GET /v1/models
--- with the client bearer, then filter by the provider's owned_by. An EMPTY list
--- means the provider serves no models right now — NOT that it is
--- unauthenticated (#197 disproved that inference). The command layer reads
--- credential health to tell those apart.
---@param provider string
---@param cb fun(ids: string[]|nil, err: string|nil)
function M.list_models(provider, cb)
    local owned_by = cc.provider_owned_by(provider)
    if not owned_by then
        cb(nil, ("unknown provider '%s' — see :ParleyProxy providers"):format(tostring(provider)))
        return
    end
    M.ensure_running(function()
        local opts = render_opts()
        if not opts.host or not opts.port then
            cb(nil, "cannot parse host:port from endpoint")
            return
        end
        vim.system(api_argv(opts.host, opts.port, opts.secret), { text = true }, function(obj)
            vim.schedule(function()
                if obj.code ~= 0 then
                    cb(nil, "cliproxy: /v1/models request failed")
                    return
                end
                local body = split_status(obj.stdout) or obj.stdout
                cb(cc.filter_models_by_owner(body, owned_by), nil)
            end)
        end)
    end, function(err)
        cb(nil, err)
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
