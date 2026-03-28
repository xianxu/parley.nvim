local outline = require("parley.outline")

describe("Outline navigation", function()
    local original_notify

    before_each(function()
        original_notify = vim.notify
        vim.notify = function() end
    end)

    after_each(function()
        vim.notify = original_notify
    end)

    it("jumps directly to the selected outline line", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
            "# Heading",
            "",
            "💬: First question",
            "Plain text",
            "## Section",
        })

        local ok, jumped_lnum = outline._jump_to_outline_location({
            bufnr = bufnr,
            name = vim.api.nvim_buf_get_name(bufnr),
            windows = { vim.api.nvim_get_current_win() },
            lnum = 3,
        }, {
            chat_user_prefix = "💬:",
        })

        assert.is_true(ok)
        assert.equals(3, jumped_lnum)
        assert.same({ 3, 0 }, vim.api.nvim_win_get_cursor(0))
    end)

    it("falls back to the nearest outline item when the requested line is not one", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
            "Some text",
            "",
            "💬: First question",
            "Plain text",
            "More text",
        })

        local ok, jumped_lnum = outline._jump_to_outline_location({
            bufnr = bufnr,
            name = vim.api.nvim_buf_get_name(bufnr),
            windows = { vim.api.nvim_get_current_win() },
            lnum = 4,
        }, {
            chat_user_prefix = "💬:",
        })

        assert.is_true(ok)
        assert.equals(3, jumped_lnum)
        assert.same({ 3, 0 }, vim.api.nvim_win_get_cursor(0))
    end)
end)
