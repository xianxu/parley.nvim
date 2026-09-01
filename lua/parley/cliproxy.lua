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
-- Timing constants the repair budget derives from. Changing one changes the
-- budget automatically (cliproxy_budget_spec asserts it still fits under the
-- dispatcher's backstop), which is what stops the comment-and-code drift that
-- three successive reviews re-opened.
local CURL_MAX_TIME = 2      -- seconds, --max-time on every probe
local PORT_RELEASE_MS = 2000 -- wait_port_released deadline
local POLL_BUDGET_MS = 5000  -- poll_until_healthy deadline

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
    local args = { "curl", "-s", "-w", "\n%{http_code}", "--max-time", tostring(CURL_MAX_TIME) }
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
-- Just enough to ADDRESS the proxy: host, port, client bearer. Extracted because
-- render_opts's first three fields are exactly this, and a second byte-identical
-- derivation is a second place for the secret-name lookup to drift (ARCH-DRY).
-- It also has NO side effects, which render_opts does: it mints a management
-- key, and callers on a UI path must not.
local function endpoint_opts()
    local host, port = cc.parse_endpoint(endpoint())
    return {
        host = host,
        port = port,
        secret = require("parley.vault").get_secret(
            require("parley.providers").get_secret_name("cliproxyapi")),
    }
end

local function render_opts()
    local base = endpoint_opts()
    local c = cfg() or {}
    return {
        host = base.host,
        port = base.port,
        auth_dir = c.auth_dir,
        secret = base.secret,
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
-- Derived from the constants each step actually uses, NOT restated: CURL_MAX_TIME
-- is the --max-time on every probe, and the two bounded polls check their
-- deadline only AFTER a probe returns, so each can overrun by one full probe.
M._repair_budget_sec = {
    liveness_probe = CURL_MAX_TIME,
    auth_files = CURL_MAX_TIME,
    stop_identity_probe = CURL_MAX_TIME,
    port_release = PORT_RELEASE_MS / 1000 + CURL_MAX_TIME,
    ensure_probe = CURL_MAX_TIME,
    poll_healthy = POLL_BUDGET_MS / 1000 + CURL_MAX_TIME,
    second_read = CURL_MAX_TIME,
}

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
    local deadline = uv.now() + PORT_RELEASE_MS
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
--- REPAIR BUDGET — the whole claimed path must finish inside the dispatcher's
--- `recovery_timeout_ms`, or the backstop spends the claim's one-shot and the
--- operator is told "recovery timed out" even though parley repaired the proxy
--- and computed a correct diagnosis.
---
--- The terms are DERIVED in `M._repair_budget_sec` from the constants each step
--- uses (`CURL_MAX_TIME`, `PORT_RELEASE_MS`, `POLL_BUDGET_MS`), including the one
--- extra probe each bounded poll can overrun by — so the table cannot be right
--- while the code is wrong. `cliproxy_budget_spec` asserts the inequality
--- against `dispatcher.recovery_timeout_ms`.
---
--- The compound case (404 repair, then a `restart` decision on the second read)
--- is made UNREACHABLE rather than budgeted: the ladder skips the restart rung
--- when `_management_restart_done` shows this claim already restarted the proxy.
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
                cb(second, true) -- second arg: this lookup restarted the proxy
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
        -- Surface the rotation race once per session. The flag is checked BEFORE
        -- peers(), not inside warn_about_peers: peers() shells out to `ps ax`
        -- plus `lsof` (~80-90ms measured, blocking the event loop) and this runs
        -- in pre_query on every single dispatch.
        if not M.peer_warning_shown() then
            -- Arm FIRST: if peers() raises (unreadable process table), leaving
            -- the latch unset would restore the ~150ms blocking scan on every
            -- dispatch — the exact regression this guard exists to prevent.
            M._arm_peer_scan()
            pcall(function()
                M.warn_about_peers(M.peers())
            end)
        end
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
    -- NB: `_spawned` already holds every pid this session spawned, on any port,
    -- and the loop above kills all of them — so a proxy left on a since-changed
    -- endpoint is covered. Proxies from EARLIER nvim sessions are not reachable
    -- from any in-process table; that is what peers()/reap() is for.
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

--- Does this usage text declare `flag` as a flag in its own right?
---
--- Whole-token, never a substring: `-login` (google) is a substring of
--- `-claude-login`, `-codex-login`, `-kimi-login` and `-xai-login`, so a
--- `find(flag, 1, true)` passes on every build — including the ones that
--- dropped `-login`, which is the single case the check exists for.
---@param help string
---@param flag string
---@return boolean
function M._usage_has_flag(help, flag)
    for line in help:gmatch("[^\n]+") do
        local token = line:match("^%s*(%-[%w%-]+)")
        if token == flag then
            return true
        end
    end
    return false
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
    -- The flag set is version-dependent: 7.2.110 dropped `-login` (google) that
    -- 7.1.71 had. Ask THIS binary rather than trusting a static table, so the
    -- operator gets "your cliproxy doesn't support this" instead of a silent
    -- non-login.
    local usage = vim.system({ bin, "-h" }, { text = true }):wait()
    local help = (usage.stdout or "") .. (usage.stderr or "")
    if help ~= "" and not M._usage_has_flag(help, flag) then
        return nil, ("this cliproxy build has no `%s` flag — `%s -h` lists what it supports")
            :format(flag, bin)
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

--- Has the once-per-session peer warning already fired? Consulted BEFORE the
--- expensive peers() scan, which runs on the dispatch hot path.
---@return boolean
function M.peer_warning_shown()
    return _peer_warning_shown
end

--- Mark the once-per-session peer scan as done, whatever its outcome.
function M._arm_peer_scan()
    _peer_warning_shown = true
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
    if _peer_warning_shown then
        return
    end
    -- Latch on the SCAN, not on there being something to say. Latching only when
    -- peers exist meant a healthy machine — the one that just reaped its leaked
    -- proxies, as this milestone instructs — never armed the guard and paid the
    -- ~150ms blocking ps+lsof on EVERY dispatch, forever.
    _peer_warning_shown = true
    if #peers == 0 then
        return
    end
    local prefix = (require("parley").config or {}).cmd_prefix or "Parley"
    -- `ps lstart` starts with the WEEKDAY ("Fri Jun 12 …"), so a lexicographic
    -- compare orders by day name — it would call a Friday process older than a
    -- Sunday one from months earlier.
    local oldest = peers[1]
    for _, p in ipairs(peers) do
        if (ca.lstart_sec(p.started) or math.huge) < (ca.lstart_sec(oldest.started) or math.huge) then
            oldest = p
        end
    end
    logger.warning(([[cliproxy: %d other cliproxy process(es) are running (oldest since %s).
Each runs its own 15-minute auth refresh over the shared auth-dir, and OAuth
refresh tokens ROTATE on use — so they can invalidate each other's credential
(this is what broke auth in #197). Run `:%sProxy reap` to stop them.]])
        :format(#peers, oldest.started, prefix))
end

--- SIGTERM every peer found by `peers()`.
---
--- Identity comes from `parse_peers`' executable match — the command's first
--- token must BE a cliproxy binary — not from a port probe: a peer is by
--- definition not on the managed port, so there is nothing to probe against.
--- Counts only kills the OS accepted.
---@param peers table[]|nil # the list the operator confirmed; re-scans if omitted
---@return number killed, number skipped
function M.reap(peers)
    local killed, skipped = 0, 0
    -- Kill exactly what was shown and confirmed: a fresh scan here would list a
    -- different set than the operator agreed to (proxies start and exit between
    -- the prompt and the answer).
    for _, peer in ipairs(peers or M.peers()) do
        -- The command line records the config it booted from; a process we
        -- cannot identify as a proxy we started is left alone.
        -- luv's kill RETURNS nil+err (ESRCH, EPERM) rather than raising, so a
        -- bare pcall counts failures as successes and tells the operator the
        -- rotation race is resolved when nothing was stopped.
        local called, rc = pcall(uv.kill, peer.pid, "sigterm")
        if called and rc == 0 then
            killed = killed + 1
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

-- Newest credential mtime anywhere in the auth-dir, for the LOGIN watch, where
-- no health record exists yet and any new credential counts.
local function newest_credential_mtime(login)
    local channels = {}
    for _, ch in ipairs(login and cc.channels_for_login(login) or {}) do
        channels[ch] = true
    end
    local c = cfg() or {}
    local dir = c.auth_dir
    if type(dir) ~= "string" or dir == "" then
        dir = vim.fn.expand("~/.cli-proxy-api")
    end
    local newest
    for _, name in ipairs(vim.fn.isdirectory(dir) == 1 and vim.fn.readdir(dir) or {}) do
        -- Filter by the credential's declared `type`, not the filename: a PEER
        -- proxy's 15-minute refresh rewriting an unrelated credential would
        -- otherwise satisfy a login watch that never completed.
        local matches = next(channels) == nil
        if not matches and name:sub(-5) == ".json" then
            -- The READ must be inside the pcall, not just the decode: arguments
            -- evaluate first, and vim.fn.readfile RAISES (E17 on a directory,
            -- E484 on a file that vanished between readdir and here — which peer
            -- proxies cause every 15 minutes). This runs in an async poll with no
            -- outer guard, so a raise would strand the login watch entirely.
            local ok, decoded = pcall(function()
                return vim.json.decode(table.concat(vim.fn.readfile(dir .. "/" .. name), "\n"))
            end)
            matches = ok and type(decoded) == "table" and channels[decoded.type] == true
        end
        if name:sub(-5) == ".json" and matches then
            local st = uv.fs_stat(dir .. "/" .. name)
            if st and st.mtime and (not newest or st.mtime.sec > newest) then
                newest = st.mtime.sec
            end
        end
    end
    return newest
end

-- Claude's OAuth redirect is fixed at http://localhost:54545/callback (read out
-- of the 7.1.71 binary and confirmed by running the flow). The other providers
-- use their own ports; 54545 is the one #197 got stuck on.
local CALLBACK_PORTS = { claude = 54545 }

--- Is the OAuth callback port already held? Returns nil when free, else a
--- message naming the remedy.
---
--- Preflight exists because of the exact dead end in #197: the login process
--- died, its callback listener went with it, and the browser's redirect had
--- nowhere to land — so the account chooser looked inert with no error anywhere.
---@param provider string
---@return string|nil blocked_reason
function M.callback_port_blocked(provider)
    local port = CALLBACK_PORTS[provider]
    if not port then
        return nil
    end
    -- CONNECT, don't bind: libuv sets SO_REUSEADDR, so a second bind succeeds
    -- even while another socket is actively listening — a bind probe would
    -- report "free" for exactly the case this exists to catch. A successful
    -- connect means something is listening, whatever set it up.
    local connected = false
    local probe = uv.new_tcp()
    local done = false
    probe:connect("127.0.0.1", port, function(err)
        connected = err == nil
        done = true
        pcall(function() probe:close() end)
    end)
    vim.wait(500, function() return done end, 10)
    if not done then
        pcall(function() probe:close() end)
    end
    if not connected then
        return nil
    end
    return ("cliproxy: OAuth callback port %d is already in use, so the browser "
        .. "redirect would have nowhere to land. Stop whatever holds it (`lsof -nP -iTCP:%d`) "
        .. "— a stale login is the usual culprit — or pass -oauth-callback-port to use another.")
        :format(port, port)
end

--- Watch the auth-dir for a credential appearing/refreshing for `provider`,
--- so a login's outcome is observed rather than assumed.
---@param channel string
---@param since number|nil # epoch seconds; a file newer than this counts
---@param timeout_ms number
---@param cb fun(ok: boolean)
function M.await_credential(login, since, timeout_ms, cb)
    local deadline = uv.now() + timeout_ms
    local function poll()
        local mt = newest_credential_mtime(login)
        if mt and (since == nil or mt > since) then
            return cb(true)
        end
        if uv.now() >= deadline then
            return cb(false)
        end
        vim.defer_fn(poll, 500)
    end
    poll()
end

--- Run an interactive OAuth login and REPORT ITS OUTCOME.
---
--- Three things #197 needed and the terminal-split version didn't do: it kept
--- the job alive independently of a closable buffer, it surfaced the authorize
--- URL so a failed auto-open is still recoverable, and it said whether the login
--- actually produced a credential instead of dying silently.
---@param provider string
---@param argv string[]
---@param on_done fun(ok: boolean)|nil
---@param timeout_ms number|nil # how long to watch for a credential (default 3min).
---   Injectable so the timeout branch is reachable from a spec without sleeping.
function M.run_login(provider, argv, on_done, timeout_ms)
    -- One settle, ever: on_exit(non-zero) reported the failure immediately while
    -- await_credential kept polling to its 3-minute deadline and then fired a
    -- second time — telling an operator who had since logged in successfully
    -- that their login "did not complete".
    local settled = false
    local raw_done = on_done or function() end
    -- The latch guards the NOTIFY as well as the callback: guarding only the
    -- callback still let an abandoned watcher tell an operator — three minutes
    -- after they were correctly told the login died, and after they had since
    -- logged in successfully — that their login "did not complete".
    local function settle(ok, message, level)
        if settled then
            return
        end
        settled = true
        if message then
            vim.notify(message, level)
        end
        raw_done(ok)
    end
    -- channels_for_login("google") is {aistudio, gemini, gemini-cli}; taking [1]
    -- picks aistudio while a -login writes gemini-cli. Read across all of them.
    local before = newest_credential_mtime(provider)
    -- Do NOT pass -no-browser: each provider's flow differs (claude prints a
    -- claude.ai/oauth/authorize URL; google/kimi/xai/antigravity print their own,
    -- or drive the browser themselves), and suppressing the binary's browser
    -- while matching only a claude-shaped URL left every other provider with a
    -- silent, uncompletable login. Let the binary do exactly what it always did,
    -- and ADD observability on top.
    local cmd = vim.deepcopy(argv)
    local output = {}
    local shown = false

    local function handle_line(line)
        output[#output + 1] = line
        -- Surface the instructions once, whatever shape they take — the URL may
        -- be any host, and some providers print a code to paste instead.
        --
        -- DEBOUNCED: the binary prints its instructions across several lines
        -- ("Visit the following URL:" then the URL), so emitting on the first
        -- matching line would show a header with nothing under it.
        if not shown and (line:match("https?://%S+") or line:lower():match("visit")) then
            shown = true
            vim.defer_fn(function()
                if settled then
                    return -- the login already died; don't invite them to continue it
                end
                vim.notify(("cliproxy: %s login started — follow the instructions below "
                    .. "(the browser may have opened already):\n%s"):format(
                    provider, table.concat(output, "\n")), vim.log.levels.INFO)
            end, 300)
        end
    end

    -- jobstart, NOT a terminal buffer: the buffer version died with the window
    -- and took the callback listener with it.
    local job = vim.fn.jobstart(cmd, {
        on_stdout = function(_, data)
            for _, line in ipairs(data or {}) do
                if line ~= "" then
                    handle_line(line)
                end
            end
        end,
        on_stderr = function(_, data)
            for _, line in ipairs(data or {}) do
                if line ~= "" then
                    handle_line(line)
                end
            end
        end,
        on_exit = function(_, code)
            if code ~= 0 then
                return settle(false, ("cliproxy: %s login exited %d%s"):format(provider, code,
                    #output > 0 and ("\n" .. table.concat(output, "\n"):sub(-400)) or ""),
                    vim.log.levels.ERROR)
            end
        end,
    })
    if job <= 0 then
        return settle(false, "cliproxy: could not start the login process", vim.log.levels.ERROR)
    end

    -- Observe the outcome instead of assuming it.
    M.await_credential(provider, before, timeout_ms or 180000, function(ok)
        if settled then
            return -- the exit path already reported; this watcher is abandoned
        end
        if ok then
            M.credential_health_for_login(provider, function(health)
                M._on_login_success(provider)
                settle(true, ("cliproxy: %s login succeeded%s"):format(provider,
                    health.account and (" (" .. health.account .. ")") or ""), vim.log.levels.INFO)
            end)
        else
            pcall(vim.fn.jobstop, job)
            settle(false, ("cliproxy: %s login did not complete — no credential was written. "
                .. "Re-run `:ParleyProxy login %s`."):format(provider, provider), vim.log.levels.WARN)
        end
    end)
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
        -- vim.ui.select is routinely replaced (dressing.nvim, telescope-ui-select,
        -- snacks.nvim) and those implementations can raise. Unguarded, that skips
        -- done() — stranding the claim until the backstop discards the diagnosis
        -- — AND leaves _login_prompt_active true, so no login is ever offered
        -- again for the rest of the session.
        local prompt_ok, prompt_err = pcall(function()
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
        if not prompt_ok then
            _login_prompt_active = false
            logger.error("cliproxy: login prompt failed: " .. tostring(prompt_err))
            done()
        end
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
    -- Per-claim, because credential_health CLEARS _management_restart_done on a
    -- successful read — which happens before the decision is computed, so
    -- reading module state here always saw false and the compound
    -- repair-then-restart path (~36s, past the backstop) was never actually
    -- blocked.
    local restarted_this_claim = false

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
                if restarted_this_claim then
                    -- The 404 repair already restarted this proxy inside THIS
                    -- claim. Restarting again would stack two full repair
                    -- budgets (~28s) past the dispatcher's 25s backstop, which
                    -- would spend the claim's one-shot and replace the
                    -- diagnosis with "recovery timed out". One restart per
                    -- claim; retry against what we have.
                    return retry()
                end
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
        M.credential_health(function(health, repaired)
            restarted_this_claim = repaired == true
            -- Staleness is decided entirely inside the record now (modtime vs
            -- updated_at), so proxy_state carries only liveness.
            execute(ca.decide(verdict, health, { running = true }, attempt, login), health)
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
-- Model catalog (issue #205)
--
-- cliproxy already knows what it serves, and that set moves on its own — an
-- antigravity login registered 13 new models mid-session, no restart. Parley
-- reads that catalog instead of carrying model names in config.
--------------------------------------------------------------------------------

local CATALOG_TTL = 600 -- seconds a SUCCESSFUL catalog stays fresh
local FAILED_ATTEMPT_BACKOFF = 30 -- seconds to back off after a FAILED attempt
local _catalog_inflight = false
local _last_attempt = nil -- when a refresh was last ATTEMPTED, accepted or not
local _force_stale = false -- set when something invalidates BOTH clocks (a login)

-- No mkdir here: this is called on every picker open and every cache read, and
-- only the WRITE needs the directory to exist.
local function catalog_path()
    return data_root() .. "/catalog.json"
end

M._catalog_path = catalog_path -- exposed for tests

--- The last catalog we saw, straight off disk. Synchronous and small (~5 KB for
--- today's 43 models) because the picker renders from it — the UI path never
--- waits on the network.
---@return table[] models, number|nil fetched_at
local _catalog_memo = nil -- { models, fetched_at, mtime }

function M.catalog_cached()
    -- Memoized on the file's mtime: the picker reads this on open, on every
    -- <C-a> toggle and on every repaint, and each miss was two file reads plus
    -- two mkdir syscalls on a keystroke path.
    local stat = vim.uv and vim.uv.fs_stat(catalog_path()) or nil
    local mtime = stat and stat.mtime and (stat.mtime.sec or 0) .. "." .. (stat.mtime.nsec or 0)
    if _catalog_memo and mtime and _catalog_memo.mtime == mtime then
        return _catalog_memo.models, _catalog_memo.fetched_at
    end
    local fd = io.open(catalog_path(), "r")
    if not fd then
        return {}, nil
    end
    local body = fd:read("*a")
    fd:close()
    local ok, decoded = pcall(vim.json.decode, body)
    if not ok or type(decoded) ~= "table" or type(decoded.models) ~= "table" then
        return {}, nil
    end
    -- Sanitize HERE, at the one boundary every consumer reads through. This file
    -- is on disk between sessions and can be truncated, hand-edited or written by
    -- an older parley; a row without a string id makes `_view_for` concatenate
    -- nil and `_build_items` render nil, i.e. the agent picker throws on open.
    -- One guard rather than a nil-check in each consumer.
    local rows = {}
    for _, m in ipairs(decoded.models) do
        if type(m) == "table" and type(m.id) == "string" and m.id ~= "" then
            m.display = type(m.display) == "string" and m.display or m.id
            m.series = type(m.series) == "string" and m.series or
                require("parley.cliproxy_catalog").series(m.id)
            rows[#rows + 1] = m
        end
    end
    _catalog_memo = { models = rows, fetched_at = tonumber(decoded.fetched_at), mtime = mtime }
    return rows, _catalog_memo.fetched_at
end

--- Persist a catalog. Also the seam a spec uses to seed one without a live
--- proxy (#205 Task 4.1 needs a catalog with no network).
---@param models table[]
---@param fetched_at number|nil
function M._write_catalog(models, fetched_at)
    vim.fn.mkdir(data_root(), "p")
    local fd = io.open(catalog_path(), "w")
    if not fd then
        return false -- nothing was stored: the invalidation is still owed
    end
    fd:write(vim.json.encode({ models = models, fetched_at = fetched_at or os.time() }))
    fd:close()
    -- AFTER the write succeeded, never before. An invalidation is consumed by a
    -- STORED result; clearing it at the start of an attempt lost it on the first
    -- declined refresh, and clearing it at the top of this function loses it just
    -- as surely when the open fails. The rule both times: the flag clears where
    -- the work it is paid for has actually happened.
    _force_stale = false
    _catalog_memo = nil -- the file just changed; the next read re-stats it
    pcall(vim.fn.setfperm, catalog_path(), "rw-------")
    return true
end

--- What a completed login must do besides reporting itself.
---
--- Extracted so it is reachable from a spec: inline in the watch callback it had
--- zero coverage, and deleting it left the suite green — the failure this issue
--- has hit five times.
---@param provider string
function M._on_login_success(provider)
    -- The catalog just changed: a login is exactly what registers a channel's
    -- models, so any staleness clock is answering about a different world.
    logger.debug("cliproxy: " .. tostring(provider) .. " login succeeded — invalidating the catalog")
    M.invalidate_catalog()
end

--- Force the next staleness check to say "refresh", whatever either clock says.
---
--- Called when a login completes. Clearing only the failure clock is NOT enough,
--- and that was the bug: `catalog_stale` short-circuits on a fresh CACHE before
--- it ever consults the attempt clock, and a `(logged out)` row exists precisely
--- because a SUCCESSFUL fetch lacked that provider's models — so the common case
--- HAS a fresh cache, and the operator kept seeing the row they had just logged
--- in through for up to the full TTL.
function M.invalidate_catalog()
    _last_attempt = nil
    _force_stale = true
end

--- Test seam: put both clocks back to "never tried", WITHOUT forcing a refresh.
--- Deliberately distinct from `invalidate_catalog` — a spec setting up a clean
--- clock is not the same act as a login announcing the catalog just changed, and
--- one function doing both made every spec that reset the clock see everything
--- as stale.
function M._reset_catalog_clock()
    _last_attempt = nil
    _force_stale = false
end

--- Test seam: pretend the last failed attempt happened at `t`, so a spec can
--- cross the backoff without sleeping through it.
function M._set_failed_attempt_at(t)
    _last_attempt = t
end

--- Is it worth another refresh?
---
--- TWO clocks, because a success and a failure mean different things:
---   * a fresh CACHE is good for CATALOG_TTL — models rarely move;
---   * a failed ATTEMPT backs off for FAILED_ATTEMPT_BACKOFF only, seconds not
---     minutes. Keying a failure on the success TTL silenced the picker for ten
---     minutes, including immediately after the operator logged in through the
---     `(logged out)` row — precisely when the catalog HAS just changed.
--- Keying only on success is the opposite failure: the cache is never written
--- while the proxy is down, so every picker open re-spawns two curls that
--- connection-refuse, an unbounded retry on a keystroke path.
---@return boolean
function M.catalog_stale()
    local _, at = M.catalog_cached()
    return cc.catalog_stale({
        now = os.time(),
        cached_at = at,
        last_attempt = _last_attempt,
        forced = _force_stale,
        ttl = CATALOG_TTL,
        backoff = FAILED_ATTEMPT_BACKOFF,
    })
end

--- Refresh the catalog from a proxy that is ALREADY running.
---
--- Deliberately NOT routed through ensure_running: opening a picker must never
--- spawn a daemon (#131's dormancy contract). A connection-refused is a no-op
--- that leaves the cached catalog in place, so the picker keeps rendering what
--- it last knew.
---
--- Two routes because neither is sufficient: /v1/models carries `created`,
--- /v1beta/models carries the display names.
---@param cb fun(models: table[])|nil
function M.fetch_catalog(cb)
    -- Every exit path resolves the callback exactly once. Returning silently
    -- while a refresh is in flight strands the caller: a picker opened during
    -- one would never repaint, because the in-flight fetch's callback belongs to
    -- an earlier, possibly closed, picker.
    cb = cb or function() end
    if _catalog_inflight then
        return cb(M.catalog_cached())
    end
    _last_attempt = os.time()
    -- endpoint_opts(), NOT render_opts(): the latter gathers the whole
    -- write_rendered_config bundle, which MINTS a 0600 `management.key` as a
    -- side effect, and opening a picker must not create a credential file.
    local opts = endpoint_opts()
    if not opts.host or not opts.port then
        return cb(M.catalog_cached())
    end
    _catalog_inflight = true
    -- Cleared on EVERY path. It is set before two vim.system calls, so an
    -- uncaught error in either callback would strand it true for the rest of the
    -- session — and a stranded flag means the catalog never refreshes again.
    local function settle(models)
        _catalog_inflight = false
        cb(models)
    end
    -- Both the body and the HTTP status: "curl exited 0" is NOT "the request
    -- succeeded". A 401 carries a perfectly readable body that parses to an
    -- empty model list, and writing that would erase a good catalog every time
    -- the client key drifted.
    local function get(route, done)
        -- The LAUNCH is guarded, not just the callbacks: vim.system itself can
        -- throw (a malformed argv, a missing curl), and an unguarded throw here
        -- leaves _catalog_inflight true for the rest of the session — after
        -- which the catalog never refreshes again.
        local ok, err = pcall(vim.system,
            api_argv(opts.host, opts.port, opts.secret, route), { text = true },
            function(obj)
                if obj.code ~= 0 then
                    return done(nil, nil)
                end
                local body, http = split_status(obj.stdout)
                done(body or obj.stdout, tonumber(http))
            end)
        if not ok then
            logger.debug("cliproxy: catalog request could not start: " .. tostring(err))
            done(nil, nil)
        end
    end
    get("/v1/models", function(v1, v1_status)
        get("/v1beta/models", function(beta, _beta_status)
            vim.schedule(function()
                local ok, models = pcall(function()
                    return require("parley.cliproxy_catalog").parse(v1 or "", beta or "")
                end)
                if not ok then
                    -- debug, not error: this runs on picker open, where an
                    -- unreadable body is not something the operator asked about
                    -- and a popup would interrupt them mid-keystroke.
                    logger.debug("cliproxy: catalog parse failed: " .. tostring(models))
                    return settle(M.catalog_cached())
                end
                -- Write only when the response is RECOGNISABLY cliproxy's model
                -- list. Three weaker gates were tried and each lost data:
                -- `#models > 0` conflated "nothing is authenticated" with "the
                -- proxy is down"; curl's exit code let a 401 body parse to an
                -- empty list and erase a good catalog; and HTTP 200 alone let
                -- whatever else is listening on that port do the same. `classify`
                -- is the existing single source for "is this cliproxy's /v1/models
                -- contract" (ARCH-DRY) — `healthy` or `needs_login` are the two
                -- shapes that ARE that contract, empty list included.
                local shape = classify(0, (v1 or "") .. "\n" .. tostring(v1_status or 0))
                if v1_status == 200 and (shape == "healthy" or shape == "needs_login") then
                    M._write_catalog(models)
                else
                    -- Debug, never a popup: this runs on a picker-open path and
                    -- a proxy that is simply down is not an error the operator
                    -- asked about. The cached catalog stays on screen.
                    logger.debug(("cliproxy: catalog refresh declined (http=%s shape=%s) — "
                        .. "keeping the cached catalog"):format(tostring(v1_status), tostring(shape)))
                    -- Hand back what is actually IN the cache. `models` is the
                    -- parse of a body we just refused to store (a 401 page, a
                    -- foreign server), so resolving with it has the caller render
                    -- rows the cache does not contain. Both declined branches —
                    -- this one and the parse failure above — resolve the same way.
                    return settle(M.catalog_cached())
                end
                settle(models)
            end)
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
