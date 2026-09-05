-- #218 BR-15: copy.lua's partition bound shipped with no spec anywhere in
-- tests/. Its fence scan walks up and down from the cursor, so before the bound
-- an unmatched fence in an earlier exchange could be picked as the enclosing
-- block and content from a different turn copied out.

local copy = require("parley.copy")

describe("copy_code_fence exchange bound (#218)", function()
    local buf, win, notified

    local function open(lines, cursor_row)
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        vim.api.nvim_win_set_cursor(win, { cursor_row, 0 })
    end

    before_each(function()
        notified = {}
        _G.__copy_notify = vim.notify
        vim.notify = function(msg, lvl) notified[#notified + 1] = { msg = msg, lvl = lvl } end
        vim.fn.setreg("+", "")
    end)

    after_each(function()
        vim.notify = _G.__copy_notify
        if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    it("does not reach back past a turn partition for an opening fence", function()
        open({
            "🤖: an earlier answer",
            "```lua",            -- unmatched, belongs to the PREVIOUS exchange
            "earlier code",
            "💬: a new question",
            "🤖: a new answer",
            "some prose here",   -- cursor: not inside any fence of its own turn
        }, 6)
        copy.copy_code_fence()
        local msgs = table.concat(vim.tbl_map(function(n) return n.msg end, notified), " | ")
        assert.is_truthy(msgs:find("Not inside a code fence", 1, true),
            "the scan crossed a partition and adopted the previous exchange's "
            .. "fence; got: " .. msgs)
    end)

    it("still copies a well-formed fence inside the same exchange", function()
        open({
            "🤖: an answer",
            "```lua",
            "local x = 1",
            "```",
        }, 3)
        copy.copy_code_fence()
        -- Assert on the notification, not the + register: headless nvim has no
        -- clipboard provider, so setreg("+") does not round-trip.
        local msgs = table.concat(vim.tbl_map(function(n) return n.msg end, notified), " | ")
        assert.is_truthy(msgs:find("1 line(s) copied", 1, true),
            "expected a successful copy from the in-exchange fence; got: " .. msgs)
    end)
end)
