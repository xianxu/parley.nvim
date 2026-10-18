-- #384: the frontmatter typeahead popup on a real buffer. TextChangedI on a
-- declared key's value offers the matching values; nowhere else.
local enum = require("parley.frontmatter_enum")
local helper = require("parley.helper")

describe("frontmatter typeahead popup (#384)", function()
    local offered, saved_complete, buf

    local function type_at(row, line)
        vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { line })
        vim.api.nvim_win_set_cursor(0, { row, #line })
        offered = nil
        vim.api.nvim_exec_autocmds("TextChangedI", { buffer = buf })
        return offered
    end

    before_each(function()
        saved_complete = helper.complete_noselect
        helper.complete_noselect = function(start, items) offered = { start = start, items = items } end
        buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. ".md")
        vim.api.nvim_set_current_buf(buf)
        -- Insert mode puts the cursor after the last character; normal mode
        -- would clamp it onto that character.
        vim.wo.virtualedit = "onemore"
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "---", "collaboration-mode: ", "title: t", "---", "", "body" })
        enum.attach(buf)
    end)

    after_each(function()
        helper.complete_noselect = saved_complete
        vim.wo.virtualedit = ""
        vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("offers the collaboration modes from the value's start", function()
        local got = type_at(2, "collaboration-mode: ")
        assert.same({ start = #"collaboration-mode: " + 1, items = { "discussion", "collaboration", "chat" } }, got)
        assert.same({ "chat" }, type_at(2, "collaboration-mode: ch").items)
    end)

    it("stays quiet on a full value, an undeclared key, and the body", function()
        assert.is_nil(type_at(2, "collaboration-mode: chat"))
        assert.is_nil(type_at(3, "title: dis"))
        assert.is_nil(type_at(6, "collaboration-mode: dis"))
    end)

    it("attaches once", function()
        enum.attach(buf)
        local calls = 0
        helper.complete_noselect = function() calls = calls + 1 end
        vim.api.nvim_win_set_cursor(0, { 2, #"collaboration-mode: " })
        vim.api.nvim_exec_autocmds("TextChangedI", { buffer = buf })
        assert.equals(1, calls)
    end)

    it("offers issue statuses only in issue files", function()
        local issues = require("parley.issues")
        local saved_dir = issues.get_issues_dir
        local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":h")
        issues.get_issues_dir = function() return dir end
        local ok, err = pcall(function()
            local items = type_at(2, "status: wo").items
            assert.is_true(vim.tbl_contains(items, "working"))
            issues.get_issues_dir = function() return dir .. "/elsewhere" end
            assert.is_nil(type_at(2, "status: wo"))
        end)
        issues.get_issues_dir = saved_dir
        assert(ok, err)
    end)

    it("is attached by parley's markdown buffer setup", function()
        local parley = require("parley")
        local scratch = vim.fn.tempname() .. "-frontmatter-enum"
        parley.setup({ chat_dir = scratch, state_dir = scratch .. "/state", providers = {}, api_keys = {} })
        local md = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(md, scratch .. "-note.md")
        parley.setup_markdown_keymaps(md)
        assert.is_true(vim.b[md].parley_frontmatter_enum)
        vim.api.nvim_buf_delete(md, { force = true })
    end)
end)
