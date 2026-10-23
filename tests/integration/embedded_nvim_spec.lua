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

    it("names the atomic case and last checkpoint before killing a wedged child", function()
        child = Embedded.start()
        Embedded.REQUEST_MS = 1000
        child:begin_case("fold retirement", 500)
        local ok, err = pcall(child.exec, child, [[
            io.stderr:write(string.rep('discarded-prefix ', 800))
            io.stderr:write('\n[stage] restoration/flush last-known-mode=n\n')
            io.stderr:flush()
            while true do end
        ]])
        assert.is_false(ok)
        assert.matches("case=fold retirement", err, 1, true)
        assert.matches("restoration/flush last-known-mode=n", err, 1, true)
        assert.matches("editor=request-pending; current-mode=unknown", err, 1, true)
        assert.matches("elapsed_ms=%d+", err)
        assert.matches("case_budget_ms=500", err, 1, true)
        assert.matches("job_alive_before_kill=true", err, 1, true)
        assert.matches("channel=" .. child.channel, err, 1, true)
        assert.is_true(#err < 6000, "stderr diagnostic is unbounded: " .. #err)
        assert.is_true(vim.wait(require("tests.helpers.arrival").MS, function()
            return vim.fn.jobwait({ child.channel }, 0)[1] ~= -1
        end), "the named case left its wedged child running")
    end)

    it("carries only the residual case budget into the next request", function()
        child = Embedded.start()
        Embedded.REQUEST_MS = 5000
        child:begin_case("shared case budget", 2000)
        assert.equals("first completed", child:exec("vim.wait(1200); return 'first completed'"))
        local ok, err = pcall(child.exec, child, "while true do end")
        assert.is_false(ok)
        assert.matches("case=shared case budget", err, 1, true)
        local request_ms = tonumber(err:match("request_budget_ms=(%d+)"))
        assert.truthy(request_ms, err)
        assert.is_true(request_ms < 1500, "the second request reset its budget: " .. err)
        assert.matches("case_budget_ms=2000", err, 1, true)
    end)

    it("refuses an expired case before sending another child request", function()
        child = Embedded.start()
        child:begin_case("already expired", 1)
        vim.wait(20)
        local ok, err = pcall(child.exec, child, "io.stderr:write('unexpected dispatch'); io.stderr:flush()")
        assert.is_false(ok)
        assert.matches("case=already expired", err, 1, true)
        assert.matches("request-not-sent", err, 1, true)
        vim.wait(20)
        assert.is_nil((child.stderr_tail or ""):find("unexpected dispatch", 1, true))
    end)

    it("preserves successful Lua values inside a named case", function()
        child = Embedded.start()
        child:begin_case("successful case", require("tests.helpers.arrival").MS)
        assert.same({ 3, "x" }, child:exec("local a, b = ... return { a + 1, b }", 2, "x"))
        assert.equals(vim.NIL, child:exec("return nil"))
    end)

    it("cannot restart an active case with a fresh budget", function()
        child = Embedded.start()
        child:begin_case("original deadline", 1000)
        local ok, err = pcall(child.begin_case, child, "replacement deadline", 5000)
        assert.is_false(ok)
        assert.matches("already has a case deadline", err, 1, true)
    end)

    it("fails a request the child never answers, naming it, and kills the child", function()
        child = Embedded.start()
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
