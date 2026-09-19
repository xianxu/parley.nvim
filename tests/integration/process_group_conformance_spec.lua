-- #261 M3 live conformance: real processes, real signals, no fake. The process
-- fake (tests/helpers/fake_process.lua) models groups; these cases check the
-- model against the kernel — a scoped run leads its own group, and a stop of
-- its scope reaches a grandchild that ignores TERM and holds the pipe.
local T = require("parley.tasker")
local uv = vim.uv or vim.loop

local function gone(pid)
    local ok = uv.kill(pid, 0)
    return ok ~= 0
end

describe("process groups, live", function()
    before_each(function() T._reset(); T._uv = nil end)
    after_each(function()
        T.leave()
        vim.wait(3000, function() return T.stats().active == 0 end, 10)
        T._reset()
    end)
    local function sh(script, scope, on_out)
        local done
        T.run(nil, "sh", { "-c", script }, function(code, signal, out, err, io_error)
            done = { code = code, signal = signal, out = out, err = err, io_error = io_error }
        end, on_out, nil, nil, { attempt_id = "conformance:" .. scope, generation_id = scope, logical_generation = scope })
        return function() return done end
    end

    it("a scoped run leads its own process group", function()
        if vim.fn.executable("sh") == 0 then return pending("sh is not executable") end
        local result = sh("kill -0 -- -$$ && echo leader", "e:1")
        assert.is_true(vim.wait(5000, function() return result() ~= nil end, 10))
        assert.equals(0, result().code, result().err)
        assert.equals("leader", vim.trim(result().out))
    end)

    it("a stop reaches a grandchild that ignores TERM and holds the pipe", function()
        if vim.fn.executable("sh") == 0 then return pending("sh is not executable") end
        local grandchild
        local result = sh('trap "" TERM; sleep 30 & echo $!; wait', "e:2", function(_, data)
            if data and not grandchild then grandchild = tonumber(data:match("%d+")) end
        end)
        assert.is_true(vim.wait(5000, function() return grandchild ~= nil end, 10))
        local stopped = uv.hrtime()
        assert.equals(1, T.stop_scope("e:2"))
        assert.is_true(vim.wait(4000, function() return result() ~= nil end, 10), "the record did not resolve")
        assert.is_true((uv.hrtime() - stopped) / 1e6 < 4000)
        assert.is_nil(result().code)
        assert.equals("killed: stop", result().io_error)
        assert.is_true(vim.wait(1000, function() return gone(grandchild) end, 10), "the grandchild survived")
    end)

    it("a stop reaches a tool through the real spawn path", function()
        if vim.fn.executable("find") == 0 then return pending("find is not executable") end
        local A = require("parley.tools.path_authority")
        local result
        local context = { tasker = T, cwd = "/", logical_generation = "e:3", operation_id = "conformance-find",
            authority = assert(A.capture({ "/" })) }
        require("parley.tools.builtin.find").execute_async({ path = "/" }, context, function(value) result = value end)
        local pid
        assert.is_true(vim.wait(5000, function()
            for _, state in ipairs(T._handles) do if state.pid then pid = state.pid end end
            return pid ~= nil
        end, 10))
        assert.is_true(T.get_attempt(T._handles[1].attempt_id).group, "a tool process is scoped")
        assert.equals(1, T.stop_scope("e:3"))
        assert.is_true(vim.wait(4000, function() return result ~= nil end, 10), "the tool did not settle")
        assert.is_true(result.physical_resolved)
        assert.is_true(vim.wait(1000, function() return gone(pid) end, 10))
    end)
end)
