-- parley.attention — the attention finder's glue (#354): records each
-- Alt+Return submit that Couch accepted, so the finder can list it as waiting
-- until the agent folds it. The state and its rules live in attention_model;
-- the file in attention_store.

local logger = require("parley.logger")

local M = {}

--- The message ID from `couch --send-to`'s stdout, whose first line reads
--- `<ID> <from> -> <to> <status>`; nil for anything else.
function M.parse_message_id(stdout)
    local line = (stdout or ""):match("^[^\n]*")
    return line:match("^(%S+)%s+%S+%s+%->%s+%S+")
end

--- The breadcrumb of `win` through #353's seam (`file_history.snapshot`), or
--- nil: before that seam lands, with no window, or when it has no value.
function M.breadcrumb(win)
    if not win or win == -1 or not vim.api.nvim_win_is_valid(win) then return nil end
    local ok, history = pcall(require, "parley.file_history")
    if not ok or type(history.snapshot) ~= "function" then return nil end
    local taken, value = pcall(history.snapshot, win)
    return taken and type(value) == "table" and value or nil
end

--- Record a submit of `path` that Couch accepted. `send_result` is the
--- `couch --send-to` result; without a message ID in its stdout nothing can
--- later tell the submit answered, so nothing is recorded and that is warned.
---@param options table|nil # passed to attention_store.apply (tests)
function M.record(path, breadcrumb, send_result, options, on_done)
    on_done = on_done or function() end
    local id = M.parse_message_id(send_result and send_result.stdout)
    if not id then
        logger.warning("attention: no message ID in Couch's reply; the submit of " .. tostring(path) .. " is not tracked")
        return on_done(nil, "no message id")
    end
    require("parley.attention_store").apply({ type = "submitted", path = path, id = id, breadcrumb = breadcrumb },
        options, on_done)
end

return M
