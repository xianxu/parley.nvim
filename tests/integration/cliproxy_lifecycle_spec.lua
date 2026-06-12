-- Integration tests for lua/parley/cliproxy.lua (issue #131).
-- Exercises the IO seam against a process-level fake (tests/fixtures/fake_cliproxy),
-- not function mocks (AGENTS.md external-service rule).

local uv = vim.uv or vim.loop

local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

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
    end)
end)
