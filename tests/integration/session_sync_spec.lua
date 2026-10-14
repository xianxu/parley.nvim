-- #313/#315: session-sync files — the operator's lock is the only lock: the
-- first edit takes it, <M-CR> saves, deletes it and tells the agent over couch;
-- a clean buffer follows the agent's writes. Owed work (couch's owed events)
-- and the operator's turn are rendered in the winbar and StatusLine.
local ss = require("parley.session_sync")
local uv = vim.uv or vim.loop

describe("session-sync buffer", function()
    local root, file, argv_file, log_file, saved_path, saved_poll, saved_check, saved_thread, buf
    local p = require("parley")

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
        require("tests.helpers.fake_couch").write(root, log_file, argv_file)
        saved_path, saved_poll, saved_check = vim.env.PATH, ss.POLL_MS, ss.PING_CHECK_MS
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        -- Outside pair unless a spec says otherwise (the suite itself may run
        -- inside a pair slot, whose env names a real thread).
        saved_thread = { vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG }
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
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
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = saved_thread[1], saved_thread[2]
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

    describe("inside a pair slot, owner: is a check (#316)", function()
        -- Two live slots; this editor runs in the one bound to scope s1/tag t1.
        local function slots()
            return vim.json.encode({ Code = "ok", Actors = {
                { Binding = { Slot = "ops:0", Scope = "s0", Tag = "t0" }, Known = true },
                { Binding = { Slot = "parley.nvim:1", Scope = "s1", Tag = "t1" }, Known = true },
            } })
        end
        before_each(function()
            vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = "s1", "t1"
            vim.env.FAKE_COUCH_ACTORS = slots()
        end)

        it("an owner that is another slot: warned, nothing saved, lock kept, nothing sent", function()
            open(header) -- owner: ops:0
            edit("- edited")
            local warned
            local saved_notify = vim.notify
            vim.notify = function(msg) warned = msg end
            keymap_cb("<M-CR>")()
            assert.is_true(vim.wait(2000, function() return warned ~= nil end))
            vim.notify = saved_notify
            assert.truthy(warned:find("owner ops:0 is not this slot's agent (parley.nvim:1)", 1, true))
            assert.equals("holder: operator", holder())
            assert.is_true(vim.bo[buf].modified)
            vim.wait(100)
            assert.same({}, sent())
        end)

        it("an owner that is this slot (by a prefix spelling) submits", function()
            local h = vim.deepcopy(header)
            h[3] = "owner: parley:1"
            open(h)
            edit("- edited")
            keymap_cb("<M-CR>")()
            assert.is_true(vim.wait(2000, function() return #sent() == 1 end))
            assert.equals("parley:1|submitted: " .. file, sent()[1])
            assert.is_false(exists(file .. ".lock"))
        end)

        it("a slot couch cannot resolve: nothing is submitted", function()
            vim.env.FAKE_COUCH_ACTORS = vim.json.encode({ Code = "ok", Actors = {} })
            open(header)
            edit("- edited")
            keymap_cb("<M-CR>")()
            vim.wait(200)
            assert.same({}, sent())
            assert.equals("holder: operator", holder())
        end)
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

    -- The operator's config auto-saves markdown from a non-nested autocmd:
    -- that write fires no BufWritePost (#317).
    local function auto_save()
        vim.api.nvim_create_autocmd("TextChanged", {
            group = vim.api.nvim_create_augroup("SpecAutoSave", { clear = true }),
            buffer = buf,
            callback = function() vim.cmd("silent! write") end,
        })
    end
    local function typed(text)
        edit(text)
        vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
    end

    it("the operator's own auto-save from a non-nested autocmd is no violation (#317)", function()
        open(header)
        auto_save()
        typed("- first comment")
        assert.equals("holder: operator", holder())
        assert.equals("- first comment", vim.fn.readfile(file)[8])
        assert.is_false(vim.bo[buf].modified)
        typed("- second comment")
        vim.wait(300)                    -- several watch ticks
        assert.is_false(exists(file .. ".clobbered"))
        assert.equals(0, #sent())
        assert.equals("%#ParleySessionSyncOperator# your turn, Alt+Return to submit%=", winbar())
        keymap_cb("<M-CR>")()            -- submit sees no foreign write either
        assert.is_true(vim.wait(2000, function() return #sent() == 1 end))
        assert.matches("submitted: ", sent()[1], 1, true)
        assert.is_false(exists(file .. ".clobbered"))
    end)

    -- The TL's two reports (11:26, 11:34): an agent write, the clean buffer
    -- reloads, the operator takes the lock, and their first save was flagged.
    for _, case in ipairs({
        { name = "the watch", reload = function() end },
        { name = ":checktime", reload = function() vim.cmd("checktime") end },
    }) do
        for _, save in ipairs({ "auto-save", ":w" }) do
            it(("agent write, reload by %s, first edit, then the operator's %s: no violation (#317)")
                :format(case.name, save), function()
                if case.name == ":checktime" then ss.POLL_MS = 60000 end
                open(header)
                if save == "auto-save" then auto_save() end
                agent_write("- TL's update")
                case.reload()
                assert.is_true(vim.wait(2000, function()
                    return vim.api.nvim_buf_get_lines(buf, 7, 8, false)[1] == "- TL's update"
                end))
                vim.api.nvim_buf_set_lines(buf, 8, 8, false, { "- operator comment" })
                vim.api.nvim_exec_autocmds("BufModifiedSet", { buffer = buf })
                assert.equals("holder: operator", holder())
                if save == "auto-save" then
                    vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
                else
                    vim.cmd("silent write")
                end
                assert.same({ "- TL's update", "- operator comment" }, vim.list_slice(vim.fn.readfile(file), 8, 9))
                vim.wait(300)            -- watch ticks (when on), and the first-edit check
                vim.cmd("checktime")
                vim.wait(50)
                assert.is_false(exists(file .. ".clobbered"))
                assert.equals(0, #sent())
                assert.equals("%#ParleySessionSyncOperator# your turn, Alt+Return to submit%=", winbar())
                -- Submit reads the baseline even with the watch off.
                keymap_cb("<M-CR>")()
                assert.is_true(vim.wait(2000, function() return #sent() == 1 end))
                assert.matches("|submitted: ", sent()[1], 1, true)
                assert.is_false(exists(file .. ".clobbered"))
            end)
        end
    end

    -- The refined report: it was the first Alt+Return after the TL's write
    -- that was flagged, and that submit was dropped; a second one submitted.
    for _, save in ipairs({ "plain", "auto-save" }) do
        it(("agent write, operator edits, one Alt+Return submits with no violation (%s, #317)"):format(save), function()
            open(header)
            if save == "auto-save" then auto_save() end
            agent_write("- TL's update")
            assert.is_true(vim.wait(2000, function()
                return vim.api.nvim_buf_get_lines(buf, 7, 8, false)[1] == "- TL's update"
            end))
            vim.api.nvim_buf_set_lines(buf, 8, 8, false, { "- operator comment" })
            vim.api.nvim_exec_autocmds("BufModifiedSet", { buffer = buf })
            vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
            assert.equals("holder: operator", holder())
            vim.wait(50)
            keymap_cb("<M-CR>")()
            assert.is_false(exists(file .. ".lock"))
            assert.is_true(vim.wait(2000, function() return #sent() == 1 end))
            assert.matches("|submitted: " .. file, sent()[1], 1, true)
            assert.is_false(exists(file .. ".clobbered"))
            assert.same({ "- TL's update", "- operator comment" }, vim.list_slice(vim.fn.readfile(file), 8, 9))
        end)
    end

    -- Without Neovim's verdict a moved mtime stays undecided: never adopted
    -- as the operator's own (close review BR-1).
    for _, how in ipairs({ "checktime errors", "eventignore" }) do
        it(("a foreign write is not adopted when %s, and is caught once Neovim can say (#317)"):format(how), function()
            open(header)
            edit("- edited")
            vim.cmd("silent write")
            local real_cmd, saved_ei = vim.cmd, vim.o.eventignore
            if how == "checktime errors" then
                vim.cmd = setmetatable({}, { __index = real_cmd, __call = function(_, c)
                    if type(c) == "string" and c:match("^checktime") then error("E11: stubbed") end
                    return real_cmd(c)
                end })
            else
                vim.o.eventignore = "FileChangedShell"
            end
            agent_write("- TL ignored the lock")
            vim.wait(300)                -- watch ticks without a verdict
            vim.cmd, vim.o.eventignore = real_cmd, saved_ei
            assert.is_false(exists(file .. ".clobbered"))
            assert.is_true(vim.wait(2000, function() return exists(file .. ".clobbered") end))
            assert.equals("- edited", vim.fn.readfile(file)[8])
            assert.equals("- TL ignored the lock", vim.fn.readfile(file .. ".clobbered")[8])
        end)
    end

    it("an agent write under the lock over a just-auto-saved clean buffer is still a violation (#317)", function()
        open(header)
        auto_save()
        typed("- my comment")
        assert.is_false(vim.bo[buf].modified)
        agent_write("- TL ignored the lock")
        assert.is_true(vim.wait(2000, function() return exists(file .. ".clobbered") end))
        assert.equals("- my comment", vim.api.nvim_buf_get_lines(buf, 7, 8, false)[1])
        assert.equals("- my comment", vim.fn.readfile(file)[8])
        assert.equals("- TL ignored the lock", vim.fn.readfile(file .. ".clobbered")[8])
        assert.is_true(vim.wait(2000, function() return #sent() == 1 end))
    end)

    it("the same write noticed by :checktime does not reload over the operator's text (#317)", function()
        ss.POLL_MS = 60000
        open(header)
        auto_save()
        typed("- my comment")
        agent_write("- TL ignored the lock")
        vim.cmd("checktime")
        assert.is_true(vim.wait(2000, function() return exists(file .. ".clobbered") end))
        assert.equals("- my comment", vim.api.nvim_buf_get_lines(buf, 7, 8, false)[1])
        assert.equals("- my comment", vim.fn.readfile(file)[8])
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

        describe("write-age baseline (#321)", function()
            local real_time, real_system, now, initial
            local function stamp(at) return os.date("!%Y-%m-%dT%H:%M:%SZ", at) end
            local function status(write, delivery)
                vim.env.FAKE_COUCH_STATUS = vim.json.encode({ Code = "ok", Status = {
                    LastWrite = write, Owed = delivery == false and {} or {
                        { ID = "delivery", At = stamp(delivery or initial - 3600) },
                    },
                } })
            end
            local function settle() vim.wait(300) end
            before_each(function()
                real_time, real_system = os.time, vim.system
                initial = real_time()
                now = initial
                os.time = function() return now end -- luacheck: ignore 122
                p.config.session_sync_ping_minutes = dofile("lua/parley/config.lua").session_sync_ping_minutes
                vim.env.FAKE_COUCH_ACTORS = actors("ops:0", true)
            end)
            after_each(function() os.time, vim.system = real_time, real_system end) -- luacheck: ignore 122

            it("waits fifteen minutes after a write, pings once, and only a new write rearms", function()
                status(stamp(initial))
                open(header)
                now = initial + 899
                settle()
                assert.equals(0, #pings())
                now = initial + 900
                assert.is_true(vim.wait(2000, function() return #pings() == 1 end))
                status(stamp(initial), initial - 1800) -- old delivery folded; another remains
                settle()
                assert.equals(1, #pings())
                status(stamp(now)) -- write folds nothing
                now = initial + 1799
                settle()
                assert.equals(1, #pings())
                now = initial + 1800
                assert.is_true(vim.wait(2000, function() return #pings() == 2 end))
            end)

            it("also uses fifteen minutes when configuration is absent", function()
                p.config.session_sync_ping_minutes = nil
                status(stamp(initial))
                open(header)
                now = initial + 899
                settle()
                assert.equals(0, #pings())
                now = initial + 900
                assert.is_true(vim.wait(2000, function() return #pings() == 1 end))
            end)

            for _, source in ipairs({ "LastWrite", "Owed.At", "LastActivity" }) do
                it("does not ping with an impossible calendar date in " .. source, function()
                    status(stamp(initial - 900))
                    local data = vim.json.decode(vim.env.FAKE_COUCH_STATUS)
                    local invalid = "2020-00-00T00:00:00Z"
                    if source == "LastWrite" then data.Status.LastWrite = invalid
                    elseif source == "Owed.At" then data.Status.LastWrite = nil; data.Status.Owed[1].At = invalid
                    else
                        local live = vim.json.decode(actors("ops:0", true))
                        live.Actors[1].LastActivity = invalid
                        vim.env.FAKE_COUCH_ACTORS = vim.json.encode(live)
                    end
                    vim.env.FAKE_COUCH_STATUS = vim.json.encode(data)
                    open(header)
                    settle()
                    assert.equals(0, #pings())
                end)
            end

            it("a recent write postpones the first ping despite older obligations", function()
                status(stamp(initial - 899))
                open(header)
                settle()
                assert.equals(0, #pings())
                status(stamp(initial))
                agent_write("- updated without folding old deliveries")
                now = initial + 1
                settle()
                assert.equals(0, #pings())
            end)

            it("falls back when LastWrite is absent without rearming on delivery changes", function()
                status(nil, initial - 900)
                open(header)
                assert.is_true(vim.wait(2000, function() return #pings() == 1 end))
                status(nil, initial - 1000)
                settle()
                assert.equals(1, #pings())
                status(nil, false)
                settle()
                status(nil, initial - 1100)
                settle()
                assert.equals(1, #pings())
            end)

            it("honors a configured threshold measured from LastWrite", function()
                p.config.session_sync_ping_minutes = 2
                status(stamp(initial))
                open(header)
                now = initial + 119
                settle()
                assert.equals(0, #pings())
                now = initial + 120
                assert.is_true(vim.wait(2000, function() return #pings() == 1 end))
            end)

            for _, phase in ipairs({ "--actors", "--session-sync" }) do
                for _, interruption in ipairs({ "operator lock", "file write" }) do
                    it("postpones a ping for " .. interruption .. " during " .. phase, function()
                        local pending, response
                        vim.system = function(argv, opts, cb)
                            if argv[2] == phase and not pending then
                                pending = cb
                                response = phase == "--actors" and actors("ops:0", true) or vim.env.FAKE_COUCH_STATUS
                                return {}
                            end
                            return real_system(argv, opts, cb)
                        end
                        status(stamp(initial - 900))
                        open(header)
                        assert.is_true(vim.wait(2000, function() return pending ~= nil end))
                        ss.PING_CHECK_MS = 60000 -- observe this completion alone
                        if interruption == "operator lock" then
                            edit("- operator editing")
                        else
                            agent_write("- owner update")
                            status(stamp(initial))
                        end
                        pending({ code = 0, stdout = response })
                        settle()
                        assert.equals(0, #pings())
                        -- Admission failure did not consume this write generation.
                        os.remove(file .. ".lock")
                        vim.system = real_system
                        now = initial + 900
                        ss.PING_CHECK_MS = 20
                        assert.is_true(vim.wait(2000, function() return #pings() == 1 end))
                    end)
                end
            end

            it("does not infer stale work from invalid writes or failed status", function()
                status("invalid")
                open(header)
                settle()
                assert.equals(0, #pings())
                vim.env.FAKE_COUCH_STATUS = '{"Code":"delivery-gap","Status":{"Owed":[]}}'
                settle()
                assert.equals(0, #pings())
                status(stamp(initial - 900), false)
                settle()
                assert.equals(0, #pings())
            end)
        end)

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

        it("does not ping while the operator holds the lock (#321)", function()
            vim.env.FAKE_COUCH_STATUS = owed(10)
            vim.fn.writefile({ "holder: operator" }, file .. ".lock")
            open(header)
            vim.wait(300)
            assert.equals(0, #pings())
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

    -- What <M-CR> does in plain markdown is review_send's (#316,
    -- tests/integration/review_send_spec.lua); here: no session-sync state.
    it("plain markdown keeps <M-CR> and gets no lock or band", function()
        open({ "# just notes" })
        assert.is_false(ss.is_session_sync(buf))
        assert.is_not_nil(keymap_cb("<M-CR>"))
        assert.is_false(exists(file .. ".lock"))
        assert.equals("", winbar())
    end)
end)
