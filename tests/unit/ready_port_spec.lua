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
