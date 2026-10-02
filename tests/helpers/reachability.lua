-- Full collection for "parley dropped its last reference" probes (#294).
--
-- A compiled LuaJIT trace keeps the closures and tables it specialized on as
-- constants until the trace is flushed: a hot loop that called one document's
-- subscription closure keeps that document reachable. That is the JIT cache,
-- bounded by the number of live traces, not a reference parley holds. On
-- LuaJIT builds that flushed constantly (#294) these probes passed by accident;
-- where traces survive, they report the JIT's anchors as parley leaks. So the
-- probe flushes traces first and then collects. A probe whose contract is that
-- storage is reclaimable while traces stay live (document_sequence_spec's
-- detached-storage case) must not use this.
local M = {}

function M.collect()
    jit.flush()
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
end

return M
