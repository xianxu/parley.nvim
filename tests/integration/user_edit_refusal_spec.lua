-- #265: a chat command whose user edit is REFUSED changes nothing, or says
-- exactly what it did. The refusal is real: the document's user-guard slots
-- are held full (tests/helpers/user_edit_capacity.lua), so the command's
-- capture is refused with `capacity` through the document's own seam.
local parley = require("parley")
local Capacity = require("tests.helpers.user_edit_capacity")

local root = vim.fn.resolve(vim.fn.tempname() .. "-user-edit-refusal")
vim.fn.mkdir(root .. "/state", "p")
-- llm_onboarding off: in headless mode it would cancel ChatPrune before it runs.
parley.setup({ chat_dir = root, state_dir = root .. "/state", providers = {}, api_keys = {}, llm_onboarding = false })

local NAME = "2026-09-15.12-00-00.001_refusal.md"
local CHAT = {
    "---", "topic: Refusal Fixture", "file: " .. NAME, "---", "",
    "💬: first question", "", "🤖: [A]", "first answer", "",
    "💬: second question", "", "🤖: [A]", "second answer", "",
}

local warned, saved_warning
local function open_chat(lines, name)
    local path = root .. "/" .. (name or NAME)
    vim.fn.writefile(lines or CHAT, path)
    vim.cmd("edit! " .. vim.fn.fnameescape(path))
    return vim.api.nvim_get_current_buf(), path
end
local function body(buf) return vim.api.nvim_buf_get_lines(buf, 0, -1, false) end
local function md_files()
    local out = vim.fn.globpath(root, "*.md", false, true)
    table.sort(out)
    return out
end

describe("chat commands under a refused user edit (#265)", function()
    before_each(function()
        warned = {}
        saved_warning = parley.logger.warning
        parley.logger.warning = function(m) warned[#warned + 1] = tostring(m) end
    end)
    after_each(function()
        parley.logger.warning = saved_warning
        vim.cmd("silent! %bwipeout!")
        vim.fn.delete(root, "rf")
        vim.fn.mkdir(root .. "/state", "p") -- the state dir lives under root; keep it for the next case
    end)

    -- Headless Neovim has no clipboard provider, so the clipboard is observed
    -- through ExchangePaste: a cut published before its edit would paste here.
    it("ExchangeCut leaves the buffer AND the clipboard as they were", function()
        local buf = open_chat()
        local before = body(buf)
        local held = Capacity.hold(buf)
        vim.api.nvim_win_set_cursor(0, { 6, 0 })
        local ok, err = pcall(parley.cmd.ExchangeCut)
        held.release()
        assert.is_true(ok, tostring(err))
        assert.same(before, body(buf))
        assert.is_truthy(table.concat(warned, "\n"):find("ExchangeCut — Edit not made", 1, true))
        -- A paste now must not duplicate the text the cut never removed.
        vim.api.nvim_win_set_cursor(0, { 11, 0 })
        pcall(parley.cmd.ExchangePaste)
        assert.same(before, body(buf))
    end)

    it("ChatPrune writes no child file when the parent edit is refused", function()
        local buf = open_chat()
        local before, files = body(buf), md_files()
        local held = Capacity.hold(buf)
        vim.api.nvim_win_set_cursor(0, { 11, 0 })
        local ok, err = pcall(parley.cmd.ChatPrune)
        held.release()
        assert.is_true(ok, tostring(err))
        assert.same(before, body(buf))
        assert.same(files, md_files(), "an orphan child file was written")
        assert.is_truthy(table.concat(warned, "\n"):find("ChatPrune — Edit not made", 1, true))
    end)

    it("the slug rename keeps the old name and header when the header edit is refused", function()
        local lines = vim.deepcopy(CHAT)
        lines[2] = "topic: A Renamed Topic"
        local buf, path = open_chat(lines)
        local held = Capacity.hold(buf)
        local new_path, why = parley._slug_rename_chat(buf)
        held.release()
        assert.is_nil(new_path)
        assert.equals("header edit refused: capacity", why)
        assert.equals(1, vim.fn.filereadable(path), "the file was renamed under a stale header")
        assert.equals("file: " .. NAME, body(buf)[3])
        assert.equals(path, vim.fn.resolve(vim.api.nvim_buf_get_name(buf)))
    end)

    it("ChatReview says the back-reference was not added, and leaves the source as it was", function()
        local src = root .. "/notes.md"
        vim.fn.writefile({ "---", "title: notes", "---", "", "body" }, src)
        vim.cmd("edit! " .. vim.fn.fnameescape(src))
        local sbuf = vim.api.nvim_get_current_buf()
        local before = body(sbuf)
        local held = Capacity.hold(sbuf)
        local ok, err = pcall(parley.cmd.ChatReview)
        held.release()
        assert.is_true(ok, tostring(err))
        assert.same(before, body(sbuf))
        -- ONE warning: the refusal, then what happened (#265 close review).
        assert.equals(1, #warned, table.concat(warned, "\n"))
        assert.is_truthy(warned[1]:find("ChatReview — Edit not made", 1, true), warned[1])
        assert.is_truthy(warned[1]:find("back%-reference not added"), warned[1])
    end)

    it("ChatPrune puts the exchanges back when the child file cannot be written", function()
        local buf = open_chat()
        local before = body(buf)
        local saved = vim.fn.writefile
        vim.fn.writefile = function(lines, path, ...)
            if path:match("%.md$") and path ~= vim.api.nvim_buf_get_name(buf) then return -1 end
            return saved(lines, path, ...)
        end
        vim.api.nvim_win_set_cursor(0, { 11, 0 })
        local ok, err = pcall(parley.cmd.ChatPrune)
        vim.fn.writefile = saved
        assert.is_true(ok, tostring(err))
        assert.same(before, body(buf), "the parent was left pointing at a child that does not exist")
        assert.is_truthy(table.concat(warned, "\n"):find("could not write", 1, true))
    end)
end)
