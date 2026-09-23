-- Exit a harness Neovim when the process that started it is gone (#220).
--
-- The Neovim-side twin of tests/fixtures/fixture_watchdog.py; the RULE below is
-- stated identically in both, and tests/arch/fixture_lifecycle_spec.lua holds them
-- to it.
--
-- `nvim --headless` treats SIGINT as an interrupt, not as an exit, so a Ctrl-C'd
-- or killed `make` leaves the parent AND every plenary spec child running. They
-- reparent to init and sit idle forever: #220 measured 145 of them, ~1.2 GB, some
-- two days old, every one having burned 0.05s of CPU — wedged at startup, never
-- having run a spec.
local uv = vim.uv or vim.loop

local M = {}

--- The rule: a process is orphaned when its parent is init, OR when its parent
--- changed. The `== 1` half is load-bearing and not redundant — a process orphaned
--- while it is still BOOTING samples 1 as its own starting parent, so a rule that
--- only watches for a change never fires for exactly the case that produces these.
--- Measured: a fixture orphaned during startup survived indefinitely under the
--- change-only rule and exited in under a second under this one.
function M.orphaned(parent, ppid)
    return ppid == 1 or ppid ~= parent
end

--- Start watching. Returns the timer, for tests.
---
--- os.exit, not `qa!`: the callback runs in a fast-event context and must not
--- depend on a main loop that may be wedged. That skips VimLeavePre, so this
--- does NOT reap child fixtures — they carry the same watchdog and reap
--- themselves within one poll of being reparented.
---
--- Skipping VimLeavePre also skips whatever cleanup lives there, so a caller with
--- durable state passes it as `before_exit`: it runs (pcall'd) on this path too.
--- tests/minimal_init.vim uses it for the per-process $PARLEY_QUERY_DIR, which
--- #261 M5 found would otherwise accumulate one directory per spec process.
---@param poll_ms integer|nil
---@param before_exit fun()|nil
function M.install(poll_ms, before_exit)
    poll_ms = poll_ms or 1000
    local parent = uv.os_getppid()
    local timer = uv.new_timer()
    timer:unref() -- never keeps the loop alive, never delays a normal exit
    timer:start(poll_ms, poll_ms, function()
        if M.orphaned(parent, uv.os_getppid()) then
            if before_exit then
                local ok, err = pcall(before_exit)
                if not ok then io.stderr:write("test watchdog cleanup failed: " .. tostring(err) .. "\n") end
            end
            os.exit(1)
        end
    end)
    return timer
end

return M
