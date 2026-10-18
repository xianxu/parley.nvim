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

    describe("with nvim-cmp active", function()
        local stub, saved_cmp
        before_each(function()
            saved_cmp = package.loaded["cmp"]
            stub = { registered = {}, buffer_sources = nil, completes = 0, enabled = true }
            stub.register_source = function(name, source) stub.registered[name] = source end
            stub.get_config = function()
                return { enabled = function() return stub.enabled end,
                    sources = stub.buffer_sources or { { name = "buffer", group_index = 1 } } }
            end
            stub.setup = { buffer = function(config) stub.buffer_sources = config.sources end }
            stub.complete = function() stub.completes = stub.completes + 1 end
            package.loaded["cmp"] = stub
        end)
        after_each(function() package.loaded["cmp"] = saved_cmp end)

        it("offers the values through cmp, ahead of the buffer's sources, and opens no Vim popup", function()
            assert.is_nil(type_at(2, "collaboration-mode: di"))
            assert.equals("parley_frontmatter", stub.buffer_sources[1].name)
            assert.is_true(stub.buffer_sources[1].group_index < stub.buffer_sources[2].group_index)
            assert.equals("buffer", stub.buffer_sources[2].name)
            assert.equals(1, stub.completes) -- the source was just added: cmp asks again
            local source = stub.registered.parley_frontmatter
            assert.is_true(source.is_available())
            local items
            source.complete(nil, {}, function(result) items = result end)
            assert.same({ { label = "discussion" } }, items)
            -- Already in the sources: cmp's own trigger handles the next key.
            type_at(2, "collaboration-mode: dis")
            assert.equals(1, stub.completes)
            vim.api.nvim_win_set_cursor(0, { 6, 2 })
            assert.is_false(source.is_available()) -- the body: cmp's sources as before
        end)

        it("falls back to Vim's popup where cmp is disabled for the buffer", function()
            stub.enabled = false
            assert.same({ "discussion" }, type_at(2, "collaboration-mode: di").items)
            assert.is_nil(stub.buffer_sources)
        end)
    end)
end)
