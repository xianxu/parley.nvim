local exchange_model = require("parley.exchange_model")
local tool_folds = require("parley.tool_folds")

describe("tool_folds incremental manual folds", function()
    local original_buf
    local buf
    local win

    before_each(function()
        original_buf = vim.api.nvim_get_current_buf()
        buf = vim.api.nvim_create_buf(false, true)
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
        vim.api.nvim_set_option_value("foldenable", true, { win = win })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "header", "", "💬: q", "", "🤖: a", "",
            "🧠: first", "thinking", "", "plain", "tail",
        })
    end)

    after_each(function()
        if vim.api.nvim_buf_is_valid(original_buf) then
            vim.api.nvim_win_set_buf(win, original_buf)
        end
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    local function model_with(kind, size)
        local model = exchange_model.new(1)
        model:add_exchange(1)
        model:add_block(1, "agent_header", 1)
        model:add_block(1, kind, size)
        return model
    end

    it("creates one fold for a foldable block and skips ordinary text", function()
        local thinking = model_with("thinking", 2)
        assert.is_true(tool_folds._apply_block_fold(buf, win, thinking, 1, 3))
        vim.cmd("normal! zM")
        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(8, vim.fn.foldclosedend(7))

        local text = model_with("text", 2)
        assert.is_false(tool_folds._apply_block_fold(buf, win, text, 1, 3))
    end)

    it("recreates the active fold after streaming tail replacement destroys it", function()
        local model = model_with("thinking", 2)
        tool_folds._apply_block_fold(buf, win, model, 1, 3)
        require("parley.buffer_edit").stream_replace_at_line(buf, 7, {
            "thinking", "inserted thinking",
        })
        model:grow_block(1, 3, 1)
        vim.cmd("normal! zM")
        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(7, vim.fn.foldclosedend(7))

        tool_folds._apply_block_fold(buf, win, model, 1, 3)
        vim.cmd("normal! zM")

        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(9, vim.fn.foldclosedend(7))
    end)

    it("leaves a user fold outside the rewritten range untouched", function()
        vim.cmd("10,11fold")
        local model = model_with("thinking", 2)
        tool_folds._apply_block_fold(buf, win, model, 1, 3)
        require("parley.buffer_edit").stream_replace_at_line(buf, 7, {
            "thinking", "inserted thinking",
        })
        model:grow_block(1, 3, 1)
        tool_folds._apply_block_fold(buf, win, model, 1, 3)
        vim.cmd("normal! zM")

        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(9, vim.fn.foldclosedend(7))
        assert.equals(11, vim.fn.foldclosed(11))
        assert.equals(12, vim.fn.foldclosedend(11))
    end)

    it("builds initial folds from semantic model blocks without clearing an unrelated fold", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "---", "topic: folds", "file: folds.md", "---", "",
            "💬: q", "", "🤖: [A]", "", "🧠: think", "detail", "",
            "📝: summary", "", "🔧: read id=x", "```json", "{}", "```", "",
            "📎: read id=x", "```", "ok", "```", "", "plain one", "plain two",
        })
        vim.cmd("25,26fold")

        tool_folds.apply_folds(buf)
        vim.cmd("normal! zM")

        assert.equals(10, vim.fn.foldclosed(10))
        assert.equals(11, vim.fn.foldclosedend(10))
        assert.equals(13, vim.fn.foldclosed(13))
        assert.equals(15, vim.fn.foldclosed(15))
        assert.equals(18, vim.fn.foldclosedend(15))
        assert.equals(20, vim.fn.foldclosed(20))
        assert.equals(23, vim.fn.foldclosedend(20))
        assert.equals(25, vim.fn.foldclosed(25))
        assert.equals(26, vim.fn.foldclosedend(25))
    end)
end)
