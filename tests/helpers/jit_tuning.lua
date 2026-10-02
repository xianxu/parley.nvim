-- #294: LuaJIT machine-code (mcode) placement on arm64 macOS. LuaJIT asks the
-- OS for each new mcode area near the previous one; macOS ignores the hint,
-- and every failed placement flushes all compiled code.
--
-- Before upstream 68354f4447 (2025-11-05, "Allow mcode allocations outside of
-- the jump range to the support code"), a failed placement could only flush
-- and retry, sometimes millions of times. After it, a failure opens a new range
-- wherever the OS puts memory, so one large area (1MB) is placed once and the
-- process stops flushing (chat_typing probe: ~1,300 flushes -> 9, 15-22s ->
-- 10s). On the old allocator the same setting fails every placement: 2.9M
-- flushes, 166s. So it is applied only where the fix is present.
local M = {}

-- LuaJIT 2.1 versions are commit timestamps.
M.MCODE_FIX = 1762386122
M.OPTIONS = { "sizemcode=1024", "maxmcode=8192" }

function M.has_mcode_fix(version)
    local stamp = tonumber((version or ""):match("^LuaJIT 2%.1%.(%d+)$"))
    return stamp ~= nil and stamp >= M.MCODE_FIX
end

--- The jit.opt settings for this runtime, or nil when none apply.
function M.options(version, arch, os)
    if arch == "arm64" and os == "OSX" and M.has_mcode_fix(version) then return M.OPTIONS end
end

function M.apply()
    local options = M.options(jit.version, jit.arch, jit.os)
    if options then jit.opt.start(unpack(options)) end
    return options
end

return M
