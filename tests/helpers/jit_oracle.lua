-- Reading a child VM's JIT trace events (#395). An old LuaJIT without the arm64
-- mcode placement fix (#294) can abort every trace with the mcode-allocation
-- error while its compiler is on. A spec that needs a completed trace tells
-- that platform defect apart from its own failure through `mcode_blocked`.
local M = {}

-- jit.vmdef.traceerr's text for LJ_TRERR_MCODEAL; jit_oracle_spec pins it.
M.MCODE_ERROR = "failed to allocate mcode memory"

--- A trace abort's reason as LuaJIT words it, from jit.attach's 'abort'
--- arguments (`otr` the error code, `oex` its detail). Child VMs require this
--- too: they run from the repository root, on Lua's default ./?.lua path.
--- @return string
function M.abort_reason(otr, oex)
    local reason = type(otr) == "number" and require("jit.vmdef").traceerr[otr] or tostring(otr)
    return type(oex) == "number" and reason:format(oex) or reason
end

--- Whether the mcode defect explains a child that completed no trace: none
--- completed, and at least one abort is the mcode-allocation error, so every
--- trace that finished recording then failed to be placed. Other aborts are
--- ordinary recording aborts a healthy VM has too; alone they never explain a
--- zero (measured on document_sequence's workload, #395).
--- @param completed integer traces that stopped
--- @param aborts string[] abort reasons, as traceerr formats them
--- @return boolean
function M.mcode_blocked(completed, aborts)
    if completed ~= 0 or type(aborts) ~= "table" then return false end
    for _, reason in ipairs(aborts) do
        if reason == M.MCODE_ERROR then return true end
    end
    return false
end

return M
