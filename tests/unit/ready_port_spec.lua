-- Tests for tests/helpers/ready_port.lua
--
-- The regression these guard is #202: a fixture's ready file is observable as
-- a zero-byte file before its port digits are flushed, and the old caller read
-- that empty file, got nil, and crashed concatenating it into a URL. Every
-- case below is driven by constructing the signal state directly, so none of
-- them depends on winning a race.

local ready_port = require("tests.helpers.ready_port")

local function scratch(name)
    local dir = vim.fn.tempname() .. "-ready-port"
    vim.fn.mkdir(dir, "p")
    return dir .. "/" .. name
end

local function write(path, content)
    local fh = assert(io.open(path, "w"))
    fh:write(content)
    fh:close()
end

describe("ready_port.wait_for_port", function()
    it("times out by name when the signal file never appears", function()
        local port, err = ready_port.wait_for_port(scratch("absent"), 40)
        assert.is_nil(port)
        assert.truthy(err:find("it never appeared", 1, true))
    end)

    it("does not accept a zero-byte file as a published port", function()
        local path = scratch("empty")
        write(path, "")
        local port, err = ready_port.wait_for_port(path, 40)
        assert.is_nil(port)
        assert.truthy(err:find("it appeared but never published a port", 1, true))
    end)

    it("returns the port when digits land after the file is created empty", function()
        local path = scratch("late")
        write(path, "")
        vim.defer_fn(function() write(path, "54321") end, 30)
        local port, err = ready_port.wait_for_port(path, 2000)
        assert.is_nil(err)
        assert.equals(54321, port)
    end)

    it("tolerates the trailing newline a shell writer would add", function()
        local path = scratch("newline")
        write(path, "8080\n")
        assert.equals(8080, ready_port.wait_for_port(path, 40))
    end)

    it("fails by name on non-numeric content instead of returning nil", function()
        local path = scratch("garbage")
        write(path, "not-a-port")
        local port, err = ready_port.wait_for_port(path, 40)
        assert.is_nil(port)
        assert.truthy(err:find('published "not-a-port"', 1, true))
    end)

    it("rejects a number outside the TCP port range", function()
        local path = scratch("range")
        write(path, "70000")
        local port, err = ready_port.wait_for_port(path, 40)
        assert.is_nil(port)
        assert.truthy(err:find("not a TCP port", 1, true))
    end)
end)

-- #360: a completed TCP handshake is not a listener. Under suite parallelism a
-- probe's source port can be another spec's freed port, and two such probes
-- complete a simultaneous open with nothing listening. The connect is staged
-- here so the case does not depend on winning that race.
describe("ready_port.is_listening", function()
    local uv = vim.uv or vim.loop
    local SEAMS = { "_connect", "_has_listener", "_run_lsof", "_lsof_present" }
    local real = {}
    for _, name in ipairs(SEAMS) do real[name] = ready_port[name] end

    after_each(function()
        for _, name in ipairs(SEAMS) do ready_port[name] = real[name] end
    end)

    it("rejects a connect that completed with nothing listening", function()
        if not ready_port._lsof_present() then
            return pending("needs lsof to confirm the listener")
        end
        local port = ready_port.free_port()
        ready_port._connect = function() return true end
        assert.is_false(ready_port.is_listening(port))
        assert.is_false(ready_port.wait_listening(port, 200))
    end)

    it("accepts a real listener", function()
        local server = uv.new_tcp()
        server:bind("127.0.0.1", 0)
        server:listen(8, function() end)
        local port = server:getsockname().port
        local ok = ready_port.wait_listening(port, 2000)
        server:close()
        assert.is_true(ok)
    end)

    it("never runs lsof while the port still refuses", function()
        local calls = 0
        ready_port._has_listener = function(p) calls = calls + 1; return real._has_listener(p) end
        assert.is_false(ready_port.wait_listening(ready_port.free_port(), 200))
        assert.equals(0, calls)
    end)

    it("lets the connect stand alone where lsof is absent", function()
        ready_port._connect = function() return true end
        ready_port._has_listener = function() return nil end
        ready_port._lsof_present = function() return false end
        assert.is_true(ready_port.is_listening(1))
    end)

    it("treats an lsof that is present but cannot answer as unconfirmed", function()
        ready_port._connect = function() return true end
        ready_port._has_listener = function() return nil end
        ready_port._lsof_present = function() return true end
        assert.is_false(ready_port.is_listening(1))
    end)

    it("require_listening fails by name when the fake never comes up (#361)", function()
        local port = ready_port.free_port()
        local ok, err = pcall(ready_port.require_listening, port, 100)
        assert.is_false(ok)
        assert.truthy(tostring(err):find(("fake never came up on port %d (waited 100ms)"):format(port), 1, true))
    end)

    it("require_listening returns once a real listener is up", function()
        local server = uv.new_tcp()
        server:bind("127.0.0.1", 0)
        server:listen(8, function() end)
        local ok = pcall(ready_port.require_listening, server:getsockname().port, 2000)
        server:close()
        assert.is_true(ok)
    end)

    it("reads each lsof exit shape", function()
        local cases = {
            { res = { code = 0, stdout = "4242\n" }, want = true },
            { res = { code = 0, stdout = "" }, want = false },
            { res = { code = 1, stdout = "" }, want = false },
            { res = { code = 124, stdout = "" }, want = nil }, -- hung past the guard
            { res = { code = 2, stdout = "" }, want = nil },   -- lsof itself failed
            { res = nil, want = nil },                          -- could not run
        }
        for i, c in ipairs(cases) do
            ready_port._run_lsof = function() return c.res end
            assert.equals(c.want, ready_port._has_listener(1), "case " .. i)
        end
    end)
end)
