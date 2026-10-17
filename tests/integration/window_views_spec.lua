-- parley.window_views (#356, #358): each window's view follows its text across a
-- whole-buffer rewrite. The pure mapping is view_map_spec's; this covers the
-- fields restore writes back on the path where the cursor's column moved.

local window_views = require("parley.window_views")

describe("window_views", function()
    local buf

    before_each(function()
        buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "abcdef", "0123456789" })
    end)

    after_each(function()
        vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("re-derives curswant when the text moved the cursor's column", function()
        vim.api.nvim_win_set_cursor(0, { 1, 3 }) -- on "d"
        local snap = window_views.capture(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "XXabcdef", "0123456789" })
        window_views.restore(buf, snap)

        local view = vim.fn.winsaveview()
        assert.same({ 1, 5, 5 }, { view.lnum, view.col, view.curswant })
        vim.cmd("normal! j")
        assert.same({ 2, 5 }, vim.api.nvim_win_get_cursor(0), "a vertical move keeps the mapped column")
    end)

    it("keeps curswant when the column is unchanged", function()
        vim.api.nvim_win_set_cursor(0, { 2, 2 })
        vim.cmd("normal! $") -- curswant MAXCOL: $-sticky
        local snap = window_views.capture(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "new", "abcdef", "0123456789" })
        window_views.restore(buf, snap)

        assert.same({ 3, 9 }, vim.api.nvim_win_get_cursor(0))
        vim.cmd("normal! k")
        assert.same({ 2, 5 }, vim.api.nvim_win_get_cursor(0), "still $-sticky: the end of the shorter line")
    end)
end)
