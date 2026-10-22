-- #416: generic embedded argv is no ownership proof. Retained birth evidence
-- must independently prevent a terminal false clean after the launcher exits.
local uv = vim.uv or vim.loop
local Identity = require("tests.helpers.process_identity")
local Runner = require("tests.helpers.spec_runner")
local ROOT = vim.fn.getcwd()
local arrival = require("tests.helpers.arrival")

describe("retained embedded child census", function()
    local root, children, launchers
    before_each(function()
        root, children, launchers = vim.fn.tempname(), {}, {}
        vim.fn.mkdir(root, "p")
    end)
    after_each(function()
        for _, launcher in ipairs(launchers) do launcher:kill("sigkill"); launcher:wait(3000) end
        for _, child in ipairs(children) do
            if Identity.start_time(child.pid) == child.start then uv.kill(child.pid, "sigkill") end
            vim.wait(arrival.MS, function() return Identity.start_time(child.pid) ~= child.start end, 10)
        end
        vim.fn.delete(root, "rf")
    end)

    local function birth(path)
        assert.is_true(vim.wait(arrival.MS, function() return vim.fn.filereadable(path) == 1 end, 10))
        local value = vim.fn.readfile(path)
        local child = { pid = tonumber(value[1]), start = value[2] }
        children[#children + 1] = child
        return child
    end

    local function spinner(path, ready)
        return {
            'local child = require("tests.helpers.embedded_nvim").start({ detach = true })',
            'vim.fn.writefile({ tostring(child.pid), require("tests.helpers.process_identity").start_time(child.pid) }, ' .. vim.inspect(path) .. ')',
            'child:notify("nvim_exec_lua", ' .. vim.inspect('vim.fn.writefile({"ready"}, ' .. vim.inspect(ready) .. '); while true do end') .. ', {})',
            'assert(vim.wait(10000, function() return vim.fn.filereadable(' .. vim.inspect(ready) .. ') == 1 end, 10))',
        }
    end

    it("retains unknown when the launcher dies inside birth publication", function()
        local ledger = root .. "/.test-processes/interrupted/spec"
        vim.fn.mkdir(ledger, "p")
        local path, pidfile = root .. "/interrupted.lua", root .. "/birth"
        vim.fn.writefile({
            'package.path = ' .. vim.inspect(ROOT .. '/?.lua;') .. ' .. package.path',
            'local P = require("tests.helpers.test_processes")',
            'P.complete = function(_, pid)',
            '  vim.fn.writefile({ tostring(pid), require("tests.helpers.process_identity").start_time(pid) }, ' .. vim.inspect(pidfile) .. ')',
            '  vim.wait(600000, function() return false end, 10)',
            'end',
            'require("tests.helpers.spec_jobs").install()',
            'require("tests.helpers.embedded_nvim").start({detach=true})',
        }, path)
        local owner = vim.system({ vim.v.progpath, "--clean", "--headless", "-l", path }, {
            env = { PARLEY_SPEC_JOBS_DIR = ledger }, text = true,
        })
        launchers[#launchers + 1] = owner
        birth(pidfile)
        owner:kill("sigkill"); owner:wait(3000)
        launchers[#launchers] = nil -- joined handles never authorize a later PID signal
        local before = table.concat(vim.fn.readfile(ledger .. "/1.json"), "\n")
        local out = vim.system({ "python3", ROOT .. "/scripts/reap-test-orphans.py", "--root", root,
            "--phase", "after", "--grace", "0" }, { text = true }):wait(10000)
        assert.are_not.equal(0, out.code, out.stdout .. out.stderr)
        assert.is_nil(out.stdout:find("clean:", 1, true))
        assert.matches("unknown", out.stdout)
        assert.equals(before, table.concat(vim.fn.readfile(ledger .. "/1.json"), "\n"))
    end)

    it("installs one job owner and preserves on_exit for children already reaped at publication", function()
        local ledger, launcher = root .. "/jobs", root .. "/callbacks.lua"
        vim.fn.mkdir(ledger, "p")
        vim.fn.writefile({
            'package.path = ' .. vim.inspect(ROOT .. '/?.lua;') .. ' .. package.path',
            'local Jobs = require("tests.helpers.spec_jobs")',
            'Jobs.install(); Jobs.install()',
            'local I = require("tests.helpers.process_identity"); local observe = I.observe',
            'I.observe = function(pid) vim.wait(100, function() return false end, 10); return observe(pid) end',
            'local calls = 0',
            'local job = vim.fn.jobstart({vim.v.progpath, "--clean", "--headless", "-c", "qa!"}, {on_exit=function() calls=calls+1 end})',
            'vim.fn.jobwait({job}, 3000)',
            'assert(calls == 1, "on_exit called " .. calls .. " times")',
            'local rows = assert(require("tests.helpers.test_processes").read(' .. vim.inspect(ledger) .. '))',
            'assert(#rows <= 1, "duplicate job birth records: " .. #rows)',
        }, launcher)
        local out = vim.system({ vim.v.progpath, "--clean", "--headless", "-l", launcher }, {
            env = { PARLEY_SPEC_JOBS_DIR = ledger }, text = true,
        }):wait(10000)
        assert.equals(0, out.code, out.stdout .. out.stderr)
    end)

    it("records jobs from clean embedded children that never load minimal_init", function()
        local pidfile, ready, spec = root .. "/birth", root .. "/ready", root .. "/grandchild.lua"
        local code = table.concat(spinner(pidfile, ready), "\n")
        vim.fn.writefile({
            'describe("clean embedded descendant", function() it("returns", function()',
            'local child = require("tests.helpers.embedded_nvim").start()',
            'child:exec(' .. vim.inspect(code) .. ')',
            'child:stop()',
            'end) end)',
        }, spec)
        local result = Runner.execute(spec, { base_ms = 20000, load1 = 0, ncpu = 12, output = function() end })
        local child = birth(pidfile)
        assert.are_not.equal(0, result.code)
        assert.is_true(vim.wait(arrival.MS, function() return Identity.start_time(child.pid) ~= child.start end, 10))
    end)

    it("cannot call an ordinary spec exit reaped while its recorded child lives", function()
        local pidfile, ready, spec = root .. "/birth", root .. "/ready", root .. "/leak.lua"
        local lines = { 'describe("ordinary leak", function() it("returns", function()' }
        vim.list_extend(lines, spinner(pidfile, ready))
        lines[#lines + 1] = 'end) end)'
        vim.fn.writefile(lines, spec)
        local output = {}
        local result = Runner.execute(spec, { base_ms = 20000, load1 = 0, ncpu = 12,
            output = function(_, text) output[#output + 1] = text end })
        local child = birth(pidfile)
        assert.are_not.equal(0, result.code, table.concat(output))
        assert.is_true(vim.wait(arrival.MS, function()
            return Identity.start_time(child.pid) ~= child.start
        end, 10), "ordinary completion left its embedded child alive")
    end)

    it("the independent terminal census detects and joins a TERM-resistant orphan", function()
        local ledger = root .. "/.test-processes/legacy/spec"
        vim.fn.mkdir(ledger, "p")
        local pidfile, ready, launcher = root .. "/birth", root .. "/ready", root .. "/launcher.lua"
        local foreign_file, foreign_ready = root .. "/foreign", root .. "/foreign-ready"
        local lines = {
            'package.path = ' .. vim.inspect(ROOT .. '/?.lua;' .. ROOT .. '/lua/?.lua;') .. ' .. package.path',
        }
        -- Same argv, same cwd, same launcher; no recorded ownership of this one.
        vim.list_extend(lines, spinner(foreign_file, foreign_ready))
        lines[#lines + 1] = 'require("tests.helpers.spec_jobs").install()'
        vim.list_extend(lines, spinner(pidfile, ready))
        lines[#lines + 1] = 'vim.cmd("qa!")'
        vim.fn.writefile(lines, launcher)
        local launched = vim.system({ vim.v.progpath, "--clean", "--headless", "-l", launcher }, {
            env = { PARLEY_SPEC_JOBS_DIR = ledger }, text = true,
        }):wait(20000)
        local child = birth(pidfile)
        local foreign = birth(foreign_file)
        assert.equals(0, launched.code, launched.stderr)
        assert.equals(child.start, Identity.start_time(child.pid), "probe did not survive its launcher")
        uv.kill(child.pid, "sigterm")
        vim.wait(50, function() return false end, 10)
        assert.equals(child.start, Identity.start_time(child.pid), "probe did not resist TERM")
        local table_file = root .. "/ps.txt"
        local table_out = vim.system({ "ps", "-Ao", "pid=,ppid=,args=" }, { text = true }):wait(3000)
        assert.equals(0, table_out.code)
        vim.fn.writefile(vim.split(table_out.stdout, "\n"), table_file)
        local snapshot = vim.system({ "python3", ROOT .. "/scripts/reap-test-orphans.py", "--root", root,
            "--phase", "after", "--ps-from", table_file, "--self-pid", tostring(vim.fn.getpid()) },
            { text = true }):wait(10000)
        assert.are_not.equal(0, snapshot.code, snapshot.stdout .. snapshot.stderr)
        assert.equals(child.start, Identity.start_time(child.pid), "snapshot mode signalled the child")
        local out = vim.system({ "python3", ROOT .. "/scripts/reap-test-orphans.py", "--root", root,
            "--phase", "after", "--grace", "0" }, { text = true }):wait(20000)
        assert.are_not.equal(0, out.code, out.stdout .. out.stderr)
        assert.is_nil(out.stdout:find("clean:", 1, true), out.stdout)
        assert.is_true(vim.wait(arrival.MS, function()
            return Identity.start_time(child.pid) ~= child.start
        end, 10), "terminal census sent a signal without joining death")
        assert.equals(foreign.start, Identity.start_time(foreign.pid), "census touched same-argv unrecorded child")
        local next_out = vim.system({ "python3", ROOT .. "/scripts/reap-test-orphans.py", "--root", root,
            "--phase", "after", "--grace", "0" }, { text = true }):wait(20000)
        assert.equals(0, next_out.code, next_out.stdout .. next_out.stderr)
    end)
end)
