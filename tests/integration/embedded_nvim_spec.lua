-- #401: the bounded child-nvim helper answers, and a child that never answers
-- fails its request naming the method, and is killed, instead of stalling the case.
local Embedded = require("tests.helpers.embedded_nvim")
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
end)
