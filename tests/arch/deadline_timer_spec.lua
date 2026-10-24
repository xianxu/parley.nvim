-- #421 (the #382 class): libuv measures a timer from the loop's cached clock,
-- which timer:start does not refresh. A deadline timer armed right after
-- synchronous work therefore already counts that work, and fired at once: a
-- 15 s acquisition deadline expired 0.35 ms after it started, behind 256
-- synchronous directory seeds on a loaded disk. helper.start_deadline (and
-- helper.defer_deadline) refresh the clock first, so every deadline timer goes
-- through them; an absolute hrtime deadline goes through
-- helper.start_absolute_deadline, which computes the remaining time once.
--
-- A deadline timer is a `:start(`, `vim.defer_fn(` or `timer_start(` whose
-- arguments name a deadline, on its own line or the next one. A hand-rolled
-- remaining time is `start_deadline(` with a `math.ceil(` in its arguments.
-- What it cannot see, stated so it is not mistaken for more: a deadline passed
-- in a variable without "deadline" in its name, a timer started through an
-- alias, and a remaining time computed on an earlier line (tasker.lua's
-- reconcile delay, on an injected clock, is one). UI debounce and periodic
-- timers are out of scope: a stale clock only makes one of their ticks early.
--
-- #431: vim.system arms its `timeout` the same raw way, right after the spawn,
-- so a call that passes one goes through helper.system. A raw vim.system is a
-- timeout call when a `timeout =` field appears on its line, the line before
-- (an options table built there) or the next three (a multi-line table). A
-- call forwarding an options variable counts too, since the caller's table
-- may carry a timeout. It cannot see a timeout set further away for a literal
-- table, or vim.system reached through an alias.
local arch = require("tests.arch.arch_helper")

local HELPER = "lua/parley/helper.lua"
local STARTS = { ":start%((.*)$", "vim%.defer_fn%((.*)$", "timer_start%((.*)$" }

local function scan(visit)
    for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
        if file ~= HELPER then
            local lines = vim.fn.readfile(file)
            for n, line in ipairs(lines) do
                if not line:match("^%s*%-%-") then
                    visit(file, n, line, lines[n + 1] or "", lines)
                end
            end
        end
    end
end

describe("arch: deadline timers refresh the loop clock", function()
    it("arms every deadline timer through helper.start_deadline", function()
        local offenders = {}
        scan(function(file, n, line, following)
            for _, start in ipairs(STARTS) do
                local call = line:match(start)
                if call and (call .. " " .. following):lower():find("deadline", 1, true) then
                    offenders[#offenders + 1] = ("%s:%d: %s"):format(file, n, vim.trim(line))
                    return
                end
            end
        end)
        assert.are.same({}, offenders,
            "arm a deadline timer with require('parley.helper').start_deadline, which refreshes the loop clock (#382, #421)")
    end)
    it("leaves an absolute deadline's remaining time to helper.start_absolute_deadline", function()
        local offenders = {}
        scan(function(file, n, line, following)
            local call = line:match("start_deadline%((.*)$")
            if call and (call .. " " .. following):find("math.ceil(", 1, true) then
                offenders[#offenders + 1] = ("%s:%d: %s"):format(file, n, vim.trim(line))
            end
        end)
        assert.are.same({}, offenders,
            "pass the absolute deadline to require('parley.helper').start_absolute_deadline (#421)")
    end)
    it("passes a vim.system timeout through helper.system", function()
        local offenders = {}
        scan(function(file, n, line, _, lines)
            if line:match("vim%.system%s*[%(,]") then
                local window = table.concat({ lines[n - 1] or "", line, lines[n + 1] or "",
                    lines[n + 2] or "", lines[n + 3] or "" }, " ")
                local forwarded = line:match("vim%.system%s*%(%s*[%w_]+%s*,%s*[%w_]+%s*[,%)]")
                    or line:match("vim%.system%s*,%s*[%w_]+%s*,%s*[%w_]+%s*[,%)]")
                if forwarded or window:match("timeout%s*=") then
                    offenders[#offenders + 1] = ("%s:%d: %s"):format(file, n, vim.trim(line))
                end
            end
        end)
        assert.are.same({}, offenders,
            "spawn a child with a timeout through require('parley.helper').system, which refreshes the loop clock (#431)")
    end)
end)
