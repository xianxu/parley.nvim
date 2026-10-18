-- #312/#386: a real markdown buffer shows its text literally (conceallevel
-- 0, links included); a chat buffer keeps 2 for parley's own conceals. The
-- cursor is never moved off a marker: nothing is hidden for it to avoid.
local parley = require("parley")

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

describe("comment.attach (#386)", function()
    local line = "ab 🤖<X>[c]{d} z"

    it("a markdown buffer shows markers and links literally", function()
        vim.wo.conceallevel = 2 -- LazyVim's global default
        vim.wo.concealcursor = "n" -- the user's own value
        open_markdown({ line, "a [link](http://x) line" })
        assert.equals(0, vim.wo.conceallevel)
        assert.equals("n", vim.wo.concealcursor, "concealcursor is the user's")
    end)

    it("a chat buffer keeps conceallevel 2 for parley's own conceals", function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        vim.wo.conceallevel = 0
        require("parley.comment").attach(buf, "chat")
        assert.equals(2, vim.wo.conceallevel)
        assert.has_error(function() require("parley.comment").attach(buf, "other") end)
    end)

    it("never moves the cursor on a marker line", function()
        local buf = open_markdown({ line })
        for col = 0, #line - 1 do
            if vim.str_utf_start(line, col + 1) == 0 then
                assert.equals(col, move(buf, col))
            end
        end
    end)

    -- Typing inside a turn lands where it was typed (the old insert-mode snap
    -- moved the cursor under completion plugins such as nvim-cmp).
    it("insert-mode typing inside a turn lands where typed", function()
        local buf = open_markdown({ line })
        local at = line:find("[c]", 1, true) -- 1-based `[` is the 0-based col of `c`
        vim.api.nvim_win_set_cursor(0, { 1, at })
        vim.api.nvim_feedkeys(vim.keycode("ixy<Esc>"), "xt", false)
        assert.equals("ab 🤖<X>[xyc]{d} z", vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
    end)
end)
