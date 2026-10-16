-- Real input order matters: the operator's global auto-save is installed before
-- the session buffer, so TextChanged can save before session-sync sees it (#324).
describe("session-sync native edits", function()
    local child, root, file, sent_file
    local function exec(code, ...)
        return vim.rpcrequest(child, "nvim_exec_lua", code, { ... })
    end
    local function exists() return vim.uv.fs_stat(file .. ".lock") ~= nil end
    local function keys(value)
        vim.rpcrequest(child, "nvim_input", value)
    end
    local function wait_for(code)
        assert.is_true(vim.wait(2000, function() return exec(code) end), code)
    end
    -- A visible path may still be empty or partially written by the child.
    -- Every positive file assertion waits for its complete expected payload.
    local function payload(path, expected)
        local observed
        local ready = vim.wait(2000, function()
            local ok, lines = pcall(vim.fn.readfile, path, "b")
            if not ok or lines[#lines] ~= "" then return false end
            table.remove(lines) -- the terminating newline proves the last line arrived.
            observed = lines
            if not expected(lines) then return false end
            observed = lines
            return true
        end)
        assert.is_true(ready, "expected complete payload missing: " .. path .. " observed=" .. vim.inspect(observed))
        return observed
    end
    local function locked()
        payload(file .. ".lock", function(lines) return lines[1] == "holder: operator" end)
    end
    local function notified(kind)
        return payload(sent_file, function(lines)
            return #lines == 1 and lines[1]:find("ops:0|" .. kind .. ":", 1, true) == 1
        end)
    end
    local function open(autosave, undo, slow_watch, registered)
        exec([[
            local path, autosave, undo, slow_watch, registered = ...
            _G.path, _G.auto_save, _G.pre_save_lock = path, autosave, nil
            vim.api.nvim_create_autocmd("TextChanged", { pattern = "*.md", callback = function()
                _G.pre_save_lock = vim.fn.filereadable(path .. ".lock")
            end })
            -- Same callback/order as the operator's core/options.lua. The switch
            -- lets undo tests observe the unmodified state without auto-saving it.
            vim.api.nvim_create_autocmd({"InsertLeave", "TextChanged"}, {
                pattern = "*.md", callback = function()
                    if auto_save and vim.bo.modified and vim.fn.expand("%") ~= "" and vim.bo.buftype == "" then
                        vim.cmd("silent! write")
                    end
                end,
            })
            vim.cmd("edit " .. vim.fn.fnameescape(path))
            if undo then
                vim.api.nvim_buf_set_lines(0, 7, 8, false, {"saved version"})
                vim.cmd("silent write")
            end
            -- Seed dot in another buffer without changing the session file.
            local session = vim.api.nvim_get_current_buf()
            local scratch = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_set_current_buf(scratch)
            vim.api.nvim_buf_set_lines(0, 0, -1, false, {"seed"})
            vim.cmd("normal! x")
            vim.api.nvim_set_current_buf(session)
            vim.api.nvim_buf_delete(scratch, {force=true})
            vim.fn.setreg('a', 'pasted')
            local ss = require("parley.session_sync")
            ss.POLL_MS = slow_watch and 60000 or 20
            if registered then
                ss.attach(session, { ID = "doc-1", File = path, Owner = "ops:0", RegisteredOwner = "ops:0", RegisteredAt = "now" })
            else
                require("parley").setup_markdown_keymaps(session)
            end
            vim.api.nvim_win_set_cursor(0, {8,0})
        ]], file, autosave, undo, slow_watch, registered)
    end
    local function agent_reload(checktime)
        local lines = vim.fn.readfile(file)
        lines[8] = "agent reply"
        vim.fn.writefile(lines, file)
        if checktime then exec("vim.cmd('checktime')") end
        wait_for([[return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == "agent reply"]])
        assert.is_false(exec("return vim.bo.modified"))
        assert.is_false(exists())
        exec("vim.api.nvim_win_set_cursor(0,{8,0}); _G.pre_save_lock=nil")
    end
    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname())
        vim.fn.mkdir(root, "p")
        file, sent_file = root .. "/status.md", root .. "/sent"
        vim.fn.writefile({"---", "type: session-sync", "owner: ops:0", "operator: test", "---", "", "## Operator instructions", "first bullet", "second bullet", "third bullet"}, file)
        require("tests.helpers.fake_couch").write(root, sent_file, root .. "/argv")
        child = vim.fn.jobstart({vim.v.progpath, "--clean", "--embed", "--headless", "-i", "NONE"}, {rpc=true})
        vim.rpcrequest(child, "nvim_ui_attach", 100, 30, {rgb=true})
        exec([[
            local runtime, root = ...
            vim.opt.rtp:append(runtime)
            -- Capture notifications without builtin vim.notify's hit-enter UI;
            -- foreign-write warnings are asserted through the fake owner's log.
            _G.notifications = {}
            vim.notify = function(message) notifications[#notifications+1] = message end
            vim.env.PATH = root .. "/bin:" .. vim.env.PATH
            vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
            vim.env.FAKE_COUCH_STATUS = nil
            vim.env.FAKE_COUCH_LOG_DELAY = "0.1"
            vim.env.FAKE_COUCH_ACTORS = '{"Actors":[]}'
        ]], vim.fn.getcwd(), root)
    end)
    after_each(function()
        vim.fn.jobstop(child)
        vim.fn.jobwait({child}, 1000)
        vim.fn.delete(root, "rf")
    end)

    local function feedback(message, is_error)
        return exec([[
            local message, is_error = ...
            local ss = require("parley.session_sync")
            return type(ss.set_submission_feedback) == "function" and ss.set_submission_feedback(0, message, is_error)
        ]], message, is_error or false)
    end

    local function make_plain()
        vim.fn.writefile({"---", "type: prose", "owner: business", "operator: test", "---", "", "## Operator instructions", "first bullet", "second bullet", "third bullet"}, file)
    end
    it("keeps submitted feedback through own save and actual owed refresh until the next edit before autosave", function()
        make_plain(); open(true, false, false, true)
        assert.is_true(feedback("submitted to ops:0 · 14:23"))
        exec([[
            vim.cmd("silent write")
            vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = 0 })
            local couch = require("parley.couch")
            local run = couch.run
            couch.run = function(argv, callback, options)
                return run(argv, function(result)
                    callback(result)
                    if argv[2] == "--session-sync" and argv[3] == "status" then _G.feedback_status_refreshed = true end
                end, options)
            end
            vim.env.FAKE_COUCH_STATUS = vim.json.encode({ Code = "ok", Status = {
                Owed = { { ID = "owed", At = "2026-10-14T12:00:00Z" } }, LastWrite = "2026-10-14T11:00:00Z",
            } })
            require("parley.session_sync").PING_CHECK_MS = 0
        ]])
        wait_for("return _G.feedback_status_refreshed == true")
        assert.is_true(exec("return vim.wo.winbar:find('submitted to ops:0 · 14:23', 1, true) ~= nil"))
        exec([[
            require("parley.session_sync").PING_CHECK_MS = 60000
            local command = vim.cmd
            vim.cmd = setmetatable({}, { __call = function(_, value)
                if value == "silent! write" then
                    _G.feedback_at_auto_save = vim.wo.winbar:find("submitted to", 1, true) ~= nil
                end
                return command(value)
            end, __index = command })
        ]])
        keys("x"); locked()
        wait_for("return _G.feedback_at_auto_save ~= nil and not vim.bo.modified")
        assert.is_false(exec("return _G.feedback_at_auto_save"))
        assert.is_false(exec("return vim.wo.winbar:find('submitted to', 1, true) ~= nil"))
        payload(file, function(lines) return lines[8] == "irst bullet" end)
    end)

    it("clears submission feedback when a foreign write is observed and reloaded", function()
        make_plain(); open(false, false, false, true)
        assert.is_true(feedback("submitted to ops:0 · 14:23"))
        agent_reload(true)
        assert.is_false(exec("return vim.wo.winbar:find('submitted to', 1, true) ~= nil"))
        assert.equals("StatusLine:ParleySessionSyncFree", exec("return vim.wo.winhighlight"))
    end)

    it("renders bounded single-line literal error feedback and lets the next submission replace it", function()
        make_plain(); open(false, false, true, true)
        local message = "submit failed: bad%{1+1}\nnext\r\n" .. string.rep("x", 400)
        assert.is_true(feedback(message, true))
        local observed = exec([[
            local message = ...
            local view = require("parley.session_sync").feedback_view(message, true)
            vim.cmd("silent write")
            vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = 0 })
            return { view = view, rendered = vim.api.nvim_eval_statusline(vim.wo.winbar,
                { winid = 0, use_winbar = true, maxwidth = 1000 }).str, highlight = vim.wo.winhighlight,
                bounded = vim.fn.strchars(view.label) <= 160 }
        ]], message)
        assert.equals("DiagnosticError", observed.view.hl)
        assert.equals("StatusLine:DiagnosticError", observed.highlight)
        assert.is_true(observed.bounded)
        assert.is_nil(observed.view.label:find("[\r\n]"))
        assert.is_truthy(observed.rendered:find("bad%{1+1}", 1, true))
        assert.is_true(feedback("submitted to other:2 · 15:10"))
        assert.is_true(exec("return vim.wo.winbar:find('submitted to other:2 · 15:10', 1, true) ~= nil"))
        assert.is_false(exec("return vim.wo.winbar:find('submit failed:', 1, true) ~= nil"))
        assert.equals("StatusLine:DiagnosticOk", exec("return vim.wo.winhighlight"))
    end)

    it("does not attach or change the band when feedback is requested for an unattached buffer", function()
        local before = exec("return vim.wo.winbar")
        assert.equals("function", exec("return type(require('parley.session_sync').set_submission_feedback)"))
        assert.is_false(feedback("submit failed: offline", true))
        assert.equals(before, exec("return vim.wo.winbar"))
        assert.is_true(exec("return require('parley.session_sync').identity(0) == nil"))
    end)

    for _, case in ipairs({
        { name = "dd", input = "dd" }, { name = "x", input = "x" },
        { name = "p", input = '"ap' }, { name = "u", input = "u", undo = true },
        { name = "dot", input = "." },
    }) do
        it("registered plain " .. case.name .. " locks before existing auto-save", function()
            make_plain()
            open(true, case.undo, false, true)
            keys(case.input)
            locked()
            wait_for("return _G.pre_save_lock ~= nil and not vim.bo.modified")
            assert.equals(1, exec("return _G.pre_save_lock"))
            assert.equals("ops:0", exec("return require('parley.session_sync').identity(0).Owner"))
        end)
    end
    it("registered identity survives header edits and undo releases then redo retakes", function()
        make_plain()
        open(true, false, false, true)
        keys("ggdd")
        locked()
        wait_for("return not vim.bo.modified")
        assert.equals("ops:0", exec("return require('parley.session_sync').identity(0).Owner"))
        keys("u")
        assert.is_true(vim.wait(2000, function() return not exists() end))
        keys("<C-r>")
        locked()
    end)
    it("observed auto-saved edits acquire with the pre-edit baseline", function()
        make_plain()
        exec([[
            local path = ...
            vim.cmd("edit " .. vim.fn.fnameescape(path))
            local ss = require("parley.session_sync")
            ss.POLL_MS = 60000
            _G.before_hash = vim.fn.sha256(vim.json.encode(vim.api.nvim_buf_get_lines(0, 0, -1, false)))
            local st = vim.uv.fs_stat(path)
            _G.before_loaded = st.mtime.sec .. "." .. st.mtime.nsec
            vim.cmd("normal! Gdd")
            vim.cmd("silent write")
            ss.attach(vim.api.nvim_get_current_buf(), { ID="doc-1", File=path, Owner="ops:0", RegisteredOwner="ops:0", RegisteredAt="now" },
                { baseline=before_hash, loaded=before_loaded, outstanding=true })
        ]], file)
        assert.is_false(exec("return vim.bo.modified"))
        locked()
        keys("u")
        assert.is_true(vim.wait(2000, function() return not exists() end), "observed baseline must survive auto-save")
    end)
    it("prepares without unlock and registered send saves before releasing and routes confirmed owner", function()
        make_plain()
        open(false, false, false, true)
        keys("dd")
        locked()
        assert.is_true(exec("return require('parley.session_sync').prepare_submit(vim.api.nvim_get_current_buf())"))
        assert.is_true(exists())
        assert.is_false(exec("return vim.bo.modified"))
        exec([[
            local ss = require("parley.session_sync")
            ss.send_registered(vim.api.nvim_get_current_buf(), ss.identity(0), function(obj) _G.sent_code = obj.code end)
        ]])
        notified("submitted")
        wait_for("return _G.sent_code == 0")
        assert.is_false(exists())
        assert.equals("second bullet", vim.fn.readfile(file)[8])
    end)
    it("completes a refused registered send callback without releasing the turn", function()
        make_plain()
        open(false, false, true, true)
        keys("dd")
        locked()
        assert.is_true(exec([[
            local ss = require("parley.session_sync")
            local identity = ss.identity(0)
            identity.ID = "stale-id"
            local result
            local ok = ss.send_registered(0, identity, function(value) result = value end)
            return ok == false and result ~= nil and result.code ~= 0 and result.stderr ~= ""
        ]]))
        assert.is_true(exists())
        assert.is_nil(vim.uv.fs_stat(sent_file))
    end)

    it("detaches without unlocking and preserves user option overrides", function()
        make_plain()
        open(false, false, false, true)
        keys("dd")
        locked()
        exec([[
            vim.bo.autoread = true
            vim.wo.winbar = "operator band"
            require("parley.session_sync").detach(vim.api.nvim_get_current_buf())
        ]])
        assert.is_true(exists())
        assert.is_true(exec("return vim.bo.autoread"))
        assert.equals("operator band", exec("return vim.wo.winbar"))
        assert.is_true(exec("return require('parley.session_sync').identity(0) == nil"))
    end)
    it("moves protection exclusively and keeps acquisition baseline through metadata handoff", function()
        make_plain()
        open(false, false, true, true)
        keys("dd")
        locked()
        local next_file = root .. "/renamed.md"
        exec([[
            local new = ...
            local ss = require("parley.session_sync")
            _G.move_token = assert(ss.begin_move(vim.api.nvim_get_current_buf()))
            assert(ss.install_move_lock(vim.api.nvim_get_current_buf(), move_token, new))
            vim.cmd("saveas " .. vim.fn.fnameescape(new))
        ]], next_file)
        assert.is_not_nil(vim.uv.fs_stat(file .. ".lock"))
        assert.is_not_nil(vim.uv.fs_stat(next_file .. ".lock"))
        exec([[
            local new = ...
            local ss = require("parley.session_sync")
            assert(ss.finish_move(vim.api.nvim_get_current_buf(), move_token,
                {ID="doc-1", File=new, Owner="ops:0", RegisteredOwner="ops:0", RegisteredAt="now"}))
        ]], next_file)
        assert.is_nil(vim.uv.fs_stat(file .. ".lock"))
        file = next_file
        keys("u")
        assert.is_true(vim.wait(2000, function() return not exists() end), "move must preserve acquisition baseline")
    end)

    it("aborts a no-effect move when the buffer name aliases its canonical registry path", function()
        make_plain()
        local alias = root .. "/alias.md"
        assert(vim.uv.fs_symlink(file, alias))
        assert.is_true(exec([[
            local alias, canonical = ...
            vim.cmd("edit " .. vim.fn.fnameescape(alias))
            assert(vim.api.nvim_buf_get_name(0) == alias, "test requires a preserved lexical alias")
            local ss = require("parley.session_sync")
            ss.POLL_MS = 60000
            ss.attach(0, {ID="doc-1",File=canonical,Owner="ops:0",RegisteredOwner="ops:0",RegisteredAt="now"})
            local token = assert(ss.begin_move(0))
            return ss.abort_move(0, token)
        ]], alias, file))
        assert.is_nil(vim.uv.fs_stat(file .. ".lock"))
        assert.is_nil(vim.uv.fs_stat(alias .. ".lock"))
    end)

    it("releases synthetic move protection only at the unchanged acquisition baseline", function()
        make_plain()
        open(false, false, true, true)
        local destination = root .. "/synthetic.md"
        exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            local baseline = vim.fn.sha256(vim.json.encode(vim.api.nvim_buf_get_lines(0,0,-1,false)))
            assert(ss.acquire_observed(0, { baseline=baseline, outstanding=true }))
            local token = assert(ss.begin_move(0))
            assert(ss.install_move_lock(0, token, destination))
            vim.cmd("saveas " .. vim.fn.fnameescape(destination))
            local identity = ss.identity(0)
            identity.File = destination
            assert(ss.finish_move(0, token, identity))
            assert(ss.release_if_baseline(0))
        ]], destination)
        assert.is_nil(vim.uv.fs_stat(file .. ".lock"))
        assert.is_nil(vim.uv.fs_stat(destination .. ".lock"))
    end)

    it("retains synthetic move protection after a programmatic edit during migration", function()
        make_plain()
        open(false, false, true, true)
        local destination = root .. "/during.md"
        assert.is_false(exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            local baseline = vim.fn.sha256(vim.json.encode(vim.api.nvim_buf_get_lines(0,0,-1,false)))
            assert(ss.acquire_observed(0, { baseline=baseline, outstanding=true }))
            local token = assert(ss.begin_move(0))
            assert(ss.install_move_lock(0, token, destination))
            vim.cmd("saveas " .. vim.fn.fnameescape(destination))
            -- A forced plugin edit must retain the pre-move acquisition baseline.
            vim.api.nvim_buf_set_lines(0,7,8,false,{"programmatic edit"})
            assert(vim.fn.filereadable(destination .. ".lock") == 1)
            vim.cmd("silent write")
            local identity = ss.identity(0)
            identity.File = destination
            assert(ss.finish_move(0, token, identity))
            return ss.release_if_baseline(0)
        ]], destination))
        assert.is_not_nil(vim.uv.fs_stat(destination .. ".lock"))
        assert.equals("programmatic edit", vim.fn.readfile(destination)[8])
    end)

    it("restores journaled move protection after editor process death", function()
        make_plain()
        open(false, false, true, true)
        local baseline = vim.fn.readfile(file)
        keys("dd")
        locked()
        local destination = root .. "/restored.md"
        local proof = exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            local identity = ss.identity(0)
            local token = assert(ss.begin_move(0))
            local protection = { old_lock=token.lock, new_lock=token.lock, baseline=token.baseline }
            assert(ss.install_move_lock(0, token, destination))
            vim.cmd("saveas " .. vim.fn.fnameescape(destination))
            return { identity=identity, protection=protection }
        ]], destination)
        vim.fn.jobstop(child)
        vim.fn.jobwait({child}, 1000)
        child = vim.fn.jobstart({vim.v.progpath, "--clean", "--embed", "--headless", "-i", "NONE"}, {rpc=true})
        vim.rpcrequest(child, "nvim_ui_attach", 100, 30, {rgb=true})
        exec([[
            local runtime, root, destination, proof = ...
            vim.opt.rtp:append(runtime)
            vim.env.PATH = root .. "/bin:" .. vim.env.PATH
            vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
            vim.env.FAKE_COUCH_STATUS = nil
            vim.env.FAKE_COUCH_ACTORS = '{"Actors":[]}'
            vim.notify = function() end
            vim.cmd("edit " .. vim.fn.fnameescape(destination))
            local ss = require("parley.session_sync")
            ss.POLL_MS = 60000
            _G.restored_token = assert(ss.restore_move(0, proof.identity, destination, proof.protection))
            _G.original_identity = proof.identity
        ]], vim.fn.getcwd(), root, destination, proof)
        assert.is_not_nil(vim.uv.fs_stat(file .. ".lock"))
        exec([[
            local destination = ...
            local identity = vim.deepcopy(original_identity)
            identity.File = destination
            assert(require("parley.session_sync").finish_move(0, restored_token, identity))
        ]], destination)
        assert.is_nil(vim.uv.fs_stat(file .. ".lock"))
        file = destination
        exec("vim.api.nvim_buf_set_lines(0,0,-1,false,...)", baseline)
        assert.is_true(vim.wait(2000, function() return not exists() end), "restored acquisition baseline was lost")
    end)

    it("restore refuses a different destination lock without changing either lock", function()
        make_plain()
        open(false, false, true, true)
        keys("dd")
        locked()
        local destination = root .. "/occupied.md"
        vim.fn.writefile({ "holder: operator", "time: another editor" }, destination .. ".lock")
        local old_lock = vim.fn.readfile(file .. ".lock")
        assert.is_true(exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            local identity = ss.identity(0)
            local token = assert(ss.begin_move(0))
            ss.detach(0)
            local restored = ss.restore_move(0, identity, destination,
                { old_lock=token.lock, new_lock=token.lock, baseline=token.baseline })
            return restored == nil
        ]], destination))
        assert.same(old_lock, vim.fn.readfile(file .. ".lock"))
        assert.same({ "holder: operator", "time: another editor" }, vim.fn.readfile(destination .. ".lock"))
    end)

    it("restore permits completed OLD lock cleanup only with matching NEW proof", function()
        make_plain()
        open(false, false, true, true)
        keys("dd")
        locked()
        local destination = root .. "/handoff.md"
        exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            local identity = ss.identity(0)
            local token = assert(ss.begin_move(0))
            assert(ss.install_move_lock(0, token, destination))
            vim.cmd("saveas " .. vim.fn.fnameescape(destination))
            vim.fn.delete(identity.File .. ".lock")
            ss.detach(0)
            local restored = assert(ss.restore_move(0, identity, destination,
                { old_lock=token.lock, new_lock=token.lock, baseline=token.baseline }))
            identity.File = destination
            assert(ss.finish_move(0, restored, identity))
        ]], destination)
        assert.is_not_nil(vim.uv.fs_stat(destination .. ".lock"))
        assert.is_nil(vim.uv.fs_stat(file .. ".lock"))
    end)

    for _, reloaded in ipairs({"open", "watch", "checktime"}) do
        for _, case in ipairs({
            {name="dd", input="dd"}, {name="x", input="x"},
            {name="p", input='"ap'}, {name="u", input="u", undo=true},
            {name="dot", input="."}, {name="insert", input="iX"},
        }) do
            it(case.name .. " locks before the existing auto-save" .. " after " .. reloaded, function()
                open(true, case.undo)
                if reloaded ~= "open" then agent_reload(reloaded == "checktime") end
                keys(case.input)
                locked()
                if case.name == "insert" then
                    -- Let TextChangedI run before InsertLeave's auto-save.
                    wait_for("return vim.bo.modified")
                    keys("<Esc>")
                end
                wait_for("return _G.pre_save_lock ~= nil")
                assert.equals(1, exec("return _G.pre_save_lock"), "lock must precede auto-save")
                wait_for("return not vim.bo.modified")
                assert.is_true(exists(), "auto-save must retain the operator turn")
            end)
        end
    end

    for _, input in ipairs({"ggdd", "ggx", 'gg"ap'}) do
        it("keeps attached session identity through header edit " .. input, function()
            open(false)
            keys(input)
            locked()
            assert.is_true(exec("return require('parley.session_sync').is_session_sync(0)"))
        end)
    end

    for _, autosave in ipairs({false, true}) do
        for _, reloaded in ipairs({"open", "watch", "checktime"}) do
            it("undo releases acquisition baseline, redo retakes: " .. reloaded .. " autosave=" .. tostring(autosave), function()
                open(autosave)
                if reloaded ~= "open" then agent_reload(reloaded == "checktime") end
                local baseline = vim.fn.readfile(file)
                keys("dd"); locked()
                if autosave then wait_for("return not vim.bo.modified") end
                keys("u")
                wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == " .. string.format("%q", baseline[8]))
                assert.is_true(vim.wait(2000, function() return not exists() end), "baseline undo kept the lock")
                payload(file, function(lines) return vim.deep_equal(baseline, lines) end)
                assert.same({}, exec("return notifications"))
                assert.is_nil(vim.uv.fs_stat(sent_file), "undo must not notify owner")
                keys("<C-r>"); locked()
                if autosave then wait_for("return not vim.bo.modified") end
                assert.is_true(exists())
                keys("u")
                assert.is_true(vim.wait(2000, function() return not exists() end))
                agent_reload() -- next agent write succeeds and reaches the editor.
            end)
        end

        it("partial undo retains turn, full undo releases: autosave=" .. tostring(autosave), function()
            open(autosave)
            keys("dd"); locked()
            keys("x"); wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'econd bullet'")
            keys("u"); wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'second bullet'")
            exec("vim.schedule(function() _G.reconciled=true end)")
            wait_for("return _G.reconciled == true")
            assert.is_true(exists())
            keys("u")
            assert.is_true(vim.wait(2000, function() return not exists() end))
            agent_reload()
        end)
    end

    it("submit then agent reload then first body dd still locks before auto-save", function()
        open(true)
        keys("dd"); locked()
        exec("require('parley.session_sync').submit(vim.api.nvim_get_current_buf())")
        assert.is_true(vim.wait(2000, function() return not exists() end))
        notified("submitted")
        agent_reload()
        keys("dd"); locked()
        wait_for("return _G.pre_save_lock ~= nil")
        assert.equals(1, exec("return _G.pre_save_lock"))
    end)

    for _, autosave in ipairs({false, true}) do
        for _, change in ipairs({"overwrite", "delete", "unkeepable overwrite"}) do
            it("clean undo preserves pending foreign " .. change .. " before release autosave=" .. tostring(autosave), function()
                open(autosave, false, true) -- release callback must handle it before the watcher.
                local original = vim.fn.readfile(file)
                keys("dd"); locked()
                if autosave then wait_for("return not vim.bo.modified") end
                local foreign = vim.fn.readfile(file)
                exec([[
                    local change = ...
                    if change == "delete" then
                        vim.fn.delete(path)
                    else
                        local foreign = vim.fn.readfile(path)
                        foreign[8] = "foreign agent text"
                        vim.fn.writefile(foreign, path)
                        if change == "unkeepable overwrite" then
                            vim.fn.mkdir(path .. ".clobbered")
                        end
                    end
                    vim.cmd("normal! u")
                ]], change)
                wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'first bullet'")
                if change == "overwrite" then
                    foreign[8] = "foreign agent text"
                    payload(file .. ".clobbered", function(lines) return vim.deep_equal(foreign, lines) end)
                    payload(file, function(lines) return vim.deep_equal(original, lines) end)
                elseif change == "delete" then
                    payload(file, function(lines) return vim.deep_equal(original, lines) end)
                else
                    notified("session-sync violation")
                    assert.equals("foreign agent text", vim.fn.readfile(file)[8])
                end
                locked()
                notified("session-sync violation")
            end)
        end

        for _, undecided in ipairs({"ignored", "errored"}) do
            it("clean undo keeps undecided foreign writes locked when checktime is " .. undecided .. " autosave=" .. tostring(autosave), function()
                open(autosave, false, true)
                local original = vim.fn.readfile(file)
                keys("dd"); locked()
                if autosave then wait_for("return not vim.bo.modified") end
                local foreign = vim.fn.readfile(file)
                exec([[
                    local undecided = ...
                    local lines = vim.fn.readfile(path)
                    lines[8] = "unclassified foreign text"
                    vim.fn.writefile(lines, path)
                    _G.real_cmd = vim.cmd
                    if undecided == "ignored" then
                        vim.o.eventignore = "FileChangedShell"
                    else
                        vim.cmd = setmetatable({}, {__call=function(_, command)
                            if command:match("^checktime") then error("checktime unavailable") end
                            return real_cmd(command)
                        end, __index=real_cmd})
                    end
                    vim.cmd("normal! u")
                ]], undecided)
                wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'first bullet'")
                exec("vim.schedule(function() _G.reconciled=true end)")
                wait_for("return _G.reconciled == true")
                assert.is_true(exists(), "an undecided disk change must retain protection")
                assert.is_false(vim.fn.filereadable(file .. ".clobbered") == 1)
                assert.equals("unclassified foreign text", vim.fn.readfile(file)[8])
                exec("vim.cmd=real_cmd; vim.o.eventignore=''")
                if autosave then
                    -- With a failed auto-save, checktime need not repeat its
                    -- disk-change event. The contract here is to keep an
                    -- undecided write protected, without fabricating a retry.
                    locked()
                    foreign[8] = "unclassified foreign text"
                    payload(file, function(lines) return vim.deep_equal(foreign, lines) end)
                    return
                end
                exec("vim.cmd('checktime')")
                foreign[8] = "unclassified foreign text"
                payload(file .. ".clobbered", function(lines) return vim.deep_equal(foreign, lines) end)
                payload(file, function(lines) return vim.deep_equal(original, lines) end)
                locked()
            end)
        end

    end

    it("a pre-existing lock has no acquisition baseline and stays held after undo", function()
        vim.fn.writefile({"holder: operator", "time: 2026-10-14T00:00:00Z"}, file .. ".lock")
        open(true)
        keys("dd"); wait_for("return not vim.bo.modified")
        keys("u"); wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'first bullet'")
        exec("vim.schedule(function() _G.reconciled=true end)")
        wait_for("return _G.reconciled == true")
        locked()
    end)

    it("failed baseline save keeps the lock until a later successful reconciliation", function()
        open(false)
        keys("dd"); locked()
        exec([[
            vim.cmd("silent write")
            _G.real_cmd = vim.cmd
            vim.cmd = setmetatable({}, {__call=function(_, command)
                if command == "silent write" then error("write unavailable") end
                return real_cmd(command)
            end, __index=real_cmd})
        ]])
        keys("u"); wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'first bullet'")
        exec("vim.schedule(function() _G.reconciled=true end)")
        wait_for("return _G.reconciled == true")
        locked()
        payload(file, function(lines) return lines[8] == "second bullet" end)
        exec("vim.cmd=real_cmd")
        keys("x"); wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'irst bullet'")
        keys("u")
        assert.is_true(vim.wait(2000, function() return not exists() end))
        payload(file, function(lines) return lines[8] == "first bullet" end)
    end)

    it("explicit save retains changed turn, undo to acquisition baseline releases", function()
        open(false)
        keys("dd"); locked()
        exec("vim.cmd('silent write')")
        assert.is_false(exec("return vim.bo.modified"))
        vim.wait(100)
        assert.is_true(exists())
        keys("u")
        assert.is_true(vim.wait(2000, function() return not exists() end))
        payload(file, function(lines) return lines[8] == "first bullet" end)
    end)
end)
