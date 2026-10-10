-- #312: <CR> on a 🤖 marker opens its thread in a float; :w writes the thread
-- back as ONE line; anything else leaves the file alone.
local parley = require("parley")
local float = require("parley.comment.float")

local base = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-comment-float-" .. os.time()

local function open_markdown(lines)
    parley.setup({ chat_dir = base .. "/chat", state_dir = base .. "/state", providers = {}, api_keys = {} })
    vim.fn.mkdir(base, "p")
    local path = base .. "/thread-" .. math.random(1e9) .. ".md"
    vim.fn.writefile(lines, path)
    vim.cmd("silent edit! " .. vim.fn.fnameescape(path))
    local buf = vim.api.nvim_get_current_buf()
    parley.setup_markdown_keymaps(buf)
    require("parley.document").attach(buf, { schedule = false })
    return buf
end

local function cursor_on(text, needle)
    local col = text:find(needle, 1, true) - 1
    vim.api.nvim_win_set_cursor(0, { 1, col })
end

local function float_lines()
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

describe("comment thread float (#312)", function()
    -- Ends on a human turn: a chain ending in `{}` is "pending" and the review
    -- skill opens the quickfix list for it, which would steal the window.
    local line = "see 🤖<X>[q]{a}[ok] end"
    after_each(function()
        if vim.api.nvim_win_get_config(0).relative ~= "" then vim.cmd("silent! close!") end
    end)

    it("opens the marker's turns, one per line, cursor in the reply", function()
        local buf = open_markdown({ line })
        cursor_on(line, "X")
        assert.is_true(float.open_thread(buf))
        assert.is_true(vim.api.nvim_win_get_config(0).relative ~= "")
        assert.same({ "[q]", "{a}", "[ok]", "[]" }, float_lines())
        assert.same({ 4, 1 }, vim.api.nvim_win_get_cursor(0))
    end)

    it(":w writes a multi-line reply back as one <br> line", function()
        local buf = open_markdown({ line, "next" })
        cursor_on(line, "X")
        float.open_thread(buf)
        vim.api.nvim_buf_set_lines(0, 3, 4, false, { "[r1", "r2]" })
        vim.cmd("write")
        assert.same({ "see 🤖<X>[q]{a}[ok][r1<br>r2] end", "next" },
            vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        assert.is_false(vim.bo.modified)
    end)

    it("closing without an edit changes nothing", function()
        local buf = open_markdown({ line })
        local tick = vim.api.nvim_buf_get_changedtick(buf)
        cursor_on(line, "X")
        float.open_thread(buf)
        vim.cmd("close")
        assert.equals(tick, vim.api.nvim_buf_get_changedtick(buf))
        assert.same({ line }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("refuses when the marker changed underneath, keeping the text", function()
        local buf = open_markdown({ line })
        cursor_on(line, "X")
        float.open_thread(buf)
        vim.api.nvim_buf_set_lines(0, 3, 4, false, { "[reply]" })
        require("parley.buffer_edit").replace_user_lines(buf, 0, 1, false, { "see 🤖<X>[changed] end" })
        vim.cmd("write")
        assert.same({ "see 🤖<X>[changed] end" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        assert.truthy(vim.fn.getreg('"'):find("[reply]", 1, true))
    end)

    it("refuses unbalanced brackets and keeps the float open", function()
        local buf = open_markdown({ line })
        cursor_on(line, "X")
        float.open_thread(buf)
        local fwin = vim.api.nvim_get_current_win()
        vim.api.nvim_buf_set_lines(0, 3, 4, false, { "[oops" })
        vim.cmd("write")
        assert.same({ line }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        assert.is_true(vim.api.nvim_win_is_valid(fwin))
    end)

    it("q saves and closes; :q! discards", function()
        local buf = open_markdown({ line })
        cursor_on(line, "X")
        float.open_thread(buf)
        vim.api.nvim_buf_set_lines(0, 3, 4, false, { "[kept]" })
        vim.api.nvim_feedkeys("q", "x", false)
        assert.equals("", vim.api.nvim_win_get_config(0).relative)
        assert.same({ "see 🤖<X>[q]{a}[ok][kept] end" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        cursor_on(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "X")
        float.open_thread(buf)
        vim.api.nvim_buf_set_lines(0, 4, 5, false, { "[dropped]" })
        vim.cmd("q!")
        assert.same({ "see 🤖<X>[q]{a}[ok][kept] end" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("does nothing off a marker", function()
        local buf = open_markdown({ line })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        assert.is_false(float.open_thread(buf))
    end)

    it("works for a free-standing chain", function()
        local l = "a 🤖[c1]{r1}[c2] b"
        local buf = open_markdown({ l })
        cursor_on(l, "🤖")
        assert.is_true(float.open_thread(buf))
        assert.same({ "[c1]", "{r1}", "[c2]", "[]" }, float_lines())
    end)
end)

describe("<CR> binding (#312)", function()
    it("opens the float on a marker and stays native elsewhere", function()
        local l = "see 🤖<X>[q] end"
        local buf = open_markdown({ l, "two", "three", "four", "five" })
        cursor_on(l, "X")
        vim.cmd("normal \r")
        assert.is_true(vim.api.nvim_win_get_config(0).relative ~= "")
        vim.cmd("close")
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
        assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])
        vim.api.nvim_feedkeys(vim.keycode("2<CR>"), "x", false)
        assert.equals(5, vim.api.nvim_win_get_cursor(0)[1])
        assert.equals(buf, vim.api.nvim_get_current_buf())
    end)
end)
