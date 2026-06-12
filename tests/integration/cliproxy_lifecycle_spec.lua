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
        for _, p in ipairs(started) do
            pcall(function()
                if p.handle and not p.handle:is_closing() then
                    uv.kill(p.pid, "sigkill")
                end
            end)
        end
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
end)
