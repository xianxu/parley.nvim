-- #294: what a slow spec child's LuaJIT is doing. Enabled by
-- PARLEY_TEST_JITSTAT=1 (tests/minimal_init.vim). A child killed at its
-- deadline runs no exit hook, and a long synchronous spec never yields to a
-- libuv timer, so the periodic line is written from the profiler callback,
-- which runs inside the VM. VM states (jit.profile): N compiled, I interpreted,
-- C C code, G GC, J JIT compiler. `flush` counts trace-cache flushes: the
-- mcode-exhaustion thrash #293 measured shows as hundreds of them.
-- PARLEY_TEST_JITSTAT_LOG names a file to append to instead of stderr, so a
-- grandchild nvim a spec starts with vim.fn.system still reaches make's output.
local M = {}
local profile_running = false

-- Resolved at install: the profiler callback can run inside a libuv callback
-- (a fast event), where Neovim 0.12 panics on any `vim.env` read.
local log_path

local function emit(line)
    local path = log_path
    if not path or path == "" then return io.stderr:write(line) end
    local f = io.open(path, "a")
    if f then f:write(line); f:close() end
end

local function summary(start, flushes, samples)
    local total, parts = 0, {}
    for _, n in pairs(samples) do total = total + n end
    for _, state in ipairs({ "N", "I", "C", "G", "J" }) do
        parts[#parts + 1] = ("%s=%d%%"):format(state, total > 0 and math.floor(100 * (samples[state] or 0) / total + 0.5) or 0)
    end
    return ("JITSTAT pid=%d t=%.0fs flush=%d %s\n"):format(vim.uv.os_getpid(), (vim.uv.hrtime() - start) / 1e9, flushes, table.concat(parts, " "))
end

function M.install(every_s)
    every_s = every_s or 10
    local profile = require("jit.profile")
    log_path = vim.env.PARLEY_TEST_JITSTAT_LOG
    profile_running = true
    local start, flushes, samples, last = vim.uv.hrtime(), 0, {}, vim.uv.hrtime()
    jit.attach(function(what)
        if what == "flush" then flushes = flushes + 1 end
    end, "trace")
    profile.start("vi10", function(_, count, vmstate)
        samples[vmstate] = (samples[vmstate] or 0) + count
        local now = vim.uv.hrtime()
        if now - last >= every_s * 1e9 then
            last = now
            emit(summary(start, flushes, samples))
        end
    end)
    vim.api.nvim_create_autocmd("VimLeavePre", { callback = function()
        if profile_running then emit(summary(start, flushes, samples)) end
    end })
end

-- The process that only schedules a spec child reports nothing: its line would
-- read as the spec's (all C, no flushes) and hide the child's.
function M.silence()
    if profile_running then require("jit.profile").stop() end
    profile_running = false
end

return M
