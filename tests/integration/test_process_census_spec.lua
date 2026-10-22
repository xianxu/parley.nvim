-- #416: generic embedded argv is no ownership proof. Retained birth evidence
-- must independently prevent a terminal false clean after the launcher exits.
local uv = vim.uv or vim.loop
local Identity = require("tests.helpers.process_identity")
local Runner = require("tests.helpers.spec_runner")
local ROOT = vim.fn.getcwd()
local arrival = require("tests.helpers.arrival")

describe("retained embedded child census", function()
    local root, children
    before_each(function()
        root, children = vim.fn.tempname(), {}
        vim.fn.mkdir(root, "p")
    end)
    after_each(function()
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
            'local channel = vim.fn.jobstart({ vim.v.progpath, "--clean", "--embed", "--headless", "-i", "NONE" }, { rpc = true, detach = true })',
            'assert(channel > 0); local child = { channel = channel, pid = vim.fn.jobpid(channel) }',
            'vim.fn.writefile({ tostring(child.pid), require("tests.helpers.process_identity").start_time(child.pid) }, ' .. vim.inspect(path) .. ')',
            'vim.rpcnotify(child.channel, "nvim_exec_lua", ' .. vim.inspect('vim.fn.writefile({"ready"}, ' .. vim.inspect(ready) .. '); while true do end') .. ', {})',
            'assert(vim.wait(10000, function() return vim.fn.filereadable(' .. vim.inspect(ready) .. ') == 1 end, 10))',
        }
    end

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
        local lines = {
            'package.path = ' .. vim.inspect(ROOT .. '/?.lua;' .. ROOT .. '/lua/?.lua;') .. ' .. package.path',
            'require("tests.helpers.spec_jobs").install()',
        }
        vim.list_extend(lines, spinner(pidfile, ready))
        lines[#lines + 1] = 'vim.cmd("qa!")'
        vim.fn.writefile(lines, launcher)
        local launched = vim.system({ vim.v.progpath, "--clean", "--headless", "-l", launcher }, {
            env = { PARLEY_SPEC_JOBS_DIR = ledger }, text = true,
        }):wait(20000)
        local child = birth(pidfile)
        assert.equals(0, launched.code, launched.stderr)
        assert.equals(child.start, Identity.start_time(child.pid), "probe did not survive its launcher")
        uv.kill(child.pid, "sigterm")
        vim.wait(50, function() return false end, 10)
        assert.equals(child.start, Identity.start_time(child.pid), "probe did not resist TERM")
        local out = vim.system({ "python3", ROOT .. "/scripts/reap-test-orphans.py", "--root", root,
            "--phase", "after", "--grace", "0" }, { text = true }):wait(20000)
        assert.are_not.equal(0, out.code, out.stdout .. out.stderr)
        assert.is_nil(out.stdout:find("clean:", 1, true), out.stdout)
        assert.is_true(vim.wait(arrival.MS, function()
            return Identity.start_time(child.pid) ~= child.start
        end, 10), "terminal census sent a signal without joining death")
        local next_out = vim.system({ "python3", ROOT .. "/scripts/reap-test-orphans.py", "--root", root,
            "--phase", "after", "--grace", "0" }, { text = true }):wait(20000)
        assert.equals(0, next_out.code, next_out.stdout .. next_out.stderr)
    end)
end)
