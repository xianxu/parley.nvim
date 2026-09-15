-- Native undo/redo are human edits. Document observation revokes only affected
-- grants; presentation state must neither block history nor cancel other writers.
local M = {}

function M.guard(opts)
    opts.native_history()
    return "native"
end

return M
