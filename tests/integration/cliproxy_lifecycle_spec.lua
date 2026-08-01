-- Integration tests for lua/parley/cliproxy.lua (issue #131).
-- Exercises the IO seam against a process-level fake (tests/fixtures/fake_cliproxy),
-- not function mocks (AGENTS.md external-service rule).

local uv = vim.uv or vim.loop

local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

-- Redirect cliproxy's derived-artifact dir to a temp dir so this spec NEVER
-- touches the real ~/.local/share/nvim, even run bare (no XDG redirect).
local SPEC_DATA_DIR = vim.fn.tempname()
require("parley.cliproxy")._set_data_dir(SPEC_DATA_DIR)

-- Track fake processes started by a test so after_each can reap them.
local started = {}

local function free_port()
    local s = uv.new_tcp()
    s:bind("127.0.0.1", 0)
    local port = s:getsockname().port
    s:close()
    return port
end

-- Start the fake on `port` in `mode`; returns the pid.
local function start_fake(port, mode)
    local handle, pid = uv.spawn(FAKE, {
        args = { "--port", tostring(port), "--mode", mode },
    }, function() end)
    assert(handle, "failed to spawn fake_cliproxy")
    table.insert(started, { handle = handle, pid = pid })
    return pid
end

-- Run an async fn(done) and block until it calls done(result); return result.
local function await(fn)
    local result, got = nil, false
    fn(function(r)
        result = r
        got = true
    end)
    vim.wait(8000, function()
        return got
    end, 20)
    assert(got, "async call timed out")
    return result
end

-- Poll until the fake answers, so probes aren't racing startup.
local function wait_listening(port)
    vim.wait(5000, function()
        local ok = false
        local c = uv.new_tcp()
        c:connect("127.0.0.1", port, function(err)
            ok = err == nil
            c:close()
        end)
        vim.wait(100, function()
            return false
        end)
        return ok
    end, 50)
end

describe("cliproxy IO lifecycle", function()
    local parley = require("parley")
    local cliproxy = require("parley.cliproxy")
    local saved_config, saved_path

    before_each(function()
        saved_config = parley.config
        saved_path = vim.env.PATH
        -- System dirs only — deliberately WITHOUT /opt/homebrew/bin (#197).
        --
        -- A brew-installed `cliproxyapi` on PATH makes discover_binary() find
        -- the REAL binary, and ensure_running then spawns it with a config whose
        -- auth-dir is unset — i.e. pointed at the operator's real
        -- ~/.cli-proxy-api, starting a 15-minute refresh loop on their live
        -- credential. That is the very rotation hazard this issue exists to fix,
        -- and _set_data_dir above does not cover it (it guards the derived-artifact
        -- dir, not binary discovery). Tests that want a binary set binary_path
        -- explicitly; tests that want discovery to FAIL now get that
        -- deterministically. curl/env/python3 all live in /usr/bin, so the fake
        -- and the health probes still work.
        vim.env.PATH = "/usr/bin:/bin:/usr/sbin:/sbin"
        parley.config = { cliproxy = { manage = true } }
    end)

    after_each(function()
        parley.config = saved_config
        vim.env.PATH = saved_path
        vim.env.PARLEY_FAKE_MODE = nil
        for _, p in ipairs(started) do
            pcall(function()
                uv.kill(p.pid, "sigkill")
            end)
        end
        for _, pid in ipairs(cliproxy.spawned_pids()) do
            pcall(function()
                uv.kill(pid, "sigkill")
            end)
        end
        cliproxy._reset_spawned()
        started = {}
    end)

    --------------------------------------------------------------------------
    -- is_managed
    --------------------------------------------------------------------------
    describe("is_managed", function()
        it("is true only when manage == true", function()
            parley.config = { cliproxy = { manage = true } }
            assert.is_true(cliproxy.is_managed())
            parley.config = { cliproxy = { manage = false } }
            assert.is_false(cliproxy.is_managed())
            parley.config = {}
            assert.is_false(cliproxy.is_managed())
        end)
    end)

    --------------------------------------------------------------------------
    -- discover_binary
    --------------------------------------------------------------------------
    describe("discover_binary", function()
        it("returns binary_path when set and executable", function()
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            assert.equals(FAKE, cliproxy.discover_binary())
        end)

        it("falls back to a cliproxyapi on PATH", function()
            local dir = vim.fn.tempname()
            vim.fn.mkdir(dir, "p")
            local bin = dir .. "/cliproxyapi"
            vim.fn.writefile({ "#!/bin/sh", "true" }, bin)
            uv.fs_chmod(bin, 493) -- 0755
            vim.env.PATH = dir
            parley.config = { cliproxy = { manage = true } }
            assert.equals(bin, cliproxy.discover_binary())
        end)

        it("returns nil when nothing is found", function()
            vim.env.PATH = vim.fn.tempname() -- empty, nonexistent dir
            parley.config = { cliproxy = { manage = true, binary_path = "/no/such/bin" } }
            assert.is_nil(cliproxy.discover_binary())
        end)
    end)

    --------------------------------------------------------------------------
    -- health_probe + classification
    --------------------------------------------------------------------------
    describe("health_probe", function()
        it("classifies a healthy proxy", function()
            local port = free_port()
            start_fake(port, "healthy")
            wait_listening(port)
            local state = await(function(done)
                cliproxy.health_probe("127.0.0.1", port, "k", done)
            end)
            assert.equals("healthy", state)
        end)

        it("classifies needs_login (200 + empty data)", function()
            local port = free_port()
            start_fake(port, "needs_login")
            wait_listening(port)
            local state = await(function(done)
                cliproxy.health_probe("127.0.0.1", port, "k", done)
            end)
            assert.equals("needs_login", state)
        end)

        it("classifies a client key mismatch (401)", function()
            local port = free_port()
            start_fake(port, "client_key_mismatch")
            wait_listening(port)
            local state = await(function(done)
                cliproxy.health_probe("127.0.0.1", port, "k", done)
            end)
            assert.equals("client_key_mismatch", state)
        end)

        it("classifies a foreign server", function()
            local port = free_port()
            start_fake(port, "foreign")
            wait_listening(port)
            local state = await(function(done)
                cliproxy.health_probe("127.0.0.1", port, "k", done)
            end)
            assert.equals("foreign", state)
        end)

        it("classifies down when nothing is listening", function()
            local port = free_port()
            local state = await(function(done)
                cliproxy.health_probe("127.0.0.1", port, "k", done)
            end)
            assert.equals("down", state)
        end)
    end)

    --------------------------------------------------------------------------
    -- spawn
    --------------------------------------------------------------------------
    describe("spawn", function()
        it("starts a detached, PID-tracked process that becomes healthy", function()
            local port = free_port()
            -- a -config file the fake reads its port from
            local cfgfile = vim.fn.tempname() .. ".yaml"
            vim.fn.writefile({ vim.json.encode({ port = port }) }, cfgfile)
            vim.env.PARLEY_FAKE_MODE = "healthy"
            local pid = cliproxy.spawn(FAKE, cfgfile)
            assert.is_truthy(pid)
            assert.is_truthy(vim.tbl_contains(cliproxy.spawned_pids(), pid))
            wait_listening(port)
            local state = await(function(done)
                cliproxy.health_probe("127.0.0.1", port, "k", done)
            end)
            assert.equals("healthy", state)
        end)
    end)

    --------------------------------------------------------------------------
    -- ensure_running — reuse / spawn / failure modes
    --------------------------------------------------------------------------
    describe("ensure_running", function()
        local saved_providers

        local function set_endpoint(port)
            parley.dispatcher = parley.dispatcher or {}
            parley.dispatcher.providers = parley.dispatcher.providers or {}
            parley.dispatcher.providers.cliproxyapi = {
                endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(port),
            }
            require("parley.vault").add_secret("cliproxyapi", "testkey")
        end

        local function run_ensure()
            local outcome
            cliproxy.ensure_running(function()
                outcome = { ok = true }
            end, function(msg)
                outcome = { ok = false, msg = msg }
            end)
            vim.wait(9000, function()
                return outcome ~= nil
            end, 20)
            assert(outcome, "ensure_running never resolved (hang!)")
            return outcome
        end

        before_each(function()
            saved_providers = parley.dispatcher and parley.dispatcher.providers
        end)
        after_each(function()
            if parley.dispatcher then
                parley.dispatcher.providers = saved_providers
            end
        end)

        it("no-op pass-through when not managed", function()
            parley.config = { cliproxy = { manage = false } }
            local outcome = run_ensure()
            assert.is_true(outcome.ok)
        end)

        it("reuses an already-healthy proxy without spawning", function()
            local port = free_port()
            set_endpoint(port)
            start_fake(port, "healthy")
            wait_listening(port)
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            local outcome = run_ensure()
            assert.is_true(outcome.ok)
            assert.equals(0, #cliproxy.spawned_pids()) -- did NOT spawn
        end)

        it("writes the rendered config 0600 with the resolved secret on disk", function()
            local port = free_port()
            set_endpoint(port) -- adds vault secret "testkey"
            start_fake(port, "healthy")
            wait_listening(port)
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            local done
            cliproxy.ensure_running(function() done = true end, function() done = true end)
            vim.wait(9000, function() return done ~= nil end, 20)
            local path = cliproxy._config_path()
            local stat = uv.fs_stat(path)
            assert.is_truthy(stat)
            assert.equals(tonumber("600", 8), require("bit").band(stat.mode, tonumber("777", 8)))
            local content = table.concat(vim.fn.readfile(path), "\n")
            assert.is_truthy(content:find("testkey", 1, true)) -- secret landed on disk
            assert.is_truthy(content:find('"api%-keys"')) -- as the api-keys array
        end)

        it("proceeds on needs_login (up but not logged in)", function()
            local port = free_port()
            set_endpoint(port)
            start_fake(port, "needs_login")
            wait_listening(port)
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            assert.is_true(run_ensure().ok)
        end)

        it("cold-starts: spawns when nothing is listening, then proceeds", function()
            local port = free_port()
            set_endpoint(port)
            vim.env.PARLEY_FAKE_MODE = "healthy"
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            local outcome = run_ensure()
            assert.is_true(outcome.ok)
            assert.is_truthy(#cliproxy.spawned_pids() >= 1) -- it spawned
        end)

        it("errors (no hang) on a foreign process holding the port", function()
            local port = free_port()
            set_endpoint(port)
            start_fake(port, "foreign")
            wait_listening(port)
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            local outcome = run_ensure()
            assert.is_false(outcome.ok)
            assert.is_truthy(outcome.msg:find("non%-cliproxy"))
        end)

        it("errors on a client api-key mismatch", function()
            local port = free_port()
            set_endpoint(port)
            start_fake(port, "client_key_mismatch")
            wait_listening(port)
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            local outcome = run_ensure()
            assert.is_false(outcome.ok)
            assert.is_truthy(outcome.msg:find("api%-key"))
        end)

        it("errors (no hang) when the spawned binary crashes", function()
            local port = free_port()
            set_endpoint(port)
            vim.env.PARLEY_FAKE_MODE = "crash"
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            local outcome = run_ensure()
            assert.is_false(outcome.ok)
            assert.is_truthy(outcome.msg:find("exited"))
        end)

        it("errors (no hang) when the proxy never becomes healthy", function()
            local port = free_port()
            set_endpoint(port)
            vim.env.PARLEY_FAKE_MODE = "slow"
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            local outcome = run_ensure()
            assert.is_false(outcome.ok)
            assert.is_truthy(outcome.msg:find("did not become healthy"))
        end)

        it("errors when no binary is found", function()
            local port = free_port()
            set_endpoint(port)
            -- A PATH with curl (so health_probe can run) but NO cliproxyapi.
            local bindir = vim.fn.tempname()
            vim.fn.mkdir(bindir, "p")
            uv.fs_symlink(vim.fn.exepath("curl"), bindir .. "/curl")
            vim.env.PATH = bindir
            parley.config = { cliproxy = { manage = true, binary_path = "/no/such/bin" } }
            local outcome = run_ensure()
            assert.is_false(outcome.ok)
            assert.is_truthy(outcome.msg:find("no cliproxy binary"))
        end)

        -- The M2 trigger: ensure_running must call download() iff auto_download is
        -- set and nothing else is found (boundary-review Important #1).
        local function path_without_cliproxy()
            -- PATH with curl (health probe) + python3 (the FAKE's interpreter)
            -- but NOT cliproxyapi/cli-proxy-api, so discover_binary finds nothing.
            local bindir = vim.fn.tempname()
            vim.fn.mkdir(bindir, "p")
            uv.fs_symlink(vim.fn.exepath("curl"), bindir .. "/curl")
            uv.fs_symlink(vim.fn.exepath("python3"), bindir .. "/python3")
            vim.env.PATH = bindir
        end

        it("auto_download=true triggers download when no binary is found, then proceeds", function()
            local port = free_port()
            set_endpoint(port)
            path_without_cliproxy()
            vim.env.PARLEY_FAKE_MODE = "healthy"
            parley.config = { cliproxy = { manage = true, auto_download = true, binary_path = "/no/such" } }
            local saved_dl, dl_called = cliproxy.download, false
            cliproxy.download = function() -- stand in for the network fetch; hand back a spawnable binary
                dl_called = true
                return FAKE
            end
            local outcome = run_ensure()
            cliproxy.download = saved_dl
            assert.is_true(dl_called) -- the auto_download branch fired
            assert.is_true(outcome.ok) -- the downloaded binary spawned + became healthy
        end)

        it("does NOT download when auto_download is unset", function()
            local port = free_port()
            set_endpoint(port)
            path_without_cliproxy()
            parley.config = { cliproxy = { manage = true, binary_path = "/no/such" } } -- no auto_download
            local saved_dl, dl_called = cliproxy.download, false
            cliproxy.download = function()
                dl_called = true
                return FAKE
            end
            local outcome = run_ensure()
            cliproxy.download = saved_dl
            assert.is_false(dl_called) -- gate held — no fetch attempted
            assert.is_false(outcome.ok)
            assert.is_truthy(outcome.msg:find("no cliproxy binary"))
        end)
    end)

    --------------------------------------------------------------------------
    -- commands: status / stop / login
    --------------------------------------------------------------------------
    describe("commands", function()
        local function set_endpoint(port)
            parley.dispatcher = parley.dispatcher or {}
            parley.dispatcher.providers = { cliproxyapi = {
                endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(port),
            } }
            require("parley.vault").add_secret("cliproxyapi", "testkey")
        end

        it("stop() kills only parley-spawned proxies and clears tracking", function()
            local port = free_port()
            set_endpoint(port)
            vim.env.PARLEY_FAKE_MODE = "healthy"
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            -- cold-start to spawn one
            local outcome
            cliproxy.ensure_running(function() outcome = true end, function() outcome = false end)
            vim.wait(9000, function() return outcome ~= nil end, 20)
            assert.is_true(outcome)
            assert.is_truthy(#cliproxy.spawned_pids() >= 1)
            local killed = cliproxy.stop()
            assert.is_truthy(killed >= 1)
            assert.equals(0, #cliproxy.spawned_pids())
        end)

        it("stop reaps a leftover cliproxy on the port not spawned this session", function()
            local port = free_port()
            set_endpoint(port)
            start_fake(port, "healthy") -- tracked in `started`, NOT in _spawned
            wait_listening(port)
            assert.equals(0, #cliproxy.spawned_pids()) -- this session spawned nothing
            local n = cliproxy.stop()
            assert.is_truthy(n >= 1) -- reaped the leftover via port identity
            local state = await(function(done)
                cliproxy.health_probe("127.0.0.1", port, "testkey", done)
            end)
            assert.equals("down", state) -- the leftover is dead
        end)

        it("stop does NOT kill a foreign process holding the port", function()
            local port = free_port()
            set_endpoint(port)
            start_fake(port, "foreign") -- not a cliproxy
            wait_listening(port)
            local n = cliproxy.stop()
            assert.equals(0, n) -- nothing reaped — identity probe said "foreign"
            local state = await(function(done)
                cliproxy.health_probe("127.0.0.1", port, "testkey", done)
            end)
            assert.equals("foreign", state) -- still alive
        end)

        it("status() reports health, host:port, binary, and no drift after render", function()
            local port = free_port()
            set_endpoint(port)
            start_fake(port, "healthy")
            wait_listening(port)
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            -- render the config once (so drift can be evaluated)
            local done
            cliproxy.ensure_running(function() done = true end, function() done = true end)
            vim.wait(9000, function() return done ~= nil end, 20)

            local info = await(function(cb)
                cliproxy.status(cb)
            end)
            assert.equals("healthy", info.health)
            assert.equals("127.0.0.1", info.host)
            assert.equals(port, info.port)
            assert.equals(FAKE, info.binary)
            assert.is_true(info.managed)
            assert.is_false(info.config_drift)
        end)

        it("login_argv maps providers to per-provider flags", function()
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            local argv = cliproxy.login_argv("claude")
            assert.equals(FAKE, argv[1])
            assert.equals("-config", argv[2])
            assert.equals("-claude-login", argv[4])
            assert.equals("-login", cliproxy.login_argv("google")[4]) -- google uses -login
            local bad, err = cliproxy.login_argv("bogus")
            assert.is_nil(bad)
            assert.is_truthy(err:find("unknown login provider"))
        end)

        it("login_providers is the single source for completion + validation", function()
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            local provs = cliproxy.login_providers()
            assert.is_truthy(#provs >= 7)
            assert.is_truthy(vim.tbl_contains(provs, "claude"))
            -- every advertised provider must actually build an argv (no drift)
            for _, p in ipairs(provs) do
                assert.is_truthy(cliproxy.login_argv(p), "login_argv failed for " .. p)
            end
        end)
    end)

    --------------------------------------------------------------------------
    -- list_models — GET /v1/models filtered by owned_by
    --------------------------------------------------------------------------
    describe("list_models", function()
        local saved_providers
        local function set_endpoint(port)
            parley.dispatcher = parley.dispatcher or {}
            parley.dispatcher.providers = parley.dispatcher.providers or {}
            parley.dispatcher.providers.cliproxyapi = {
                endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(port),
            }
            require("parley.vault").add_secret("cliproxyapi", "testkey")
        end
        before_each(function()
            saved_providers = parley.dispatcher and parley.dispatcher.providers
        end)
        after_each(function()
            if parley.dispatcher then
                parley.dispatcher.providers = saved_providers
            end
        end)

        it("rejects an unknown provider before touching the proxy", function()
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            local r = await(function(done)
                cliproxy.list_models("bogus", function(ids, err)
                    done({ ids = ids, err = err })
                end)
            end)
            assert.is_nil(r.ids)
            assert.is_truthy(r.err:find("unknown provider"))
            assert.is_truthy(r.err:find("providers")) -- points at the discovery command
        end)

        it("lists only the requested provider's models (filters by owned_by)", function()
            local port = free_port()
            set_endpoint(port)
            start_fake(port, "healthy") -- mixed-owner list (anthropic + openai)
            wait_listening(port)
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            local r = await(function(done)
                cliproxy.list_models("claude", function(ids, err)
                    done({ ids = ids, err = err })
                end)
            end)
            assert.is_nil(r.err)
            assert.same({ "claude-opus-4-8", "claude-sonnet-4-6" }, r.ids)
        end)

        it("discriminates: codex sees only the openai-owned model", function()
            local port = free_port()
            set_endpoint(port)
            start_fake(port, "healthy")
            wait_listening(port)
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            local r = await(function(done)
                cliproxy.list_models("codex", function(ids, err)
                    done({ ids = ids, err = err })
                end)
            end)
            assert.is_nil(r.err)
            assert.same({ "gpt-5-codex" }, r.ids)
        end)

        it("returns an empty list when the provider isn't authenticated", function()
            local port = free_port()
            set_endpoint(port)
            start_fake(port, "needs_login") -- proxy up, no upstream login → empty registry
            wait_listening(port)
            parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
            local r = await(function(done)
                cliproxy.list_models("claude", function(ids, err)
                    done({ ids = ids, err = err })
                end)
            end)
            assert.is_nil(r.err)
            assert.same({}, r.ids) -- command layer turns this into a login prompt
        end)
    end)

    --------------------------------------------------------------------------
    -- management API: credential health (#197)
    --------------------------------------------------------------------------
    describe("auth_files", function()
        local function set_endpoint(port)
            parley.dispatcher = parley.dispatcher or {}
            parley.dispatcher.providers = parley.dispatcher.providers or {}
            parley.dispatcher.providers.cliproxyapi = {
                endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(port),
            }
            require("parley.vault").add_secret("cliproxyapi", "testkey")
        end

        -- A portable credential store: a folder of auth JSONs plus an optional
        -- state.json overlay. Mutating those files between calls is what makes
        -- the fake stateful rather than canned.
        local function write_store(overlay)
            local dir = vim.fn.tempname()
            vim.fn.mkdir(dir, "p")
            vim.fn.writefile({ vim.json.encode({ type = "claude", email = "me@example.com" }) },
                dir .. "/claude-me@example.com.json")
            if overlay then
                vim.fn.writefile({ vim.json.encode(overlay) }, dir .. "/state.json")
            end
            return dir
        end

        -- Start the fake the way the real binary is started: from a rendered
        -- config, so the management key travels the same path in test as in
        -- production.
        local function start_with_config(port, store, mgmt_key)
            local cfg_file = vim.fn.tempname() .. ".json"
            local conf = { port = port, ["auth-dir"] = store, ["api-keys"] = { "testkey" } }
            if mgmt_key then
                conf["remote-management"] = { ["secret-key"] = mgmt_key }
            end
            vim.fn.writefile({ vim.json.encode(conf) }, cfg_file)
            local handle, pid = uv.spawn(FAKE, { args = { "-config", cfg_file } }, function() end)
            assert(handle, "failed to spawn fake_cliproxy")
            table.insert(started, { handle = handle, pid = pid })
            wait_listening(port)
        end

        local function health(channel)
            return await(function(done)
                cliproxy.auth_files(done, channel or "claude")
            end)
        end

        it("reports healthy for an active credential", function()
            local port = free_port()
            set_endpoint(port)
            start_with_config(port, write_store(), cliproxy.management_key())
            local h = health()
            assert.equals("healthy", h.state)
            assert.equals("me@example.com", h.account)
        end)

        it("reports the proxy's own reason for an unavailable credential", function()
            local port = free_port()
            set_endpoint(port)
            start_with_config(port, write_store({
                claude = { unavailable = true, status = "error",
                    status_message = "OAuth access token has expired." },
            }), cliproxy.management_key())
            local h = health()
            assert.equals("unavailable", h.state)
            assert.matches("expired", h.message)
        end)

        it("distinguishes a proxy that predates the management key (404)", function()
            -- The repairable case: cliproxy only registers the management routes
            -- when it BOOTED with a secret-key, so this 404 means "restart me",
            -- not "error".
            local port = free_port()
            set_endpoint(port)
            start_with_config(port, write_store(), nil) -- no key in the config
            local h = health()
            assert.equals("unknown", h.state)
            assert.equals("no_management_route", h.reason)
        end)

        it("distinguishes a rejected management key (401) from a missing route", function()
            local port = free_port()
            set_endpoint(port)
            start_with_config(port, write_store(), "some-other-key")
            local h = health()
            assert.equals("unknown", h.state)
            assert.equals("management_key_mismatch", h.reason)
        end)

        it("distinguishes an unreachable proxy", function()
            set_endpoint(free_port()) -- nothing listening
            local h = health()
            assert.equals("unknown", h.state)
            assert.equals("unreachable", h.reason)
        end)

        it("reports missing when the channel has no credential", function()
            local port = free_port()
            set_endpoint(port)
            start_with_config(port, write_store(), cliproxy.management_key())
            assert.equals("missing", health("codex").state)
        end)
    end)

    --------------------------------------------------------------------------
    -- credential_health: repair a proxy that predates the management key (#197)
    --------------------------------------------------------------------------
    describe("credential_health", function()
        local function set_endpoint(port)
            parley.dispatcher = parley.dispatcher or {}
            parley.dispatcher.providers = parley.dispatcher.providers or {}
            parley.dispatcher.providers.cliproxyapi = {
                endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(port),
            }
            require("parley.vault").add_secret("cliproxyapi", "testkey")
        end

        local function write_store()
            local dir = vim.fn.tempname()
            vim.fn.mkdir(dir, "p")
            vim.fn.writefile({ vim.json.encode({ type = "claude", email = "me@example.com" }) },
                dir .. "/claude-me@example.com.json")
            return dir
        end

        local function start_keyless(port, store)
            local cfg_file = vim.fn.tempname() .. ".json"
            vim.fn.writefile({ vim.json.encode({
                port = port, ["auth-dir"] = store, ["api-keys"] = { "testkey" },
            }) }, cfg_file)
            local handle, pid = uv.spawn(FAKE, { args = { "-config", cfg_file } }, function() end)
            assert(handle, "failed to spawn fake_cliproxy")
            table.insert(started, { handle = handle, pid = pid })
            wait_listening(port)
            return pid
        end

        before_each(function()
            cliproxy._reset_management_restart()
        end)

        it("restarts a keyless proxy once, then reads health from the new one", function()
            local port = free_port()
            local store = write_store()
            set_endpoint(port)
            local old_pid = start_keyless(port, store)
            -- ensure_running must be able to respawn: point it at the fake and
            -- at an auth-dir holding the credential, so the restarted proxy
            -- renders WITH the management key and serves the route.
            parley.config = { cliproxy = { manage = true, binary_path = FAKE, auth_dir = store } }

            local h = await(function(done)
                cliproxy.credential_health(done, "claude")
            end)

            assert.equals("healthy", h.state)
            assert.is_false(vim.tbl_contains(cliproxy.spawned_pids(), old_pid))
        end)

        it("does not restart twice — a persistent 404 is reported, not looped", function()
            local port = free_port()
            local store = write_store()
            set_endpoint(port)
            -- No discoverable binary ⇒ the repair's restart cannot succeed.
            parley.config = { cliproxy = { manage = true, binary_path = "/no/such/bin" } }
            start_keyless(port, store)

            local first = await(function(done) cliproxy.credential_health(done, "claude") end)
            assert.equals("unknown", first.state)

            -- The repair stopped the old proxy and could not start a new one.
            -- Put another keyless proxy back on the port: if the guard did NOT
            -- hold, the second lookup would stop() this one too. Its survival is
            -- the observable proof that the repair ran at most once.
            start_keyless(port, store)
            local second = await(function(done) cliproxy.credential_health(done, "claude") end)

            assert.equals("unknown", second.state)
            assert.equals("no_management_route", second.reason)
            local still_up = await(function(done)
                cliproxy.health_probe("127.0.0.1", port, "testkey", done)
            end)
            assert.equals("healthy", still_up)
        end)

        it("clears the one-shot after a successful lookup so a later restart is repairable", function()
            -- I2: the guard bounds CONSECUTIVE attempts, not the session. An
            -- operator running `brew services restart cliproxyapi` mid-session
            -- must still get a repair.
            local port = free_port()
            local store = write_store()
            set_endpoint(port)
            local old_pid = start_keyless(port, store)
            parley.config = { cliproxy = { manage = true, binary_path = FAKE, auth_dir = store } }

            assert.equals("healthy", await(function(done)
                cliproxy.credential_health(done, "claude")
            end).state)
            assert.is_false(vim.tbl_contains(cliproxy.spawned_pids(), old_pid))

            -- Simulate the operator restarting a keyless proxy underneath us.
            cliproxy.stop()
            local second_pid = start_keyless(port, store)
            local h = await(function(done) cliproxy.credential_health(done, "claude") end)

            assert.equals("healthy", h.state, "the repair did not re-arm after a success")
            assert.is_false(vim.tbl_contains(cliproxy.spawned_pids(), second_pid))
        end)

        it("passes a healthy lookup straight through without restarting", function()
            local port = free_port()
            local store = write_store()
            set_endpoint(port)
            local cfg_file = vim.fn.tempname() .. ".json"
            vim.fn.writefile({ vim.json.encode({
                port = port, ["auth-dir"] = store, ["api-keys"] = { "testkey" },
                ["remote-management"] = { ["secret-key"] = cliproxy.management_key() },
            }) }, cfg_file)
            local handle, pid = uv.spawn(FAKE, { args = { "-config", cfg_file } }, function() end)
            table.insert(started, { handle = handle, pid = pid })
            wait_listening(port)
            parley.config = { cliproxy = { manage = true, binary_path = FAKE, auth_dir = store } }

            local h = await(function(done) cliproxy.credential_health(done, "claude") end)

            assert.equals("healthy", h.state)
            -- reuse-if-healthy must not regress into restart-per-query
            assert.same({}, cliproxy.spawned_pids())
        end)
    end)

    --------------------------------------------------------------------------
    -- management key (#197)
    --------------------------------------------------------------------------
    describe("management_key", function()
        -- These tests repoint the derived-artifact root and (in the reload case)
        -- swap package.loaded. Both are restored: a module-identity swap left
        -- behind is the kind of cross-test leak workshop/lessons.md documents.
        local spec_data_dir

        before_each(function()
            spec_data_dir = vim.fn.tempname()
            cliproxy._set_data_dir(spec_data_dir)
        end)

        after_each(function()
            package.loaded["parley.cliproxy"] = cliproxy
            cliproxy._set_data_dir(SPEC_DATA_DIR)
        end)

        it("generates once, reuses thereafter, and persists 0600", function()
            local a = cliproxy.management_key()
            local b = cliproxy.management_key()
            assert.equals(a, b)
            assert.equals(32, #a)
            assert.matches("^%x+$", a)
            local mode = (uv.fs_stat(cliproxy._management_key_path()) or {}).mode
            assert.equals(tonumber("600", 8), bit.band(mode, tonumber("777", 8)))
        end)

        it("survives a restart — a regenerated key would 401 against the running proxy", function()
            local first = cliproxy.management_key()
            package.loaded["parley.cliproxy"] = nil
            local reloaded = require("parley.cliproxy")
            reloaded._set_data_dir(spec_data_dir)
            assert.equals(first, reloaded.management_key())
        end)
    end)
end)
