-- #401: the bounded child-nvim helper answers, and a child that never answers
-- fails its request naming the method, and is killed, instead of stalling the case.
local Embedded = require("tests.helpers.embedded_nvim")
local Runner = require("tests.helpers.spec_runner")
local uv = vim.uv or vim.loop

describe("embedded nvim helper", function()
    local child, saved
    before_each(function() saved = Embedded.REQUEST_MS end)
    after_each(function()
        Embedded.REQUEST_MS = saved
        if child then child:stop() end
    end)

    it("runs Lua in the child and returns its value", function()
        child = Embedded.start({ ui = { 80, 24 } })
        assert.same({ 3, "x" }, child:exec("local a, b = ... return { a + 1, b }", 2, "x"))
    end)

    it("fails a request the child never answers, naming it, and kills the child", function()
        child = Embedded.start()
        local fixture=child:exec("return require('parley.remote_runtime').default_parent()")
        Embedded.REQUEST_MS = 500
        local started = uv.hrtime()
        local ok, err = pcall(child.exec, child, "while true do end")
        local elapsed = (uv.hrtime() - started) / 1e6
        assert.is_false(ok)
        assert.matches(("embedded nvim did not answer nvim_exec_lua within 500 ms; killed pid %d"):format(child.pid), err)
        assert.is_true(elapsed < require("tests.helpers.arrival").MS, elapsed)
        assert.is_true(vim.wait(require("tests.helpers.arrival").MS, function()
            return vim.fn.jobwait({ child.channel }, 0)[1] ~= -1
        end), "the wedged child is still running")
        assert.is_nil(uv.fs_lstat(fixture),'request timeout left its private fixture behind')
    end)

    -- vim.wait counts whole elapsed ms per pass; a handle closed by each request
    -- made every pass return under 1 ms, so a false predicate never timed out (#440).
    it("lets a predicate wait over child requests time out", function()
        child = Embedded.start({ ui = { 80, 24 } })
        local bound, started = 300, uv.hrtime()
        local function wait_for(code)
            assert.is_true(vim.wait(bound, function() -- bound: the timeout is the property under test
                -- A fence, so a wait that never expires fails here instead of stalling the spec.
                if (uv.hrtime() - started) / 1e6 > 10 * bound then error("wait never timed out", 0) end
                return child:exec(code)
            end), code)
        end
        local ok, err = pcall(wait_for, "return false")
        assert.is_false(ok)
        assert.matches("return false", err)
        assert.is_true((uv.hrtime() - started) / 1e6 < 10 * bound, "the wait outlived its bound")
    end)

    it('joins an intentionally killed child before removing its private fixture',function()
        child=Embedded.start()
        local fixture=child:exec("return require('parley.remote_runtime').default_parent()")
        assert(uv.kill(child.pid,'sigkill'))
        child:stop()
        assert.is_nil(uv.fs_lstat(fixture),'stopped child left its private fixture behind')
    end)

    it('retains and names its private fixture when the child exit is not confirmed',function()
        child=Embedded.start()
        local fixture=child:exec("return require('parley.remote_runtime').default_parent()")
        child:exec([[vim.api.nvim_create_autocmd('VimLeavePre',{callback=function() while true do end end})]])
        local jobwait=vim.fn.jobwait
        vim.fn.jobwait=function() return {-1} end
        local ok,err=child:stop()
        vim.fn.jobwait=jobwait
        assert.is_nil(ok)
        assert.is_not_nil(tostring(err):find(fixture,1,true),tostring(err))
        assert.is_not_nil(uv.fs_lstat(fixture))
        assert(uv.kill(child.pid,'sigkill'))
        assert.is_true(child:stop())
        assert.is_nil(uv.fs_lstat(fixture))
    end)

    it('retains a replaced fixture using the identity captured before child actions',function()
        child=Embedded.start()
        local fixture=child:exec("return require('parley.remote_runtime').default_parent()")
        local witness=assert(uv.fs_lstat(fixture))
        assert(uv.kill(child.pid,'sigkill'))
        vim.fn.jobwait({child.channel},1000)
        local original=fixture..'-original'
        assert(uv.fs_rename(fixture,original))
        assert(uv.fs_mkdir(fixture,448))
        vim.fn.writefile({'replacement'},fixture..'/sentinel')
        local ok,err=child:stop()
        assert.is_nil(ok)
        assert.is_not_nil(tostring(err):find(fixture,1,true),tostring(err))
        assert.same({'replacement'},vim.fn.readfile(fixture..'/sentinel'))
        assert.is_true(require('tests.helpers.remote_runtime_fixture').cleanup(original,witness))
        vim.fn.delete(fixture,'rf')
    end)

    it("bounds a request at half the spec's idle budget, which the runner passes", function()
        local saved_env = vim.env.PARLEY_SPEC_IDLE_MS
        vim.env.PARLEY_SPEC_IDLE_MS = "10000"
        local passed = Embedded.request_ms()
        vim.env.PARLEY_SPEC_IDLE_MS = nil
        local default = Embedded.request_ms()
        vim.env.PARLEY_SPEC_IDLE_MS = saved_env
        assert.equals(5000, passed)
        assert.equals(Runner.DEFAULT_TIMEOUT / 2, default)
    end)

    it("stops the child when its setup fails, and raises", function()
        local real_jobstart, channel = vim.fn.jobstart, nil
        vim.fn.jobstart = function(...) channel = real_jobstart(...); return channel end
        local ok, err = pcall(Embedded.start, { ui = { -1, -1 } })
        vim.fn.jobstart = real_jobstart
        assert.is_false(ok)
        assert.truthy(channel, "no child was started")
        assert.is_not_nil(tostring(err):find("width", 1, true), tostring(err))
        assert.is_true(vim.fn.jobwait({ channel }, 0)[1] ~= -1, "the child is still running")
    end)

    -- Through the real runner: a wedged child fails its case naming the request,
    -- not the runner's anonymous idle kill.
    it("names a wedged child before the runner's idle kill", function()
        local root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        local path = root .. "/wedge.lua"
        vim.fn.writefile({
            'local Embedded = require("tests.helpers.embedded_nvim")',
            'describe("wedged child", function() it("spins", function()',
            '    local child = Embedded.start()',
            '    local ok, err = pcall(child.exec, child, "while true do end")',
            '    child:stop()',
            '    assert(ok, err)',
            'end) end)',
        }, path)
        local output = {}
        local result = Runner.execute(path, { base_ms = 20000, load1 = 0, ncpu = 12,
            output = function(_, text) output[#output + 1] = text end })
        vim.fn.delete(root, "rf")
        local text = table.concat(output)
        assert.are_not.equal(0, result.code)
        assert.is_nil(result.reason, text)
        assert.is_nil(text:find("DEADLINE", 1, true), text)
        assert.is_not_nil(text:find("embedded nvim did not answer nvim_exec_lua within 10000 ms", 1, true), text)
    end)
end)
