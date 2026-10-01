-- #294: what a slow spec child's LuaJIT is doing. Enabled by
-- PARLEY_TEST_JITSTAT=1 (tests/minimal_init.vim). A child killed at its
-- deadline runs no exit hook, and a long synchronous spec never yields to a
-- libuv timer, so the periodic line is written from the profiler callback,
-- which runs inside the VM. VM states (jit.profile): N compiled, I interpreted,
-- C C code, G GC, J JIT compiler. `flush` counts trace-cache flushes: the
-- mcode-exhaustion thrash #293 measured shows as hundreds of them.
local M = {}

local function summary(start, flushes, samples)
    local total, parts = 0, {}
    for _, n in pairs(samples) do total = total + n end
    for _, state in ipairs({ "N", "I", "C", "G", "J" }) do
        parts[#parts + 1] = ("%s=%d%%"):format(state, total > 0 and math.floor(100 * (samples[state] or 0) / total + 0.5) or 0)
    end
    return ("JITSTAT t=%.0fs flush=%d %s\n"):format((vim.uv.hrtime() - start) / 1e9, flushes, table.concat(parts, " "))
end

function M.install(every_s)
    every_s = every_s or 10
    local profile = require("jit.profile")
    local start, flushes, samples, last = vim.uv.hrtime(), 0, {}, vim.uv.hrtime()
    jit.attach(function(what)
        if what == "flush" then flushes = flushes + 1 end
    end, "trace")
    profile.start("vi10", function(_, count, vmstate)
        samples[vmstate] = (samples[vmstate] or 0) + count
        local now = vim.uv.hrtime()
        if now - last >= every_s * 1e9 then
            last = now
            io.stderr:write(summary(start, flushes, samples))
        end
    end)
    vim.api.nvim_create_autocmd("VimLeavePre", { callback = function()
        -- The make parent mostly waits; a process that never ran Lua has nothing to say.
        if next(samples) then io.stderr:write(summary(start, flushes, samples)) end
    end })
end

return M
