-- Native :checktime dispatch, including a dirty document attached only after
-- its edit: that operator text has no admission history or confirmed lock.
local arrival = require("tests.helpers.arrival")
local Embedded = require("tests.helpers.embedded_nvim")
local FakeCouch = require("tests.helpers.fake_couch")

describe("registered FileChangedShell ownership", function()
    local child, root, file, original, generation
    local function exec(code, ...) return child:exec(code, ...) end
    local function wait_for(code)
        assert.is_true(vim.wait(arrival.MS, function() return exec(code) end), code)
    end
    local function external_write(lines)
        generation = generation + 1
        vim.fn.writefile(lines, file)
        -- File sizes need not differ, and the filesystem's mtime resolution
        -- must not turn repeated foreign generations into a missed event.
        assert(vim.uv.fs_utime(file, generation, generation))
    end
    local function open(kind, dirty)
        file = kind == "side" and root .. "/status.side/notes.md" or root .. "/status.md"
        vim.fn.mkdir(vim.fn.fnamemodify(file, ":h"), "p")
        original = {"---", "type: " .. (kind == "side" and "prose" or "session-sync"),
            "couch-owner: ops:0", "---", ""}
        for line = 6, 90 do original[line] = "body line " .. line end
        vim.fn.writefile(original, file)
        exec([[
            local path, dirty = ...
            _G.path = path
            vim.cmd("edit " .. vim.fn.fnameescape(path))
            if dirty then
                -- Actual native edit before attachment; no model/state setup.
                vim.api.nvim_win_set_cursor(0, {30, 0})
                vim.cmd("normal! Ioperator ")
                assert(vim.bo.modified)
            end
            local ss = require("parley.session_sync")
            ss.POLL_MS = 60000 -- only native checktime observes these writes
            ss.attach(0, { ID = "registered-411", File = path, Owner = "ops:0" })
            _G.events = {}
            vim.api.nvim_create_autocmd("FileChangedShell", {
                buffer = 0, callback = function()
                    events[#events + 1] = { kind = "changed", choice = vim.v.fcs_choice }
                    -- Prevent RED from entering Neovim's blocking ask UI.
                    -- The recorded choice must still prove Parley did not ask.
                    if vim.v.fcs_choice == "ask" then vim.v.fcs_choice = "" end
                end,
            })
            vim.api.nvim_create_autocmd("FileChangedShellPost", {
                buffer = 0, callback = function()
                    events[#events + 1] = { kind = "post", modified = vim.bo.modified }
                end,
            })
        ]], file, dirty)
    end
    local function checktime()
        exec("vim.cmd('checktime')")
        local events = exec("return events")
        local last_changed
        for _, event in ipairs(events) do
            if event.kind == "changed" then last_changed = event end
        end
        assert.is_not_nil(last_changed, "checktime did not dispatch a native change event")
        assert.is_not.equals("ask", last_changed.choice, "registered file delegated to Neovim's prompt")
    end
    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname())
        vim.fn.mkdir(root, "p")
        generation = 1800000000
        FakeCouch.write(root, root .. "/sent", root .. "/argv")
        child = Embedded.start({ ui = { 100, 26 } })
        exec([[
            local root = ...
            vim.env.PATH = root .. "/bin:" .. vim.env.PATH
            vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
            vim.env.FAKE_COUCH_STATUS = nil
            vim.env.FAKE_COUCH_ACTORS = '{"Actors":[]}'
            _G.notifications = {}
            vim.notify = function(message) notifications[#notifications + 1] = message end
        ]], root)
    end)
    after_each(function()
        if child then child:stop() end
        vim.fn.delete(root, "rf")
    end)

    for _, kind in ipairs({"session", "side"}) do
        it("reloads a clean registered " .. kind .. " with every window's cursor and view intact", function()
            open(kind, false)
            local before = exec([[
                vim.cmd("split")
                local wins = vim.fn.win_findbuf(0)
                _G.views = {}
                for index, win in ipairs(wins) do
                    vim.api.nvim_win_call(win, function()
                        vim.api.nvim_win_set_cursor(win, {20 + index * 20, 3})
                        vim.cmd("normal! zt")
                        views[#views + 1] = {win = win, view = vim.fn.winsaveview()}
                    end)
                end
                return views
            ]])
            local foreign = vim.deepcopy(original)
            foreign[90] = "agent's revised final line"
            external_write(foreign)
            checktime()
            assert.same(foreign, exec("return vim.api.nvim_buf_get_lines(0,0,-1,false)"))
            for _, saved in ipairs(before) do
                assert.same(saved.view, exec("local win=...; return vim.api.nvim_win_call(win, vim.fn.winsaveview)", saved.win))
            end
            assert.is_false(exec("return vim.bo.modified"))
            assert.is_nil(vim.uv.fs_stat(file .. ".clobbered"))
            assert.same({}, exec("return notifications"))
        end)

        for _, writes in ipairs({2, 4}) do
            it("keeps a dirty registered " .. kind .. " across " .. writes .. " foreign generations", function()
                open(kind, true)
                assert.is_nil(vim.uv.fs_stat(file .. ".lock"), "fixture unexpectedly acquired a turn")
                local operator = exec("return vim.api.nvim_buf_get_lines(0,0,-1,false)")
                for round = 1, writes do
                    local foreign = vim.deepcopy(original)
                    foreign[30] = "agent generation " .. round
                    external_write(foreign)
                    checktime()
                    assert.same(operator, exec("return vim.api.nvim_buf_get_lines(0,0,-1,false)"),
                        "operator text replaced on generation " .. round)
                    wait_for("return vim.fn.filereadable(path .. '.clobbered') == 1")
                    assert.is_true(vim.wait(arrival.MS, function()
                        return vim.deep_equal(foreign, vim.fn.readfile(file .. ".clobbered"))
                    end), "foreign generation " .. round .. " was not preserved")
                    assert.same(operator, vim.fn.readfile(file))
                    assert.same(operator, exec("return vim.api.nvim_buf_get_lines(0,0,-1,false)"))
                    local notices = exec("return notifications")
                    assert.equals(round, #notices, "foreign generation was lost or preserved twice")
                    assert.is_not_nil(notices[round]:find("operator's copy was kept", 1, true))
                    assert.is_not_nil(notices[round]:find("while the operator had local changes", 1, true),
                        "preservation without a confirmed lock must not claim the lock was held")
                    -- A repeated native check of the same generation is a no-op.
                    exec("vim.cmd('checktime')")
                    assert.equals(round, exec("return #notifications"))
                end
                local events = exec("return events")
                local changed, post = 0, 0
                for _, event in ipairs(events) do
                    if event.kind == "changed" then changed = changed + 1 else post = post + 1 end
                end
                assert.equals(writes, changed)
                assert.equals(0, post, "suppressed native handling must not masquerade as a reload")
            end)
        end
    end

    it("leaves both operator buffer and agent disk copy intact when preservation fails", function()
        open("side", true)
        local operator = exec("return vim.api.nvim_buf_get_lines(0,0,-1,false)")
        vim.fn.mkdir(file .. ".clobbered", "p")
        local foreign = vim.deepcopy(original)
        foreign[30] = "agent copy that cannot be copied"
        external_write(foreign)
        checktime()
        wait_for("return #notifications == 1")
        assert.same(foreign, vim.fn.readfile(file))
        assert.same(operator, exec("return vim.api.nvim_buf_get_lines(0,0,-1,false)"))
        assert.is_true(exec("return vim.bo.modified"))
        assert.is_not_nil(exec("return notifications[1]"):find("could not be kept", 1, true))
        exec("vim.cmd('checktime')")
        assert.equals(1, exec("return #notifications"))
    end)

    it("drops deferred preservation after the registered attachment is detached", function()
        open("side", true)
        local operator = exec("return vim.api.nvim_buf_get_lines(0,0,-1,false)")
        exec([[
            vim.api.nvim_create_autocmd("FileChangedShell", {
                buffer = 0, once = true, callback = function()
                    require("parley.session_sync").detach(0)
                end,
            })
        ]])
        local foreign = vim.deepcopy(original)
        foreign[30] = "agent write at attachment handoff"
        external_write(foreign)
        checktime()
        exec("vim.schedule(function() _G.detached_settled = true end)")
        wait_for("return detached_settled == true")
        assert.same(foreign, vim.fn.readfile(file))
        assert.same(operator, exec("return vim.api.nvim_buf_get_lines(0,0,-1,false)"))
        assert.is_nil(vim.uv.fs_stat(file .. ".clobbered"))
        assert.same({}, exec("return notifications"))
    end)

    it("leaves an unregistered Markdown file to native autoread without installing a handler", function()
        file = root .. "/plain.md"
        vim.fn.writefile({"plain original"}, file)
        exec([[
            local path = ...
            vim.cmd("edit " .. vim.fn.fnameescape(path))
            require("parley.session_sync").attach(0) -- no identity or typed header: not admitted
            vim.bo.autoread = true
            assert(#vim.api.nvim_get_autocmds({event="FileChangedShell",buffer=0}) == 0)
        ]], file)
        external_write({"plain agent rewrite"})
        exec("vim.cmd('checktime')")
        assert.same({"plain agent rewrite"}, exec("return vim.api.nvim_buf_get_lines(0,0,-1,false)"))
        assert.same({}, exec("return notifications"))
        assert.is_nil(vim.uv.fs_stat(file .. ".clobbered"))
    end)
end)
