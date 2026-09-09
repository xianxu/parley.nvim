-- Characterisation + target tests for the reference-opening chain (#225).
--
-- `OpenFileUnderCursor` has historically had TWO chains — one for markdown
-- buffers (`M.open_chat_reference`) and one for chat buffers, inline in the
-- command. They are not duplicates: four capabilities live in exactly one of
-- them (issue #225 measures them). These tests pin each capability in the
-- buffer type that has it today, so the extraction that unifies the chains
-- cannot silently drop an arm.

local tmp_dir = vim.fn.tempname() .. "-parley-open-ref"
local chat_dir = tmp_dir .. "/chats"
local src_root = tmp_dir .. "/src"
local docs_dir = tmp_dir .. "/docs"
vim.fn.mkdir(chat_dir, "p")
vim.fn.mkdir(src_root, "p")
vim.fn.mkdir(docs_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = chat_dir,
    state_dir = tmp_dir .. "/state",
    src_root = src_root,
    providers = {},
    api_keys = {},
})

-- Build a real chat file (timestamp name + headers, so `not_chat` returns nil).
local function write_chat(basename, body)
    local path = chat_dir .. "/" .. basename
    local lines = {
        "---",
        "topic: Fixture",
        "file: " .. basename,
        "model: test-model",
        "provider: openai",
        "---",
        "",
        "💬: hello",
        "",
        "🤖:[Agent] hi",
    }
    for _, l in ipairs(body or {}) do
        table.insert(lines, l)
    end
    vim.fn.writefile(lines, path)
    return path
end

local function write_markdown(basename, body)
    local path = docs_dir .. "/" .. basename
    vim.fn.writefile(body, path)
    return path
end

-- Open `path` in the current window, put the cursor on the line whose text is
-- `needle`, at column `col` (1-indexed), then run OpenFileUnderCursor with
-- `vim.cmd` and `open_buf` spied. Returns { opened = <open_buf arg>, cmds = {} }.
local function open_at(path, needle, col)
    vim.cmd("silent! %bwipeout!")
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    local buf = vim.api.nvim_get_current_buf()
    local target
    for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        if line == needle then
            target = i
            break
        end
    end
    assert(target, "fixture line not found: " .. needle)
    vim.api.nvim_win_set_cursor(0, { target, (col or 1) - 1 })

    local rec = { cmds = {}, opened = nil, warnings = {} }
    local real_cmd, real_open, real_warn = vim.cmd, parley.open_buf, parley.logger.warning
    vim.cmd = function(c)
        table.insert(rec.cmds, tostring(c))
    end
    parley.open_buf = function(p)
        rec.opened = p
    end
    parley.logger.warning = function(msg)
        table.insert(rec.warnings, tostring(msg))
    end
    local ok, err = pcall(parley.cmd.OpenFileUnderCursor)
    vim.cmd, parley.open_buf, parley.logger.warning = real_cmd, real_open, real_warn
    assert(ok, err)
    return rec
end

local function joined(cmds)
    return table.concat(cmds, "\n")
end

-- On macOS $TMPDIR is a symlink (/tmp -> /private/tmp), and which form comes
-- back depends on whether the path went through `nvim_buf_get_name`. Compare
-- resolved paths so the tests are not asserting on that accident.
local function same_path(expected, actual)
    assert.equals(vim.fn.resolve(expected or ""), vim.fn.resolve(actual or ""))
end

describe("reference opening: capabilities that live in only one chain", function()
    it("D1 — a src: link opens, in markdown", function()
        local target = src_root .. "/lib/thing.lua"
        vim.fn.mkdir(src_root .. "/lib", "p")
        vim.fn.writefile({ "-- target" }, target)

        local line = "see [thing](src:/lib/thing.lua) here"
        local md = write_markdown("d1.md", { "# Doc", "", line })
        local rec = open_at(md, line, 12)

        same_path(target, rec.opened)
    end)

    it("D2 — the @@path: topic form opens, in markdown", function()
        local chat = write_chat("2026-03-24.11-00-00.001_d2.md")
        local line = "@@" .. chat .. ": Some Topic"
        local md = write_markdown("d2.md", { "# Doc", "", line })
        local rec = open_at(md, line, 3)

        same_path(chat, rec.opened)
    end)

    it("D3 — a bare chat filename resolves against the chat roots, in markdown", function()
        local chat = write_chat("2026-03-24.11-00-00.003_d3.md")
        local line = "@@2026-03-24.11-00-00.003_d3.md@@"
        local md = write_markdown("d3.md", { "# Doc", "", line })
        local rec = open_at(md, line, 3)

        same_path(chat, rec.opened)
    end)

    it("D4 — a directory reference opens in Explore, in chat", function()
        local dir = tmp_dir .. "/somedir"
        vim.fn.mkdir(dir, "p")
        local line = "@@" .. dir .. "/@@"
        local chat = write_chat("2026-03-24.11-00-00.004_d4.md", { "", line })
        local rec = open_at(chat, line, 3)

        assert.is_truthy(joined(rec.cmds):match("Explore"))
        assert.is_truthy(joined(rec.cmds):match(vim.pesc(dir)))
    end)

    it("D4 — the directory Explore prefers the other window in a two-split layout", function()
        local dir = tmp_dir .. "/somedir2"
        vim.fn.mkdir(dir, "p")
        local line = "@@" .. dir .. "/@@"
        local chat = write_chat("2026-03-24.11-00-00.005_d4b.md", { "", line })

        vim.cmd("silent! %bwipeout!")
        vim.cmd("only")
        vim.cmd("edit " .. vim.fn.fnameescape(chat))
        vim.cmd("vsplit")
        vim.cmd("wincmd h")
        local origin_win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_get_current_buf()
        local target
        for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if l == line then target = i break end
        end
        vim.api.nvim_win_set_cursor(0, { target, 2 })

        local cmds = {}
        local real_cmd = vim.cmd
        vim.cmd = function(c) table.insert(cmds, tostring(c)) end
        local ok, err = pcall(parley.cmd.OpenFileUnderCursor)
        local landed_win = vim.api.nvim_get_current_win()
        vim.cmd = real_cmd
        vim.cmd("only")
        assert(ok, err)

        assert.is_truthy(table.concat(cmds, "\n"):match("Explore"))
        assert.are_not.equals(origin_win, landed_win)
    end)
end)
