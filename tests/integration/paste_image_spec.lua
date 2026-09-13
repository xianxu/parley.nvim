-- tests/integration/paste_image_spec.lua
--
-- The <M-v> paste flow (#231) end-to-end through the config seam: the
-- fixture stands in for osascript. One case per row of the plan's ordering
-- table (State and ordering), plus the key's registry resolution.
local root = vim.fn.tempname() .. "-parley-paste"
vim.fn.mkdir(root, "p")
local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
-- Named so the plan's Integration-points row `fake_clipboard` resolves to a
-- definition (tests/arch/single_source_sweeps_spec.lua "every symbol … exists").
local fake_clipboard = repo .. "/tests/fixtures/fake_clipboard"
local png = repo .. "/tests/fixtures/one_pixel.png"
local log = root .. "/clipboard.log"

local parley = require("parley")
parley.setup({
    chat_dir = root,
    state_dir = vim.fn.tempname() .. "-parley-paste-state",
    providers = {},
    api_keys = {},
    assets = { clipboard_cmd = { fake_clipboard, "{out}" } },
})
local assets = require("parley.assets")

local TS = "2026-09-10.14-20-03.112"

local function open_chat(name, lines)
    local path = root .. "/" .. name
    vim.fn.writefile(lines, path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    return vim.api.nvim_get_current_buf(), path
end

local function chat_lines()
    return { "---", "topic: Paste", "file: x.md", "model: m", "provider: openai", "---", "", "💬: look at this", "and this" }
end

local function wait_for(pred, ms)
    return vim.wait(ms or 3000, pred, 20)
end

local function line_count(buf)
    return #vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function reads()
    return vim.fn.filereadable(log) == 1 and #vim.fn.readfile(log) or 0
end

local function bytes_of(path)
    return assets.default_io.read(path, assets.MAX_BYTES + 1)
end

local notices
local function notify(msg, level)
    notices[#notices + 1] = { msg = msg, level = level }
end

describe("paste image (#231)", function()
    before_each(function()
        notices = {}
        os.remove(log)
        vim.env.PARLEY_FAKE_CLIPBOARD_LOG = log
    end)
    after_each(function()
        vim.env.PARLEY_FAKE_CLIPBOARD = nil
        vim.cmd("silent! %bwipeout!")
        vim.fn.delete(root, "rf")
        vim.fn.mkdir(root, "p")
    end)

    it("saves the clipboard PNG under assets/<ts>/ and inserts the link after the cursor line", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. png
        local buf, path = open_chat(TS .. "_paste.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 }) -- the 💬: line

        parley.paste_image(buf, { notify = notify })

        assert.is_true(wait_for(function() return line_count(buf) == 10 end), "link inserted")
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local att = assets.parse_attachment(lines[9])
        assert.is_not_nil(att, "line 9 is an attachment: " .. lines[9])
        assert.equals(TS, att.ts)
        assert.equals("and this", lines[10], "the following line is untouched")
        local abs = root .. "/" .. att.path
        assert.equals(1, vim.fn.filereadable(abs))
        assert.equals(bytes_of(png), bytes_of(abs), "bytes are the clipboard bytes")
        assert.matches("pasted assets/", notices[#notices].msg)
        assert.equals(1, reads(), "one clipboard read")
        -- Harness $TMPDIR is a symlink (/tmp → /private/tmp): resolve both sides.
        assert.equals(vim.fn.resolve(path), vim.fn.resolve(vim.api.nvim_buf_get_name(buf)))
    end)

    it("declines a text clipboard, writes nothing, and says why", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "text"
        local buf = open_chat(TS .. "_text.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })

        parley.paste_image(buf, { notify = notify })

        assert.is_true(wait_for(function() return #notices > 0 end))
        assert.matches("nothing pasted", notices[1].msg)
        assert.matches("expected type", notices[1].msg, "the tool's own words are shown")
        assert.equals("info", notices[1].level)
        assert.equals(9, line_count(buf))
        assert.equals(0, vim.fn.isdirectory(root .. "/assets"), "no folder created")
    end)

    it("reports a broken tool as a failure with its stderr", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "broken"
        local buf = open_chat(TS .. "_broken.md", chat_lines())
        parley.paste_image(buf, { notify = notify })
        assert.is_true(wait_for(function() return #notices > 0 end))
        assert.equals("warn", notices[1].level)
        assert.matches("exit 2: boom", notices[1].msg)
        assert.equals(9, line_count(buf))
    end)

    it("declines a markdown file without a timestamp name, without reading the clipboard", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. png
        local buf = open_chat("notes.md", { "# note" })
        parley.paste_image(buf, { notify = notify })
        assert.equals(1, #notices)
        assert.matches("timestamp%-named chat", notices[1].msg)
        assert.equals(0, reads())
    end)

    it("the link lands where the cursor was, even if lines were inserted above meanwhile", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "slow:" .. png
        local buf = open_chat(TS .. "_race.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 9, 0 }) -- "and this"
        parley.paste_image(buf, { notify = notify })
        -- Typing above before the tool answers: the anchor must follow.
        vim.api.nvim_buf_set_lines(buf, 6, 6, false, { "inserted above" })
        assert.is_true(wait_for(function() return line_count(buf) == 11 end))
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.equals("and this", lines[10])
        assert.is_not_nil(assets.parse_attachment(lines[11]))
    end)

    it("discards the image when the buffer was closed before the tool answered", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "slow:" .. png
        local buf = open_chat(TS .. "_closed.md", chat_lines())
        parley.paste_image(buf, { notify = notify })
        vim.api.nvim_buf_delete(buf, { force = true })
        assert.is_true(wait_for(function() return #notices > 0 end))
        assert.matches("buffer was closed", notices[1].msg)
        assert.equals(0, vim.fn.isdirectory(root .. "/assets"), "no bytes without a transcript line")
    end)

    it("refuses a second paste while one is in flight on the same buffer", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "slow:" .. png
        local buf = open_chat(TS .. "_twice.md", chat_lines())
        parley.paste_image(buf, { notify = notify })
        parley.paste_image(buf, { notify = notify })
        assert.matches("already in progress", notices[1].msg)
        assert.is_true(wait_for(function() return line_count(buf) == 10 end))
        assert.equals(1, reads(), "the second key spawned nothing")
        -- and the flight is over: a third paste is accepted. Wait for ITS link,
        -- not the log line — the fixture logs before it sleeps, and a paste
        -- still in flight when this case returns would notify into the next
        -- case's table (nothing outlives a paste: ARCH-ORDER).
        parley.paste_image(buf, { notify = notify })
        assert.is_true(wait_for(function() return line_count(buf) == 11 end))
        assert.equals(2, reads())
    end)

    it("relays a save failure as nothing pasted, leaving the buffer untouched", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. png
        -- The assets path is a plain FILE, so save's mkdir cannot succeed.
        vim.fn.writefile({ "not a folder" }, root .. "/" .. assets.DIR)
        local buf = open_chat(TS .. "_nowrite.md", chat_lines())
        parley.paste_image(buf, { notify = notify })
        assert.is_true(wait_for(function() return #notices > 0 end))
        assert.matches("nothing pasted", notices[1].msg)
        assert.matches("could not create", notices[1].msg)
        assert.equals("error", notices[1].level)
        assert.equals(9, line_count(buf), "no link without bytes")
        assert.equals(1, reads())
    end)

    it("<M-v> is a parley_buffer entry resolving to n/i through the registry", function()
        local reg = require("parley.keybinding_registry")
        local entry
        for _, e in ipairs(reg.entries) do
            if e.id == "paste_image" then entry = e end
        end
        assert.is_not_nil(entry)
        assert.equals("parley_buffer", entry.scope)
        local keys, modes = reg.resolve_keys(entry, parley.config)
        assert.same({ "<M-v>" }, keys)
        assert.same({ "n", "i" }, modes)
    end)
end)
