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

-- Drive the real tree builder and selection callback against on-disk chats.
describe("Outline branch destinations (#250)", function()
    local parley = require("parley")
    local picker = require("parley.float_picker")
    local tmp, original_open, original_notify, options, notices

    before_each(function()
        tmp = vim.fn.tempname()
        vim.fn.mkdir(tmp, "p")
        tmp = vim.uv.fs_realpath(tmp)
        parley.setup({ chat_dir = tmp, state_dir = tmp .. "/state", providers = {}, api_keys = {} })
        original_open, original_notify = picker.open, vim.notify
        notices = {}
        picker.open = function(opts) options = opts end
        vim.notify = function(msg) notices[#notices + 1] = msg end
    end)

    after_each(function()
        picker.open, vim.notify = original_open, original_notify
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_get_name(buf):find(tmp, 1, true) then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
        end
        vim.fn.delete(tmp, "rf")
    end)

    local function filename(name)
        local ids = { parent = "00", child = "01", leaf = "02", missing = "03" }
        return "2026-09-14.10-00-" .. ids[name] .. ".000_" .. name .. ".md"
    end

    local function chat(name, body)
        local path = tmp .. "/" .. filename(name)
        body = (body or ""):gsub("([%a]+)%.md", filename)
        vim.fn.writefile({ "---", "topic: " .. name, "file: " .. vim.fn.fnamemodify(path, ":t"), "---", "💬: question", body }, path)
        return path
    end

    local function open_outline(path)
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        outline.question_picker(parley.config)
    end

    local function branch_to(path)
        for _, item in ipairs(options.items) do
            if item.value.child_path == path then return item end
        end
        error("missing branch to " .. path)
    end

    for _, inline in ipairs({ false, true }) do
        it("opens an unloaded " .. (inline and "inline" or "standalone") .. " child at line 1", function()
            local child = chat("child")
            local ref = inline and "[🌿: child](child.md)" or "🌿: child.md: Child"
            open_outline(chat("parent", ref))
            options.on_select(branch_to(child))
            assert.equals(child, vim.api.nvim_buf_get_name(0))
            assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
        end)
    end

    it("opens a nested branch and retains question destinations", function()
        local leaf = chat("leaf")
        chat("child", "🌿: leaf.md: Leaf")
        open_outline(chat("parent", "🌿: child.md: Child"))
        options.on_select(branch_to(leaf))
        assert.equals(leaf, vim.api.nvim_buf_get_name(0))
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
        for _, item in ipairs(options.items) do
            if item.value.file == leaf and item.type == "question" then
                options.on_select(item)
                assert.same({ 5, 0 }, vim.api.nvim_win_get_cursor(0))
                return
            end
        end
        error("missing leaf question")
    end)

    it("reports a missing child without opening an empty file", function()
        local parent = chat("parent", "🌿: missing.md: Missing")
        open_outline(parent)
        options.on_select(branch_to(tmp .. "/" .. filename("missing")))
        assert.equals(parent, vim.api.nvim_buf_get_name(0))
        assert.equals(-1, vim.fn.bufnr(tmp .. "/" .. filename("missing")))
        assert.truthy(table.concat(notices, "\n"):find("missing.md", 1, true))
    end)
end)
