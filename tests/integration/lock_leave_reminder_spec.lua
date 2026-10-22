local arrival = require("tests.helpers.arrival")
local band = require("parley.document_band")
local ss = require("parley.session_sync")

describe("lock leave reminder", function()
    local root, source, dest, win, saved, red, messages, timers, painted
    local function await(predicate) assert.is_true(vim.wait(arrival.MS, predicate, 5)) end
    local function edit() vim.api.nvim_buf_set_lines(source, -1, -1, false, { "held edit" }) end
    local function swap() vim.api.nvim_win_set_buf(win, dest) end
    local function label() return vim.wo[win].winbar end
    local function pulse()
        await(function() return #timers > 0 end)
        return timers[#timers]
    end
    local function tick(timer) timer.callback(); vim.wait(1) end
    local function finish(timer) for _ = 1, 6 do tick(timer) end end
    before_each(function()
        -- A repo root keeps each file's path band (#391) to its own name.
        root = vim.fn.tempname(); vim.fn.mkdir(root .. "/.git", "p")
        vim.fn.writefile({ "body" }, root .. "/held.md")
        vim.cmd("edit " .. vim.fn.fnameescape(root .. "/held.md"))
        source, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
        dest = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(dest, root .. "/destination.md")
        saved = { poll = ss.POLL_MS, notify = vim.notify, set = vim.api.nvim_set_option_value,
            pulse = band.PULSE_MS, timer = vim.uv.new_timer, path = vim.env.PATH,
            registry = vim.env.FAKE_COUCH_REGISTRY }
        -- Attaching asks Couch for the document's round (#383): the fake answers.
        require("tests.helpers.fake_couch").write(root, root .. "/sent", root .. "/argv")
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.FAKE_COUCH_REGISTRY = root .. "/registry.json"
        -- #408 validates acquisition against the registry, rather than making
        -- a local sidecar for an identity the producer has never registered.
        vim.fn.writefile({ vim.json.encode({ paths = {
            [root .. "/held.md"] = { ID = "fixture", File = root .. "/held.md", Owner = "ops:0" },
        }, moves = {} }) }, vim.env.FAKE_COUCH_REGISTRY)
        ss.POLL_MS, band.PULSE_MS = 100000, 15
        ss.attach(source, { File = root .. "/held.md", Owner = "ops:0", ID = "fixture" })
        red, messages, timers, painted = 0, {}, {}, {}
        -- Control only pulse timers; the session's idle/watch timers keep real IO.
        vim.uv.new_timer = function()
            local real, controlled = saved.timer(), false
            local timer = {}
            function timer.start(_, delay, interval, callback)
                if interval == band.PULSE_MS then
                    controlled, timer.callback = true, callback
                    timers[#timers + 1] = timer
                else real:start(delay, interval, callback) end
            end
            function timer.stop() timer.stopped = true; if not controlled then real:stop() end end
            function timer.close() timer.closed = true; real:close() end
            function timer.is_closing() return real:is_closing() end
            return timer
        end
        local previous
        vim.api.nvim_set_option_value = function(name, value, opts)
            if name == "winbar" and opts.win == win then
                if value ~= previous and value:find("ParleySessionSyncLeave", 1, true) then
                    red = red + 1; painted[#painted + 1] = value
                end
                previous = value
            end
            return saved.set(name, value, opts)
        end
        vim.notify = function(message) messages[#messages + 1] = message end
    end)
    after_each(function()
        ss.detach(source)
        for _, buf in ipairs({ source, dest }) do
            if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        end
        vim.cmd("silent only")
        vim.wait(50)
        ss.POLL_MS, band.PULSE_MS = saved.poll, saved.pulse
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = saved.path, saved.registry
        vim.notify, vim.api.nvim_set_option_value, vim.uv.new_timer = saved.notify, saved.set, saved.timer
        vim.fn.delete(root, "rf")
    end)
    it("flashes exactly three times after a native buffer swap, naming the locked source", function()
        edit(); swap()
        assert.equals(dest, vim.api.nvim_win_get_buf(win), "navigation is immediate")
        local timer = pulse(); finish(timer)
        assert.is_true(timer.closed)
        assert.truthy(painted[1]:find("held.md", 1, true))
        assert.equals(3, red)
        assert.equals(1, #messages)
        assert.truthy(messages[1]:find("unsubmitted: Alt+Return to submit", 1, true))
        assert.truthy(messages[1]:find(root .. "/held.md", 1, true), vim.inspect(messages))
        assert.falsy(label():find("ParleySessionSyncLeave", 1, true))
    end)
    it("drops a queued leave when focus has already returned before rendering", function()
        edit()
        vim.api.nvim_exec_autocmds("BufLeave", { buffer = source })
        vim.wait(10)
        assert.equals(0, #timers)
        assert.equals(0, #messages)
    end)
    it("does not flash a free document", function()
        swap(); vim.wait(150)
        assert.equals(0, red); assert.equals(0, #messages)
    end)
    it("ignores a turn undone to its baseline even before deferred release", function()
        edit(); vim.api.nvim_buf_set_lines(source, 0, -1, false, { "body" }); swap()
        vim.wait(150)
        assert.equals(0, red); assert.equals(0, #messages)
    end)
    it("still reminds after auto-save cleared modified", function()
        edit(); vim.cmd("silent write"); assert.is_false(vim.bo[source].modified); swap()
        finish(pulse())
        assert.equals(3, red)
        assert.equals(1, #messages)
    end)
    it("coalesces BufLeave and WinLeave for one departure and affects only that window", function()
        edit()
        vim.api.nvim_exec_autocmds("BufLeave", { buffer = source })
        vim.api.nvim_exec_autocmds("WinLeave", { buffer = source })
        vim.cmd("vsplit")
        local other = vim.api.nvim_get_current_win()
        finish(pulse())
        assert.equals(3, red)
        assert.equals(1, #messages)
        assert.falsy(vim.wo[other].winbar:find("ParleySessionSyncLeave", 1, true))
    end)
    it("retires a pulse when the destination buffer changes again", function()
        edit(); swap(); local timer = pulse(); tick(timer)
        vim.api.nvim_win_set_buf(win, source)
        tick(timer) -- a late queued callback cannot repaint the replaced window
        assert.is_true(timer.closed)
        assert.equals(1, red)
        assert.falsy(label():find("ParleySessionSyncLeave", 1, true))
    end)
    it("preserves a user option override made during a pulse", function()
        edit(); swap(); local timer = pulse(); tick(timer)
        vim.wo[win].winbar = "operator custom"
        tick(timer)
        assert.is_true(timer.closed)
        assert.equals("operator custom", label())
        assert.equals(1, red)
    end)
    it("restores the latest underlying view without letting its render hide a pulse", function()
        edit(); swap(); local timer = pulse(); tick(timer)
        local owner = band.new(dest)
        owner.render({ label = "new underlying state", hl = "WarningMsg" })
        assert.truthy(label():find("ParleySessionSyncLeave", 1, true))
        for _ = 1, 5 do tick(timer) end
        assert.equals(3, red)
        assert.truthy(label():find("new underlying state", 1, true))
        owner.clear()
    end)
    it("cancels when its source attachment is detached", function()
        edit(); swap(); local timer = pulse(); tick(timer)
        ss.detach(source); tick(timer)
        assert.is_true(timer.closed)
        assert.equals(1, red)
        assert.falsy(label():find("ParleySessionSyncLeave", 1, true))
    end)
    it("cancels after a submit releases the file-backed lock", function()
        edit(); swap(); local timer = pulse(); tick(timer)
        assert.is_true(os.remove(ss.lock_path(source)))
        tick(timer); tick(timer)
        assert.is_true(timer.closed)
        assert.equals(1, red)
        assert.falsy(label():find("ParleySessionSyncLeave", 1, true))
    end)
    it("cancels on window close and ignores a late tick", function()
        edit(); swap(); local timer = pulse(); tick(timer)
        vim.cmd("vsplit")
        vim.api.nvim_win_close(win, true)
        tick(timer)
        assert.is_true(timer.closed)
        assert.equals(1, red)
    end)
    it("does not leave a copied pulse in a split opened during a red frame", function()
        edit(); swap(); local timer = pulse(); tick(timer)
        vim.cmd("vsplit")
        local other = vim.api.nvim_get_current_win()
        for _ = 1, 5 do tick(timer) end
        assert.falsy(vim.wo[other].winbar:find("ParleySessionSyncLeave", 1, true))
    end)
    local function destination_trail()
        local history = require("parley.file_history"); history.setup()
        edit(); swap()
        local source_path, dest_path = vim.api.nvim_buf_get_name(source), vim.api.nvim_buf_get_name(dest)
        vim.fn.writefile({ "destination" }, dest_path)
        assert.is_true(history.restore(win, { version = 1, paths = { source_path, dest_path }, omitted = 0 }))
        return pulse()
    end
    local function free_destination()
        local owner = band.new(dest)
        owner.render({ state = "free", hl = "ParleySessionSyncFree" })
        return owner
    end
    it("retains destination lock and path state through priority and coordinator pulses", function()
        local timer = destination_trail()
        local owner, coordinator = free_destination(), band.new(dest)
        tick(timer)
        assert.truthy(label():find("free     ", 1, true))
        assert.truthy(label():find("destination", 1, true)); assert.is_nil(label():find("held ›", 1, true))
        assert.truthy(label():find("unsubmitted: Alt+Return", 1, true))
        owner.render({ state = "operator", unsent = true, hl = "ParleySessionSyncOperator" })
        coordinator.render({ overlay = true, state = "unknown", hl = "WarningMsg",
            feedback = { label = "pending coordinator notice", hl = "WarningMsg" } })
        assert.truthy(label():find("yours ●", 1, true))
        assert.truthy(label():find("unsubmitted: Alt+Return", 1, true))
        tick(timer)
        assert.truthy(label():find("pending coordinator notice", 1, true))
        assert.truthy(label():find("yours ●", 1, true))
        for _ = 1, 4 do tick(timer) end
        coordinator.clear(); owner.clear()
    end)
    it("removes a copied pulse before a generic state owner's next refresh", function()
        local timer = destination_trail()
        local owner = free_destination()
        tick(timer)
        vim.cmd("vsplit")
        local other = vim.api.nvim_get_current_win()
        assert.falsy(vim.wo[other].winbar:find("ParleySessionSyncLeave", 1, true))
        assert.truthy(vim.wo[other].winbar:find("free     ", 1, true))
        owner.render({ state = "free", hl = "ParleySessionSyncFree" })
        assert.truthy(vim.wo[other].winbar:find("destination", 1, true)); assert.is_nil(vim.wo[other].winbar:find("held ›", 1, true))
        assert.truthy(label():find("ParleySessionSyncLeave", 1, true))
        for _ = 1, 5 do tick(timer) end
        owner.clear()
    end)
    it("restores a new split beneath a red pulse and keeps its inherited trail behind Back on state refresh", function()
        local timer = destination_trail()
        -- Exercise the attached destination's real BufWinEnter renderer, which
        -- follows WinNew's inherited history in the new editing window.
        ss.attach(dest, { File = vim.api.nvim_buf_get_name(dest), Owner = "ops:0", ID = "destination" })
        tick(timer)
        vim.cmd("vsplit")
        local other = vim.api.nvim_get_current_win()
        assert.falsy(vim.wo[other].winbar:find("ParleySessionSyncLeave", 1, true))
        local inherited = assert(require("parley.file_history").peek(other))
        assert.same({ vim.api.nvim_buf_get_name(source), vim.api.nvim_buf_get_name(dest) }, inherited.paths)
        assert.is_true(ss.set_submission_feedback(dest, "ok", false))
        assert.truthy(vim.wo[other].winbar:find("destination", 1, true)); assert.is_nil(vim.wo[other].winbar:find("held ›", 1, true))
        assert.truthy(vim.wo[other].winbar:find("free     ", 1, true))
        assert.truthy(label():find("ParleySessionSyncLeave", 1, true))
        for _ = 1, 5 do tick(timer) end
        ss.detach(dest)
    end)
    it("allows a split during an off frame with only breadcrumb ownership", function()
        local timer = destination_trail()
        tick(timer); tick(timer)
        assert.falsy(label():find("ParleySessionSyncLeave", 1, true))
        assert.is_true(pcall(vim.cmd, "vsplit"))
        local other = vim.api.nvim_get_current_win()
        assert.falsy(vim.wo[other].winbar:find("ParleySessionSyncLeave", 1, true))
        for _ = 1, 4 do tick(timer) end
    end)

    it("also reminds for a typed legacy session attachment", function()
        ss.detach(source)
        vim.api.nvim_buf_set_lines(source, 0, -1, false,
            { "---", "type: session-sync", "owner: ops:0", "---", "body" })
        vim.cmd("silent write")
        ss.attach(source)
        edit(); swap(); finish(pulse())
        assert.equals(3, red); assert.equals(1, #messages)
    end)

end)
