-- #312: a real markdown buffer gets compact-marker window options and a cursor
-- that never rests on a hidden marker byte, in normal and insert mode.
local parley = require("parley")
local view = require("parley.comment.view")

local base = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-comment-attach-" .. os.time()

local function open_markdown(lines)
    parley.setup({ chat_dir = base .. "/chat", state_dir = base .. "/state", providers = {}, api_keys = {} })
    vim.fn.mkdir(base, "p")
    local path = base .. "/notes.md"
    vim.fn.writefile(lines, path)
    vim.cmd("silent edit! " .. vim.fn.fnameescape(path))
    local buf = vim.api.nvim_get_current_buf()
    parley.setup_markdown_keymaps(buf)
    return buf
end

local function move(buf, col)
    vim.api.nvim_win_set_cursor(0, { 1, col })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
    return vim.api.nvim_win_get_cursor(0)[2]
end

describe("comment.attach (#312)", function()
    local line = "ab 🤖<X>[c] z"
    local m = view.layout(line)[1]

    it("keeps markers hidden on their line in every mode, nowhere else", function()
        vim.wo.concealcursor = "n" -- the user's own value
        local buf = open_markdown({ line, "a [link](http://x) line" })
        assert.equals(2, vim.wo.conceallevel)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        assert.equals("nvic", vim.wo.concealcursor)
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        assert.equals("n", vim.wo.concealcursor, "other conceals keep the user's setting")
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        vim.api.nvim_exec_autocmds("BufLeave", { buffer = buf })
        assert.equals("n", vim.wo.concealcursor, "leaving the buffer restores it")
    end)

    it("keeps a later change to the window's own value", function()
        vim.wo.concealcursor = ""
        local buf = open_markdown({ line, "plain" })
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        vim.wo.concealcursor = "nc" -- user changes it later
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        assert.equals("nvic", vim.wo.concealcursor)
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        assert.equals("nc", vim.wo.concealcursor)
    end)

    it("snaps the normal-mode cursor out of hidden bytes", function()
        local buf = open_markdown({ line })
        move(buf, 0)
        -- moving right onto 🤖 (hidden) lands on X
        assert.equals(m.visible[1], move(buf, m.hidden[1][1]))
        -- moving right onto the hidden `>` lands on the visible `[`
        assert.equals(m.hidden[2][2], move(buf, m.hidden[2][1]))
        -- moving left onto it lands back on X
        assert.equals(m.visible[2] - 1, move(buf, m.hidden[2][1]))
    end)

    it("snaps in insert mode too", function()
        local buf = open_markdown({ line })
        move(buf, 0)
        vim.cmd("startinsert")
        vim.api.nvim_win_set_cursor(0, { 1, m.hidden[1][1] + 2 })
        vim.api.nvim_exec_autocmds("CursorMovedI", { buffer = buf })
        local col = vim.api.nvim_win_get_cursor(0)[2]
        vim.cmd("stopinsert")
        assert.is_nil(view.snap(view.layout(line), col, col, #line, line, true),
            "rests on an allowed insertion point: " .. col)
    end)

    it("does not snap when the window shows markers literally (conceallevel 0)", function()
        local buf = open_markdown({ line })
        vim.wo.conceallevel = 0
        move(buf, 0)
        assert.equals(m.hidden[1][1] + 1, move(buf, m.hidden[1][1] + 1))
    end)

    it("leaves a marker-free line alone", function()
        local buf = open_markdown({ "plain text" })
        assert.equals(4, move(buf, 4))
    end)
end)
