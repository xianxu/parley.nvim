-- #218 — the RENDER seam, not the structure.
--
-- highlight_structure's own containment is unit-tested. This pins the second
-- site: highlighter walks the visible window itself, and used to keep a private
-- copy of the fence toggle that never reset at a 💬:/🤖: partition. A stale
-- in_code_block suppresses ParleyQuestion (highlighter.lua:255), so an unmatched
-- fence in one answer silently stopped every later question from highlighting.
--
-- Verified by mutation: restore the private toggle, or drop reset_partition from
-- the walk, and this goes red.

local parley = require("parley")
local highlighter = require("parley.highlighter")

describe("fence containment at the render seam (#218)", function()
    local buf, win

    local function render(lines)
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        parley._parley_bufs[buf] = "chat"
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        highlighter.rebuild_structure(buf)
        highlighter.highlight_question_block(buf)
        local ns = highlighter.setup_highlights()
        local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
        local by_row = {}
        for _, m in ipairs(marks) do
            by_row[m[2]] = by_row[m[2]] or {}
            by_row[m[2]][m[4].hl_group] = true
        end
        return by_row
    end

    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then
            parley._parley_bufs[buf] = nil
            highlighter.clear_structure(buf)
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    it("a question after an unmatched fence still highlights as a question", function()
        local by_row = render({
            "💬: first question",
            "🤖: an answer that opens a fence and never closes it",
            "```lua",
            "local x = 1",
            "💬: second question",
            "body of the second question",
        })
        -- row 4 (0-indexed) is the second question's prefix line, row 5 its body
        assert.is_truthy(by_row[4] and by_row[4].ParleyQuestion,
            "the 💬: line after an unmatched fence lost ParleyQuestion")
        assert.is_truthy(by_row[5] and by_row[5].ParleyQuestion,
            "the question BODY after an unmatched fence lost ParleyQuestion — "
            .. "the stale in_code_block leaked across the partition")
    end)

    it("a well-formed fence still suppresses question highlighting inside it", function()
        -- The guard must not become a no-op: inside a real fence, in a question,
        -- ParleyQuestion is still correctly withheld.
        local by_row = render({
            "💬: a question containing code",
            "```lua",
            "local y = 2",
            "```",
            "trailing question prose",
        })
        assert.is_nil(by_row[2] and by_row[2].ParleyQuestion,
            "content inside an open fence must not highlight as question prose")
        assert.is_truthy(by_row[4] and by_row[4].ParleyQuestion,
            "prose after the fence closes is question prose again")
    end)
end)
