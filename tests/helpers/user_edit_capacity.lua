-- Put a buffer under a REAL user-edit refusal (#265).
--
-- A live generation does not refuse user edits (measured in #265: edits inside
-- a streaming answer, and a whole-buffer replace, all applied), so it is no
-- oracle. What a user can actually meet is `capacity`: the document keeps 64
-- user-guard slots per editor, and every capture still outstanding holds its
-- guards. One capture of 64 regions fills them through the document's own
-- seam, with no double; the next capture refuses with `capacity`.
--
--   local held = require('tests.helpers.user_edit_capacity').hold(buf)
--   ... a command's edit is now refused ...
--   held.release()
local M = {}

M.SLOTS = 64 -- lua/parley/document/user_edits.lua CAPACITY

---@param buf integer
---@return table held # { release = fun() }
function M.hold(buf)
    local regions = {}
    for i = 1, M.SLOTS do regions[i] = { first = { row = 0, col = 0 }, last = { row = 0, col = 0 } } end
    local edits = require("parley.buffer_edit")
    local capture = assert(edits.capture_user(buf, "test-capacity-hold", regions))
    -- The proof the hold works: the very next capture is refused.
    local probe, why = edits.capture_user(buf, "test-capacity-probe", { regions[1] })
    assert(probe == nil and why == "capacity", "the hold did not fill the guard slots: " .. tostring(why))
    return {
        capture = capture, -- held: the tokens keep the guards alive
        release = function() edits.cancel_user(capture) end,
    }
end

return M
