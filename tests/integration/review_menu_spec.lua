-- Integration tests for lua/parley/review_menu.lua — the composite review-mode
-- menu (mode selector + multi-line instruction editor). (#133 M4)

local menu = require("parley.review_menu")

describe("review_menu", function()
    local buf

    before_each(function()
        buf = vim.api.nvim_create_buf(false, true)
    end)

    after_each(function()
        pcall(vim.cmd, "stopinsert")
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    it("exports float_picker.compute_layout (reused, not duplicated)", function()
        assert.is_function(require("parley.float_picker").compute_layout)
    end)

    it("opens a mode selector + instruction editor listing the 6 modes", function()
        local h = menu.open({})
        assert.is_not_nil(h)
        assert.is_true(vim.api.nvim_win_is_valid(h.list_win))
        assert.is_true(vim.api.nvim_win_is_valid(h.instr_win))
        local list_buf = vim.api.nvim_win_get_buf(h.list_win)
        assert.are.equal(6, #vim.api.nvim_buf_get_lines(list_buf, 0, -1, false))
        -- the instruction window is a real, modifiable buffer (not buftype=prompt)
        assert.are.equal("", vim.bo[vim.api.nvim_win_get_buf(h.instr_win)].buftype)
        h.close()
        assert.is_false(vim.api.nvim_win_is_valid(h.list_win))
    end)

    it("submit sends {mode, instruction} and the mode is sticky next open", function()
        local got
        local h = menu.open({ mode = "developmental", on_submit = function(r) got = r end })
        assert.are.equal("developmental", h.selected())
        vim.api.nvim_buf_set_lines(vim.api.nvim_win_get_buf(h.instr_win), 0, -1, false, { "tighten the intro" })
        h.submit()
        assert.are.equal("developmental", got.mode)
        assert.are.equal("tighten the intro", got.instruction)
        -- sticky: a fresh open with no explicit mode pre-selects the last one
        local h2 = menu.open({})
        assert.are.equal("developmental", h2.selected())
        h2.close()
    end)

    it("move cycles the selection", function()
        local h = menu.open({ mode = "copy-editing" })
        assert.are.equal("copy-editing", h.selected())
        h.move(1)
        assert.are_not.equal("copy-editing", h.selected())
        h.close()
    end)

    it("free-form requires a non-empty instruction", function()
        local got
        local h = menu.open({ mode = "free-form", on_submit = function(r) got = r end })
        h.submit() -- empty instruction → refused, on_submit not called
        assert.is_nil(got)
        vim.api.nvim_buf_set_lines(vim.api.nvim_win_get_buf(h.instr_win), 0, -1, false, { "do the thing" })
        h.submit()
        assert.is_not_nil(got)
        assert.are.equal("free-form", got.mode)
    end)

    it("review.setup_keymaps binds <M-o>/<M-CR> (menu) on a markdown doc", function()
        -- parley.setup() isn't run in the unit env, so inject the shortcut config
        -- the binding loop reads (the defaults themselves live in config.lua).
        local p = require("parley")
        p.config.review_shortcut_menu = { modes = { "n" }, shortcut = "<M-o>" }
        p.config.review_shortcut_next = { modes = { "n", "i" }, shortcut = "<M-CR>" }
        local b = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(b, "/tmp/doc-m4.md")
        require("parley.skills.review").setup_keymaps(b)
        local has_menu = false
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(b, "n")) do
            if m.desc and m.desc:find("open mode menu", 1, true) then
                has_menu = true
            end
        end
        assert.is_true(has_menu, "menu binding should be set on a markdown doc")
        vim.api.nvim_buf_delete(b, { force = true })
    end)
end)
