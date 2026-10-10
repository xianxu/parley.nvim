-- #313: session-sync files — lock on first edit, <M-CR> submits over couch,
-- the owner's reply (rewrite + lock removed) unlocks.
local ss = require("parley.session_sync")
local uv = vim.uv or vim.loop

describe("session-sync buffer", function()
    local root, file, argv_file, saved_path, saved_poll, buf
    local p = require("parley")

    local function write_fake_couch()
        local bin = root .. "/bin/couch"
        vim.fn.mkdir(root .. "/bin", "p")
        vim.fn.writefile({
            "#!/bin/sh",
            'for a in "$@"; do printf "%s\\n" "$a" >> "' .. argv_file .. '"; done',
            'if [ -n "$FAKE_COUCH_EXIT" ] && [ "$FAKE_COUCH_EXIT" != 0 ]; then echo "no such peer" >&2; exit "$FAKE_COUCH_EXIT"; fi',
        }, bin)
        assert.is_truthy(uv.fs_chmod(bin, 493))
    end

    local function open(lines)
        vim.fn.writefile(lines, file)
        vim.cmd("edit " .. vim.fn.fnameescape(file))
        buf = vim.api.nvim_get_current_buf()
        p.setup_markdown_keymaps(buf)
    end

    local function keymap_cb(lhs)
        local km = vim.api.nvim_buf_call(buf, function() return vim.fn.maparg(lhs, "n", false, true) end)
        return km.buffer == 1 and km.callback or nil
    end

    local function exists(path) return uv.fs_stat(path) ~= nil end

    -- An edit as the operator makes it: BufModifiedSet fires from the main
    -- loop on a keystroke, never synchronously from an API edit, so a
    -- headless spec fires it after the edit.
    local function edit(text)
        vim.api.nvim_buf_set_lines(buf, 7, 8, false, { text })
        vim.api.nvim_exec_autocmds("BufModifiedSet", { buffer = buf })
    end

    local header = { "---", "type: session-sync", "owner: ops:0", "operator: xian-xu", "---", "", "## Needs you", "- item" }

    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname())
        vim.fn.mkdir(root, "p")
        file = root .. "/tl-status.md"
        argv_file = root .. "/argv"
        write_fake_couch()
        saved_path, saved_poll = vim.env.PATH, ss.POLL_MS
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.FAKE_COUCH_EXIT = "0"
        ss.POLL_MS = 20
        p.config.review_shortcut_next = { modes = { "n", "i" }, shortcut = "<M-CR>" }
        p.config.session_sync_shortcut_unlock = { modes = { "n" }, shortcut = "<C-g>u" }
        p.config.session_sync_stale_minutes = 5
    end)

    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
        vim.env.PATH, ss.POLL_MS = saved_path, saved_poll
        vim.fn.delete(root, "rf")
    end)

    it("takes the lock on the first modification", function()
        open(header)
        assert.is_false(exists(file .. ".lock"))
        edit("- item 🤖[ok?]")
        assert.is_true(exists(file .. ".lock"))
        assert.equals("holder: xian-xu", vim.fn.readfile(file .. ".lock")[1])
    end)

    it("<M-CR> saves, goes read-only and sends one couch message to the owner", function()
        open(header)
        edit("- item 🤖[ok?]")
        keymap_cb("<M-CR>")()
        assert.is_false(vim.bo[buf].modifiable)
        assert.equals("- item 🤖[ok?]", vim.fn.readfile(file)[8])
        assert.is_true(vim.wait(2000, function() return exists(argv_file) end))
        assert.same({ "--send-to", "ops:0", "--message", "submitted: " .. file }, vim.fn.readfile(argv_file))
        vim.wait(100)
        assert.is_false(vim.bo[buf].modifiable)
    end)

    it("a failed send keeps the buffer editable", function()
        vim.env.FAKE_COUCH_EXIT = "3"
        open(header)
        edit("- edited")
        keymap_cb("<M-CR>")()
        assert.is_true(vim.wait(2000, function() return vim.bo[buf].modifiable end))
        assert.is_true(exists(file .. ".lock"))
    end)

    it("the owner's reply reloads the buffer and makes it editable", function()
        open(header)
        edit("- edited")
        keymap_cb("<M-CR>")()
        assert.is_true(vim.wait(2000, function() return exists(argv_file) end))
        local reply = vim.deepcopy(header)
        reply[8] = "- resolved by TL"
        vim.fn.writefile(reply, file)
        os.remove(file .. ".lock")
        assert.is_true(vim.wait(2000, function() return vim.bo[buf].modifiable end))
        assert.equals("- resolved by TL", vim.api.nvim_buf_get_lines(buf, 7, 8, false)[1])
        assert.is_false(vim.bo[buf].modified)
    end)

    it("manual unlock after submit makes it editable and keeps the lock", function()
        open(header)
        edit("- edited")
        keymap_cb("<M-CR>")()
        assert.is_true(vim.wait(2000, function() return exists(argv_file) end))
        keymap_cb("<C-g>u")()
        assert.is_true(vim.bo[buf].modifiable)
        assert.is_true(exists(file .. ".lock"))
    end)

    it("shows the unsent-edits reminder after the idle threshold", function()
        p.config.session_sync_stale_minutes = 0.001
        open(header)
        edit("- edited")
        local ns = vim.api.nvim_create_namespace("parley_session_sync")
        assert.is_true(vim.wait(2000, function()
            local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
            return #marks > 0 and marks[1][4].virt_text[1][1] == ss.REMINDER
        end))
    end)

    it("plain markdown keeps the review action on <M-CR>, and unlock is a no-op", function()
        open({ "# just notes" })
        local fallback_called = false
        ss.dispatch(buf, function() fallback_called = true end)()
        assert.is_true(fallback_called)
        keymap_cb("<C-g>u")()
        assert.is_true(vim.bo[buf].modifiable)
        assert.is_not_nil(keymap_cb("<M-CR>"))
        assert.is_false(exists(file .. ".lock"))
    end)
end)
