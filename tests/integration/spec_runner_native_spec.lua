local Runner = require("tests.helpers.spec_runner")

describe("owned headless spec execution", function()
    local root
    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
    end)
    after_each(function() vim.fn.delete(root, "rf") end)

    local function run(lines, options)
        local path = root .. "/fixture.lua"
        vim.fn.writefile(lines, path)
        local output = {}
        options = vim.tbl_extend("force", { load1 = 0, ncpu = 12 }, options or {}, {
            output = function(stream, text) output[#output + 1] = stream .. ":" .. text end,
        })
        assert.is_function(Runner.execute)
        local result = Runner.execute(path, options)
        return result, table.concat(output)
    end

    it("executes real Plenary assertions and preserves ordinary output", function()
        local result, output = run({
            'describe("real child", function()',
            'it("passes", function() print("ordinary output"); assert.equals(2, 1 + 1) end)',
            'end)',
        })
        assert.equals(0, result.code)
        assert.equals(1, result.completed)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
        assert.matches("ordinary output", output, 1, true)
        assert.matches("Success", output, 1, true)
        assert.is_nil(output:find("PARLEY_CASE_", 1, true))
    end)

    it("retains an actual failed assertion and nonzero exit", function()
        local result, output = run({
            'describe("real child", function()',
            'it("fails", function() assert.equals("expected", "actual") end)',
            'end)',
        })
        assert.is_true(result.code ~= 0)
        assert.equals(1, result.completed)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
        assert.matches("actual", output, 1, true)
        assert.matches("Fail", output, 1, true)
    end)

    it("kills and reaps a stalled case after completed work", function()
        local result = run({
            'describe("real child", function()',
            'it("first", function() assert.is_true(true) end)',
            'it("stalled", function() vim.wait(15000, function() return false end, 10) end)',
            'end)',
        }, { base_ms = 1000 })
        assert.equals(124, result.code)
        assert.equals("stalled", result.reason)
        assert.equals(1, result.completed)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
    end)

    -- #446: a file that keeps completing cases runs past base x4 and passes.
    it("lets a file run past four idle budgets while its cases keep completing", function()
        local started = vim.uv.hrtime()
        local result = run({
            'describe("real child", function()',
            'for i = 1, 20 do it("progress " .. i, function() vim.wait(250, function() return false end, 10) end) end',
            'end)',
        }, { base_ms = 1000 }) -- base: each case leaves 750 ms of its budget for overhead under load
        assert.is_true((vim.uv.hrtime() - started) / 1e6 > 4 * 1000, "the file did not outlast four budgets")
        assert.equals(0, result.code)
        assert.is_nil(result.reason)
        assert.equals(20, result.completed)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
    end)

    it("does not let arbitrary bootstrap output keep a child alive", function()
        local result, output = run({
            'local timer = vim.uv.new_timer()',
            'timer:start(0, 50, function() io.stdout:write("Success || arbitrary output\\n"); io.stdout:flush() end)',
            'vim.wait(15000, function() return false end, 10)',
        }, { base_ms = 1000 })
        assert.equals(124, result.code)
        assert.equals("stalled", result.reason)
        assert.equals(0, result.completed)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
        assert.matches("arbitrary output", output, 1, true)
    end)

    it("still kills a stuck bootstrap at controlled capped load", function()
        local result = run({
            'vim.wait(15000, function() return false end, 10)',
        }, { base_ms = 250, load1 = 100000, ncpu = 12 })
        assert.equals(124, result.code)
        assert.equals("stalled", result.reason)
        assert.equals(0, result.completed)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
    end)

    it("includes after_each teardown in a case's progress boundary", function()
        local result, output = run({
            'describe("real child", function()',
            'after_each(function() vim.wait(15000, function() return false end, 10) end)',
            'it("body", function() io.stdout:write("BODY COMPLETED\\n"); io.stdout:flush() end)',
            'end)',
        }, { base_ms = 1000 })
        assert.equals(124, result.code)
        assert.equals("stalled", result.reason)
        assert.equals(0, result.completed)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
        assert.matches("BODY COMPLETED", output, 1, true)
    end)

    -- #402: everything a spec started dies with it. Each fixture spins an
    -- embedded nvim that only the runner can end (a spinning nvim ignores
    -- SIGTERM); each case SIGKILLs any survivor itself, so a red run leaves none.
    local function spinner(pidfile)
        return {
            'local Embedded = require("tests.helpers.embedded_nvim")',
            'describe("orphan", function() it("spins", function()',
            '    Embedded.REQUEST_MS = 600000',
            '    local child = Embedded.start()',
            '    vim.fn.writefile({ tostring(child.pid) }, ' .. vim.inspect(pidfile) .. ')',
            '    child:exec("while true do end")',
            'end) end)',
        }
    end
    local function alive(pid) return pid ~= nil and select(3, vim.uv.kill(pid, 0)) == nil end
    local function embedded_pid(pidfile)
        assert.is_true(vim.wait(require("tests.helpers.arrival").MS,
            function() return vim.fn.filereadable(pidfile) == 1 end, 20), "the fixture never started its embedded nvim")
        return tonumber(vim.fn.readfile(pidfile)[1])
    end
    local function gone(pid)
        local ended = vim.wait(require("tests.helpers.arrival").MS, function() return not alive(pid) end, 20)
        if not ended then vim.uv.kill(pid, "sigkill") end -- never leave a spinner behind
        return ended
    end

    it("ends the spec's whole process group at the idle deadline", function()
        local pidfile = root .. "/pid"
        local result = run(spinner(pidfile), { base_ms = 3000 })
        local pid = embedded_pid(pidfile)
        assert.equals("stalled", result.reason)
        assert.is_true(gone(pid), "embedded nvim " .. pid .. " outlived the idle kill")
    end)

    -- A vim.system grandchild isn't a job: only the spec child's own process
    -- group (detach) reaches it.
    it("ends a spec's vim.system grandchild at the idle deadline", function()
        local pidfile = root .. "/pid"
        local result = run({
            'describe("orphan", function() it("hangs", function()',
            '    local sleeper = vim.system({ "sleep", "600" })',
            '    vim.fn.writefile({ tostring(sleeper.pid) }, ' .. vim.inspect(pidfile) .. ')',
            '    vim.wait(600000, function() return false end, 50)',
            'end) end)',
        }, { base_ms = 3000 })
        local pid = embedded_pid(pidfile)
        assert.equals("stalled", result.reason)
        assert.is_true(gone(pid), "vim.system grandchild " .. pid .. " outlived the idle kill")
    end)

    for _, signal in ipairs({ "sigterm", "sigint" }) do
        it("takes its spec's process group with it when the runner gets " .. signal, function()
            local pidfile, path = root .. "/pid", root .. "/fixture.lua"
            vim.fn.writefile(spinner(pidfile), path)
            local runner = vim.system({ vim.v.progpath, "--headless", "--noplugin", "-n", "-i", "NONE",
                "-u", "tests/minimal_init.vim", "-c",
                ("lua require('tests.helpers.spec_runner').execute(%q, { base_ms = 600000, output = function() end })")
                    :format(path), "-c", "qa!" })
            local pid = embedded_pid(pidfile)
            vim.uv.kill(runner.pid, signal)
            local exited = runner:wait(require("tests.helpers.arrival").MS)
            assert.is_true(gone(pid), "embedded nvim " .. pid .. " outlived its runner's " .. signal)
            assert.is_not_nil(exited.code)
        end)
    end

    it("signals no recorded job whose pid now names another process", function()
        local Jobs = require("tests.helpers.spec_jobs")
        local live = vim.system({ "sleep", "30" })
        vim.fn.writefile({ live.pid .. " 1.000000" }, root .. "/jobs") -- a start time it never had
        local logged = {}
        Jobs.signal(root, "sigkill", function(message) logged[#logged + 1] = message end)
        local survived = alive(live.pid)
        live:kill(9)
        live:wait()
        assert.is_true(survived, "a mismatched record was signalled")
        assert.equals(1, #logged)
        assert.matches("spec job not signalled: pid " .. live.pid .. " reused", logged[1])
    end)
end)
