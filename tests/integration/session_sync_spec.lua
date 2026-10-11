-- #313/#315: session-sync files — the operator's lock is the only lock: the
-- first edit takes it, <M-CR> saves, deletes it and tells the agent over couch;
-- a clean buffer follows the agent's writes. Owed work (couch's owed events)
-- and the operator's turn are rendered in the winbar and StatusLine.
local ss = require("parley.session_sync")
local uv = vim.uv or vim.loop

describe("session-sync buffer", function()
    local root, file, argv_file, log_file, saved_path, saved_poll, saved_check, buf
    local p = require("parley")

    local function write_fake_couch()
        local bin = root .. "/bin/couch"
        vim.fn.mkdir(root .. "/bin", "p")
        -- Queries answer from env (`--session-sync` exits 2 unless
        -- FAKE_COUCH_STATUS is set: the verb before pair#437); every send
        -- appends one line `<to>|<message>` to the log.
        vim.fn.writefile({
            "#!/bin/sh",
            'case "$1" in',
            '--actors) printf "%s" "$FAKE_COUCH_ACTORS"; exit 0;;',
            '--session-sync) [ -n "$FAKE_COUCH_STATUS" ] || exit 2; printf "%s" "$FAKE_COUCH_STATUS"; exit 0;;',
            'esac',
            'if [ -n "$FAKE_COUCH_SLEEP" ]; then sleep "$FAKE_COUCH_SLEEP"; fi',
            'printf "%s|%s\\n" "$2" "$4" >> "' .. log_file .. '"',
            -- Written whole, then renamed: the spec polls for the file.
            'for a in "$@"; do printf "%s\\n" "$a"; done > "' .. argv_file .. '.tmp"',
            'mv "' .. argv_file .. '.tmp" "' .. argv_file .. '"',
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
    local function sent() return exists(log_file) and vim.fn.readfile(log_file) or {} end
    -- One live actor; `quiet` = its last activity is a minute old (turn
    -- ended), else just now (mid-turn). Resting names the resting branch, not
    -- the turn: it is true here either way, so it can't decide the ping.
    local function actors(slot, quiet)
        return vim.json.encode({ Code = "ok", Actors = {
            { Binding = { Slot = slot }, Known = true, Resting = true,
              LastActivity = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() - (quiet and 60 or 0)) },
        } })
    end
    -- couch's `--session-sync status` reporting one owed event `minutes` old.
    local function owed(minutes)
        return vim.json.encode({ Code = "ok", Status = { Owed = {
            { ID = "d1", Kind = "delivery", At = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() - minutes * 60) },
        } } })
    end
    -- A lock (or file) last written `minutes` ago.
    local function age(path, minutes)
        local t = os.time() - minutes * 60
        assert.is_truthy(uv.fs_utime(path, t, t))
    end
    local function agent_write(text)
        local update = vim.deepcopy({ "---", "type: session-sync", "owner: ops:0", "operator: xian-xu", "---", "", "## Needs you", "- item" })
        update[8] = text
        vim.fn.writefile(update, file)
    end
    local function holder() return vim.fn.readfile(file .. ".lock")[1] end
    local function winbar() return vim.wo[vim.fn.bufwinid(buf)].winbar end
    local function winhl() return vim.wo[vim.fn.bufwinid(buf)].winhighlight end

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
        log_file = root .. "/sent"
        write_fake_couch()
        saved_path, saved_poll, saved_check = vim.env.PATH, ss.POLL_MS, ss.PING_CHECK_MS
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.FAKE_COUCH_EXIT = "0"
        vim.env.FAKE_COUCH_SLEEP = nil
        vim.env.FAKE_COUCH_STATUS = nil
        vim.env.FAKE_COUCH_ACTORS = actors("ops:0", true)
        ss.POLL_MS = 20
        ss.PING_CHECK_MS = 20
        p.config.session_sync_ping_minutes = 5
        p.config.review_shortcut_next = { modes = { "n", "i" }, shortcut = "<M-CR>" }
        p.config.session_sync_stale_minutes = 5
    end)

    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
        vim.env.PATH, ss.POLL_MS, ss.PING_CHECK_MS = saved_path, saved_poll, saved_check
        vim.fn.delete(root, "rf")
    end)

    it("starts free, and the first modification takes the operator's turn", function()
        open(header)
        assert.is_false(exists(file .. ".lock"))
        assert.equals("%#ParleySessionSyncFree# free: editing takes your turn%=", winbar())
        edit("- item 🤖[ok?]")
        assert.equals("holder: operator", holder())
        assert.equals("%#ParleySessionSyncOperator# your turn, Alt+Return to submit%=", winbar())
        assert.equals("StatusLine:ParleySessionSyncOperator", winhl())
    end)

    it("<M-CR> saves, deletes the lock, leaves the buffer editable and sends one couch message (#315)", function()
        open(header)
        edit("- item 🤖[ok?]")
        keymap_cb("<M-CR>")()
        assert.is_false(exists(file .. ".lock"))
        assert.is_true(vim.bo[buf].modifiable)
        assert.is_false(vim.bo[buf].modified)
        assert.equals("- item 🤖[ok?]", vim.fn.readfile(file)[8])
        assert.equals("%#ParleySessionSyncFree# free: editing takes your turn%=", winbar())
        assert.is_true(vim.wait(2000, function() return exists(argv_file) end))
        assert.same({ "--send-to", "ops:0", "--message", "submitted: " .. file }, vim.fn.readfile(argv_file))
        -- The next keystroke takes the lock again.
        edit("- second thought")
        assert.equals("holder: operator", holder())
    end)

    it("a failed send leaves the file free and the buffer editable (#315)", function()
        vim.env.FAKE_COUCH_EXIT = "3"
        open(header)
        edit("- edited")
        keymap_cb("<M-CR>")()
        assert.is_true(vim.wait(2000, function() return exists(argv_file) end))
        vim.wait(100)
        assert.is_false(exists(file .. ".lock"))
        assert.is_true(vim.bo[buf].modifiable)
        assert.equals("- edited", vim.fn.readfile(file)[8])
    end)

    it("the agent's reply to a submit reloads the clean buffer silently (#315)", function()
        open(header)
        edit("- edited")
        keymap_cb("<M-CR>")()
        assert.is_true(vim.wait(2000, function() return exists(argv_file) end))
        agent_write("- resolved by TL")
        assert.is_true(vim.wait(2000, function()
            return vim.api.nvim_buf_get_lines(buf, 7, 8, false)[1] == "- resolved by TL"
        end))
        assert.is_false(vim.bo[buf].modified)
        assert.is_false(exists(file .. ".lock"))
        assert.is_false(exists(file .. ".clobbered"))
        assert.equals(1, #sent())            -- only the submit: no violation
    end)

    it("a reply noticed by :checktime reloads a clean buffer without a prompt (#315)", function()
        ss.POLL_MS = 60000               -- only FileChangedShell can notice it
        open(header)
        edit("- edited")
        keymap_cb("<M-CR>")()
        agent_write("- resolved by TL")
        vim.cmd("checktime")
        assert.equals("- resolved by TL", vim.api.nvim_buf_get_lines(buf, 7, 8, false)[1])
        assert.is_false(vim.bo[buf].modified)
    end)

    it("a legacy holder: agent lock does not block the operator (#315)", function()
        vim.fn.writefile({ "holder: agent" }, file .. ".lock")
        open(header)
        assert.is_true(vim.bo[buf].modifiable)
        assert.equals("%#ParleySessionSyncFree# free: editing takes your turn%=", winbar())
        edit("- edited")
        assert.equals("holder: operator", holder())
        assert.equals("%#ParleySessionSyncOperator# your turn, Alt+Return to submit%=", winbar())
    end)

    it("an idle operator turn turns stale and renders in the reminder colour", function()
        p.config.session_sync_stale_minutes = 0.001
        open(header)
        edit("- edited")
        assert.is_true(vim.wait(2000, function()
            return winbar() == "%#ParleySessionSyncStale# unsent edits, Alt+Return to submit%="
        end))
        assert.equals("StatusLine:ParleySessionSyncStale", winhl())
    end)

    it("the operator's turn is a dark red band", function()
        open(header)
        local hl = vim.api.nvim_get_hl(0, { name = "ParleySessionSyncOperator", link = false })
        assert.equals(0x870000, hl.bg)
        assert.is_true(hl.bold)
    end)

    it("a free buffer follows the agent's writes on disk", function()
        open(header)
        local update = vim.deepcopy(header)
        update[8] = "- new thread from TL"
        vim.fn.writefile(update, file)
        assert.is_true(vim.wait(2000, function()
            return vim.api.nvim_buf_get_lines(buf, 7, 8, false)[1] == "- new thread from TL"
        end))
        assert.is_false(exists(file .. ".lock"))
    end)

    it("an agent write racing the first edit: the operator's text is kept, theirs in .clobbered (#315)", function()
        ss.POLL_MS = 60000               -- the watch never catches the write
        open(header)
        agent_write("- new thread from TL")
        edit("- edited on the old copy")
        assert.equals("holder: operator", holder())
        assert.is_true(vim.wait(2000, function() return exists(file .. ".clobbered") end))
        assert.equals("- edited on the old copy", vim.api.nvim_buf_get_lines(buf, 7, 8, false)[1])
        assert.equals("- edited on the old copy", vim.fn.readfile(file)[8])
        assert.equals("- new thread from TL", vim.fn.readfile(file .. ".clobbered")[8])
        assert.equals("%#ParleySessionSyncOperator# ops:0 changed as you started typing: yours kept, theirs in .clobbered%=", winbar())
        assert.is_true(vim.wait(2000, function() return #sent() == 1 end))
        assert.matches("as the operator started editing", sent()[1], 1, true)
    end)

    it("submit over a write made under the operator's lock keeps the operator's copy (#314)", function()
        ss.POLL_MS = 60000
        open(header)
        edit("- edited")
        assert.equals("holder: operator", holder())
        agent_write("- new thread from TL")   -- a writer ignoring the lock
        keymap_cb("<M-CR>")()
        assert.equals("- edited", vim.fn.readfile(file)[8])
        assert.equals("- new thread from TL", vim.fn.readfile(file .. ".clobbered")[8])
        assert.is_false(exists(file .. ".lock"))
        assert.is_true(vim.wait(2000, function() return #sent() == 2 end))
        local log = table.concat(sent(), "\n")
        assert.matches("ops:0|session-sync violation: " .. file, log, 1, true)
        assert.matches("ops:0|submitted: " .. file, log, 1, true)
    end)

    it("an agent write under the operator's lock: no prompt, buffer kept, band flagged, one message (#314)", function()
        open(header)
        edit("- edited")
        agent_write("- TL ignored the lock")
        assert.is_true(vim.wait(2000, function() return exists(file .. ".clobbered") end))
        assert.equals("- edited", vim.api.nvim_buf_get_lines(buf, 7, 8, false)[1])
        assert.equals("- edited", vim.fn.readfile(file)[8])
        assert.equals("- TL ignored the lock", vim.fn.readfile(file .. ".clobbered")[8])
        assert.equals("holder: operator", holder())
        assert.equals("%#ParleySessionSyncOperator# ops:0 wrote under your lock: yours kept, theirs in .clobbered%=", winbar())
        assert.is_true(vim.wait(2000, function() return #sent() == 1 end))
        assert.matches("^ops:0|session%-sync violation: ", sent()[1])
        -- A second violation in the same turn is kept too, without a second message.
        agent_write("- and again")
        assert.is_true(vim.wait(2000, function() return vim.fn.readfile(file .. ".clobbered")[8] == "- and again" end))
        assert.equals("- edited", vim.fn.readfile(file)[8])
        vim.wait(200)
        assert.equals(1, #sent())
    end)

    it("an agent deleting the file under the lock: the operator's copy is restored, nothing claimed kept (BR-2)", function()
        open(header)
        edit("- edited")
        os.remove(file)
        assert.is_true(vim.wait(2000, function() return exists(file) end))
        assert.equals("- edited", vim.fn.readfile(file)[8])
        assert.is_false(exists(file .. ".clobbered"))
        assert.is_true(vim.wait(2000, function() return #sent() == 1 end))
        assert.matches("deleted while the operator held the lock", sent()[1], 1, true)
        assert.is_nil(sent()[1]:find(".clobbered", 1, true))
    end)

    it("a copy that cannot be kept is not overwritten (BR-2)", function()
        open(header)
        edit("- edited")
        vim.fn.mkdir(file .. ".clobbered", "p")   -- the copy will fail
        agent_write("- TL ignored the lock")
        assert.is_true(vim.wait(2000, function() return #sent() == 1 end))
        assert.equals("- TL ignored the lock", vim.fn.readfile(file)[8])
        assert.equals("- edited", vim.api.nvim_buf_get_lines(buf, 7, 8, false)[1])
        assert.matches("could not be kept", sent()[1], 1, true)
        vim.wait(200)
        assert.equals(1, #sent())            -- no retry loop
        -- Submit refuses while the agent's copy is still the file (BR-6).
        keymap_cb("<M-CR>")()
        assert.equals("holder: operator", holder())
        assert.equals("- TL ignored the lock", vim.fn.readfile(file)[8])
        vim.wait(200)
        assert.equals(1, #sent())
    end)

    it("an unloaded buffer stops watching: a later write is no violation (#314)", function()
        open(header)
        edit("- edited")
        vim.cmd("bdelete!")              -- unloads; BufWipeout never fires
        agent_write("- TL writes after the operator closed it")
        vim.wait(300)
        assert.is_false(exists(file .. ".clobbered"))
        assert.equals("- TL writes after the operator closed it", vim.fn.readfile(file)[8])
        assert.equals(0, #sent())
    end)

    it("a write noticed by :checktime under the operator's lock never prompts (#314)", function()
        ss.POLL_MS = 60000               -- only FileChangedShell can notice it
        open(header)
        edit("- edited")
        agent_write("- TL ignored the lock")
        vim.cmd("checktime")
        assert.is_true(vim.wait(2000, function() return exists(file .. ".clobbered") end))
        assert.equals("- edited", vim.api.nvim_buf_get_lines(buf, 7, 8, false)[1])
        assert.equals("- edited", vim.fn.readfile(file)[8])
        assert.is_true(vim.bo[buf].modified == false)
        vim.cmd("silent write")          -- a later save is quiet
        assert.is_true(vim.wait(2000, function() return #sent() == 1 end))
    end)

    it("the owed band counts the minutes from couch's oldest owed event (#315)", function()
        vim.env.FAKE_COUCH_STATUS = owed(3)
        open(header)
        assert.is_true(vim.wait(2000, function()
            return winbar() == "%#ParleySessionSyncOwed# ops:0 owes a response, 3 min%="
        end))
        assert.equals("StatusLine:ParleySessionSyncOwed", winhl())
        -- The operator's turn outranks it; nothing owed is the neutral band.
        edit("- edited")
        assert.equals("%#ParleySessionSyncOperator# your turn, Alt+Return to submit%=", winbar())
        vim.env.FAKE_COUCH_STATUS = '{"Code":"ok","Status":{"Owed":[]}}'
        keymap_cb("<M-CR>")()
        assert.is_true(vim.wait(2000, function()
            return winbar() == "%#ParleySessionSyncFree# free: editing takes your turn%="
        end))
    end)

    it("a lock alone never shows owed work (#315)", function()
        vim.fn.writefile({ "holder: agent" }, file .. ".lock")
        age(file .. ".lock", 3)
        open(header)
        vim.wait(200)
        assert.equals("%#ParleySessionSyncFree# free: editing takes your turn%=", winbar())
    end)

    describe("liveness ping (#314)", function()
        local function pings()
            return vim.tbl_filter(function(l) return l:find("session-sync ping:", 1, true) end, sent())
        end

        it("pings a quiet owner once when it has owed a response for the threshold", function()
            vim.env.FAKE_COUCH_STATUS = owed(6)
            open(header)
            assert.is_true(vim.wait(2000, function() return #pings() == 1 end))
            assert.matches("^ops:0|session%-sync ping: " .. vim.pesc(file) .. " owes a response since ", pings()[1])
            vim.wait(300)
            assert.equals(1, #pings())
        end)

        it("does not ping an owner mid-turn, and does once it goes quiet", function()
            vim.env.FAKE_COUCH_ACTORS = actors("ops:0", false)
            vim.env.FAKE_COUCH_STATUS = owed(6)
            open(header)
            vim.wait(300)
            assert.equals(0, #pings())
            vim.env.FAKE_COUCH_ACTORS = actors("ops:0", true)
            assert.is_true(vim.wait(2000, function() return #pings() == 1 end))
        end)

        it("does not ping before the threshold, when nothing is owed, or when the owner is not live", function()
            vim.env.FAKE_COUCH_STATUS = owed(4)
            open(header)
            vim.wait(300)
            assert.equals(0, #pings())
            vim.api.nvim_buf_delete(buf, { force = true })
            vim.env.FAKE_COUCH_STATUS = nil
            vim.fn.writefile({ "holder: agent" }, file .. ".lock")
            age(file .. ".lock", 60)     -- a legacy agent lock alone owes nothing (#315)
            open(header)
            age(file, 60)
            vim.wait(300)
            assert.equals(0, #pings())
            vim.api.nvim_buf_delete(buf, { force = true })
            os.remove(file .. ".lock")
            vim.env.FAKE_COUCH_ACTORS = actors("pair:0", true)
            vim.env.FAKE_COUCH_STATUS = owed(6)
            open(header)
            vim.wait(300)
            assert.equals(0, #pings())
        end)

        it("survives JSON nulls from couch and keeps probing (close review BR-1)", function()
            vim.env.FAKE_COUCH_STATUS = '{"Code":"ok","Status":{"Owed":null}}'
            vim.env.FAKE_COUCH_ACTORS = '{"Code":"ok","Actors":[{"Binding":null},{"Binding":{"Slot":"ops:0"},"Known":true,"LastActivity":null}]}'
            open(header)
            vim.wait(300)
            assert.equals(0, #pings())
            vim.env.FAKE_COUCH_STATUS = '{"Code":"ok","Status":null}'
            vim.wait(300)
            assert.equals(0, #pings())
            vim.env.FAKE_COUCH_STATUS = owed(6)
            vim.wait(300)
            assert.equals(0, #pings())       -- the null actor fields still decode
            vim.env.FAKE_COUCH_ACTORS = actors("ops:0", true)
            assert.is_true(vim.wait(2000, function() return #pings() == 1 end))
        end)

        it("pings while the operator holds the lock too: owed events alone decide (#315)", function()
            vim.env.FAKE_COUCH_STATUS = owed(10)
            vim.fn.writefile({ "holder: operator" }, file .. ".lock")
            open(header)
            assert.is_true(vim.wait(2000, function() return #pings() == 1 end))
        end)
    end)

    it("a file reopened during an operator turn still turns stale", function()
        p.config.session_sync_stale_minutes = 0.001
        vim.fn.writefile({ "holder: operator" }, file .. ".lock")
        open(header)
        assert.is_true(vim.wait(2000, function()
            return winbar() == "%#ParleySessionSyncStale# unsent edits, Alt+Return to submit%="
        end))
    end)

    it("plain markdown keeps the review action on <M-CR>", function()
        open({ "# just notes" })
        local fallback_called = false
        ss.dispatch(buf, function() fallback_called = true end)()
        assert.is_true(fallback_called)
        assert.is_not_nil(keymap_cb("<M-CR>"))
        assert.is_false(exists(file .. ".lock"))
        assert.equals("", winbar())
    end)
end)
