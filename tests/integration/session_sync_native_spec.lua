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
    local function locked()
        assert.is_true(vim.wait(1000, function()
            local ok, lines = pcall(vim.fn.readfile, file .. ".lock")
            return ok and lines[1] == "holder: operator"
        end), "complete operator lock missing")
    end
    local function open(autosave, undo, slow_watch)
        exec([[
            local path, autosave, undo, slow_watch = ...
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
            require("parley").setup_markdown_keymaps(session)
            vim.api.nvim_win_set_cursor(0, {8,0})
        ]], file, autosave, undo, slow_watch)
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
            vim.env.FAKE_COUCH_ACTORS = '{"Actors":[]}'
        ]], vim.fn.getcwd(), root)
    end)
    after_each(function()
        vim.fn.jobstop(child)
        vim.fn.jobwait({child}, 1000)
        vim.fn.delete(root, "rf")
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
            assert.is_false(exec("return require('parley.session_sync').is_session_sync(0)"))
        end)
    end

    for _, reloaded in ipairs({false, true}) do
        it("dd then undo releases silently, redo retakes" .. (reloaded and " after reload" or ""), function()
            open(false)
            if reloaded then agent_reload() end
            local disk = vim.fn.readfile(file)
            keys("dd"); locked()
            keys("u")
            wait_for("return not vim.bo.modified")
            assert.is_true(vim.wait(1000, function() return not exists() end), "clean undo kept the lock")
            assert.same(disk, exec("return vim.api.nvim_buf_get_lines(0,0,-1,false)"))
            assert.same(disk, vim.fn.readfile(file))
            assert.is_nil(vim.uv.fs_stat(sent_file), "undo must not notify owner")
            keys("<C-r>"); locked()
            assert.is_true(exec("return vim.bo.modified"))
        end)
    end

    it("multi-step undo keeps the lock until the clean baseline", function()
        open(false)
        keys("dd"); locked()
        keys("x"); wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'econd bullet'")
        keys("u"); wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'second bullet'")
        assert.is_true(exists())
        keys("u"); wait_for("return not vim.bo.modified")
        assert.is_true(vim.wait(1000, function() return not exists() end))
        agent_reload()
    end)

    it("submit then agent reload then first body dd still locks before auto-save", function()
        open(true)
        keys("dd"); locked()
        exec("require('parley.session_sync').submit(vim.api.nvim_get_current_buf())")
        assert.is_true(vim.wait(2000, function() return not exists() end))
        assert.is_true(vim.wait(2000, function() return vim.uv.fs_stat(sent_file) ~= nil end))
        agent_reload()
        keys("dd"); locked()
        wait_for("return _G.pre_save_lock ~= nil")
        assert.equals(1, exec("return _G.pre_save_lock"))
    end)

    for _, change in ipairs({"overwrite", "delete", "unkeepable overwrite"}) do
        it("clean undo preserves pending foreign " .. change .. " before release", function()
            open(false, false, true) -- release callback must handle it before the watcher.
            local original = vim.fn.readfile(file)
            keys("dd"); locked()
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
            wait_for("return not vim.bo.modified")
            if change == "overwrite" then
                assert.is_true(vim.wait(1000, function()
                    return vim.fn.filereadable(file .. ".clobbered") == 1
                end), "foreign text was not preserved")
                assert.equals("foreign agent text", vim.fn.readfile(file .. ".clobbered")[8])
                assert.same(original, vim.fn.readfile(file))
            elseif change == "delete" then
                assert.is_true(vim.wait(1000, function() return vim.fn.filereadable(file) == 1 end), "deleted file was not restored")
                assert.same(original, vim.fn.readfile(file))
            else
                assert.is_true(vim.wait(1000, function() return vim.fn.filereadable(sent_file) == 1 end))
                assert.equals("foreign agent text", vim.fn.readfile(file)[8])
            end
            locked()
            assert.is_true(vim.wait(1000, function() return vim.fn.filereadable(sent_file) == 1 end))
            assert.matches("session-sync violation:", vim.fn.readfile(sent_file)[1], 1, true)
        end)
    end

    for _, undecided in ipairs({"ignored", "errored"}) do
        it("clean undo keeps undecided foreign writes locked when checktime is " .. undecided, function()
            open(false, false, true)
            local original = vim.fn.readfile(file)
            keys("dd"); locked()
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
            wait_for("return not vim.bo.modified")
            exec("vim.schedule(function() _G.reconciled=true end)")
            wait_for("return _G.reconciled == true")
            assert.is_true(exists(), "an undecided disk change must retain protection")
            assert.is_false(vim.fn.filereadable(file .. ".clobbered") == 1)
            assert.equals("unclassified foreign text", vim.fn.readfile(file)[8])
            exec("vim.cmd=real_cmd; vim.o.eventignore=''; vim.cmd('checktime')")
            assert.is_true(vim.wait(1000, function() return vim.fn.filereadable(file .. ".clobbered") == 1 end))
            assert.same(original, vim.fn.readfile(file))
            locked()
        end)
    end

    it("an explicit save retains the turn, undo away from that save remains locked", function()
        open(false)
        keys("dd"); locked()
        exec("vim.cmd('silent write')")
        assert.is_false(exec("return vim.bo.modified"))
        vim.wait(100)
        assert.is_true(exists())
        keys("u"); wait_for("return vim.bo.modified")
        assert.is_true(exists())
    end)
end)
