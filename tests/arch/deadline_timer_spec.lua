-- #421 (the #382 class): libuv measures a timer from the loop's cached clock,
-- which timer:start does not refresh. A deadline timer armed right after
-- synchronous work therefore already counts that work, and fired at once: a
-- 15 s acquisition deadline expired 0.35 ms after it started, behind 256
-- synchronous directory seeds on a loaded disk. helper.start_deadline refreshes
-- the clock first, so every deadline timer goes through it.
--
-- A deadline timer is a `:start(` whose arguments name a deadline, on its own
-- line or the next one. What it cannot see, stated so it is not mistaken for
-- more: a deadline passed in a variable without "deadline" in its name, and a
-- timer started through an alias. UI debounce and periodic timers are out of
-- scope: a stale clock only makes one of their ticks early.
local arch = require("tests.arch.arch_helper")

local HELPER = "lua/parley/helper.lua"

describe("arch: deadline timers refresh the loop clock", function()
    it("arms every deadline timer through helper.start_deadline", function()
        local offenders = {}
        for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
            if file ~= HELPER then
                local lines = vim.fn.readfile(file)
                for n, line in ipairs(lines) do
                    local call = line:match(":start%((.*)$")
                    if call and not line:match("^%s*%-%-") then
                        local args = (call .. " " .. (lines[n + 1] or "")):lower()
                        if args:find("deadline", 1, true) then
                            offenders[#offenders + 1] = ("%s:%d: %s"):format(file, n, vim.trim(line))
                        end
                    end
                end
            end
        end
        assert.are.same({}, offenders,
            "arm a deadline timer with require('parley.helper').start_deadline, which refreshes the loop clock (#382, #421)")
    end)
end)
