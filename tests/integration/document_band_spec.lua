describe("shared document bands", function()
    local root, saved, p, ss, document, opened
    local env_keys = { "PATH", "COUCH_THREAD_SCOPE", "COUCH_THREAD_TAG", "COUCH_ISOLATED_ROOT",
        "FAKE_COUCH_REGISTRY", "FAKE_COUCH_REGISTRY_MODE", "FAKE_COUCH_ACTORS", "FAKE_COUCH_STATUS",
        "FAKE_COUCH_EXIT", "FAKE_COUCH_SLEEP", "FAKE_COUCH_LOG_DELAY" }
    local function await(predicate)
        assert.is_true(vim.wait(10000, predicate, 10), "band transition timed out")
    end
    local function observe(item)
        return { winbar = vim.wo[item.win].winbar, winhighlight = vim.wo[item.win].winhighlight }
    end
    local function expect_view(item, label, highlight, cell_override, base_override)
        local cell, detail, base = "free     ", label, highlight
        if label == "free: editing takes your turn" then detail = ""
        elseif label == "your turn, Alt+Return to submit" then cell, detail = "yours ●  ", ""
        elseif label == "unsent edits, Alt+Return to submit" then cell, detail = "stale    ", ""
        elseif highlight == "ParleySessionSyncOperator" then cell = "stale    "
        elseif highlight == "ParleySessionSyncOwed" then cell = "agent…   "
        elseif highlight == "WarningMsg" then cell = "unknown  "
        end
        if highlight == "DiagnosticError" or highlight == "DiagnosticOk" then base = "ParleySessionSyncFree" end
        cell, base = cell_override or cell, base_override or base
        local bar = "%#" .. base .. "#" .. cell
        if detail ~= "" then bar = bar .. " %#" .. highlight .. "#" .. detail:gsub("%%", "%%%%") end
        assert.same({ winbar = bar .. "%=", winhighlight = "StatusLine:" .. base }, observe(item))
    end
    local function open(name, typed)
        local path = root .. "/" .. name .. ".md"
        local lines = typed and { "---", "type: session-sync", "owner: ops:0", "---", "body", "tail" }
            or { "# Ordinary question", "body", "tail" }
        vim.fn.writefile(lines, path)
        if #opened > 0 then vim.cmd("vsplit") end
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        local item = { path = path, buf = vim.api.nvim_get_current_buf(), win = vim.api.nvim_get_current_win() }
        vim.wo[item.win].winbar = "original"
        vim.wo[item.win].winhighlight = "StatusLine:Search"
        opened[#opened + 1] = item
        return item
    end
    local function register(item)
        local result
        require("parley.document_registry").request("register", { item.path, "ops:0" }, {}, function(reply) result = reply end)
        await(function() return result ~= nil end)
        assert.equals("registered", result.kind)
    end
    local function admit(item)
        p.setup_markdown_keymaps(item.buf)
        await(function() return document.identity(item.buf) ~= nil end)
    end
    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname()); vim.fn.mkdir(root, "p")
        opened, saved = {}, { env = {} }
        for _, key in ipairs(env_keys) do saved.env[key] = vim.env[key] end
        require("tests.helpers.fake_couch").write(root, root .. "/sent", root .. "/argv")
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = "band-scope", "band-pane"
        vim.env.COUCH_ISOLATED_ROOT = root
        vim.env.FAKE_COUCH_REGISTRY = root .. "/registry.json"
        vim.env.FAKE_COUCH_REGISTRY_MODE, vim.env.FAKE_COUCH_STATUS = nil, nil
        vim.env.FAKE_COUCH_EXIT, vim.env.FAKE_COUCH_SLEEP, vim.env.FAKE_COUCH_LOG_DELAY = "0", nil, nil
        vim.env.FAKE_COUCH_ACTORS = vim.json.encode({ Code = "ok", Actors = {
            { Binding = { Slot = "ops:0", Scope = "band-scope", Tag = "band-pane" } },
        } })
        p, ss, document = require("parley"), require("parley.session_sync"), require("parley.agentic_document")
        saved.state_dir, saved.shortcut = p.config.state_dir, p.config.review_shortcut_next
        saved.date = os.date
        saved.columns = vim.o.columns; vim.o.columns = 500
        saved.stale, saved.poll, saved.ping = p.config.session_sync_stale_minutes, ss.POLL_MS, ss.PING_CHECK_MS
        p.config.state_dir = root .. "/state"
        p.config.review_shortcut_next = { modes = { "n", "i" }, shortcut = "<M-CR>" }
        ss.POLL_MS, ss.PING_CHECK_MS = 20, 60000
    end)
    after_each(function()
        for _, item in ipairs(opened) do
            document.detach(item.buf); ss.detach(item.buf)
            if vim.api.nvim_buf_is_valid(item.buf) then vim.api.nvim_buf_delete(item.buf, { force = true }) end
        end
        require("parley.document_registry").shutdown()
        rawset(os, "date", saved.date)
        vim.o.columns = saved.columns
        vim.cmd("silent only")
        for _, key in ipairs(env_keys) do vim.env[key] = saved.env[key] end
        p.config.state_dir, p.config.review_shortcut_next = saved.state_dir, saved.shortcut
        p.config.session_sync_stale_minutes, ss.POLL_MS, ss.PING_CHECK_MS = saved.stale, saved.poll, saved.ping
        vim.fn.delete(root, "rf")
    end)

    it("renders a shared unknown fallback and preserves an attached session lock when present", function()
        vim.env.FAKE_COUCH_REGISTRY_MODE = "unsupported"
        local typed = open("typed-unknown", true)
        p.setup_markdown_keymaps(typed.buf)
        await(function() return document.status(typed.buf).phase == "unknown" end)
        assert.equals("StatusLine:ParleySessionSyncFree", vim.wo[typed.win].winhighlight)
        assert.truthy(vim.wo[typed.win].winbar:find("Couch unavailable: agentic state unknown", 1, true))
        -- Membership uncertainty cannot replace an already attached lock view.
        -- Once that owner detaches, the same fallback is used by either kind.
        ss.detach(typed.buf)
        expect_view(typed, "Couch unavailable: agentic state unknown", "WarningMsg")
        local typed_view = observe(typed)
        local ordinary = open("unknown")
        p.setup_markdown_keymaps(ordinary.buf)
        await(function() return document.status(ordinary.buf).phase == "unknown" end)
        expect_view(ordinary, "Couch unavailable: agentic state unknown", "WarningMsg")
        assert.same(typed_view, observe(ordinary))
    end)

    it("shares error text while retaining proven-plain and attached lock knowledge", function()
        local typed = open("typed", true); ss.attach(typed.buf)
        local ordinary = open("unresolved")
        p.setup_markdown_keymaps(ordinary.buf)
        await(function() return document.status(ordinary.buf).phase == "plain" end)
        vim.env.FAKE_COUCH_ACTORS = vim.json.encode({ Code = "ok", Actors = {} })
        document.submit(ordinary.buf)
        local message = "submit failed: cannot resolve this pane's agent"
        await(function() return vim.wo[ordinary.win].winbar:find(message, 1, true) ~= nil end)
        assert.is_true(ss.set_submission_feedback(typed.buf, message, true))
        expect_view(typed, message, "DiagnosticError")
        expect_view(ordinary, message, "DiagnosticError", "         ", "WinBar")
    end)

    local function pair()
        local typed = open("session", true)
        ss.attach(typed.buf)
        local ordinary = open("registered")
        register(ordinary); admit(ordinary)
        return typed, ordinary
    end
    local function equivalent(typed, ordinary, label, highlight)
        assert.same(observe(typed), observe(ordinary))
        expect_view(ordinary, label, highlight)
    end
    local function feedback_label(item)
        local label = vim.wo[item.win].winbar:match(".*%%#[^#]+#(.*)%%=$")
        return label and label:gsub("%%%%", "%%")
    end
    local function compare_feedback(typed, ordinary, fragment, is_error)
        await(function()
            local status = document.status(ordinary.buf)
            local label = feedback_label(ordinary)
            return status and not status.operation and label and label:find(fragment, 1, true) ~= nil
        end)
        local label = feedback_label(ordinary)
        assert.is_true(ss.set_submission_feedback(typed.buf, label, is_error))
        expect_view(typed, label, is_error and "DiagnosticError" or "DiagnosticOk")
        expect_view(ordinary, label, is_error and "DiagnosticError" or "DiagnosticOk", "unknown  ", "WarningMsg")
        return label
    end

    it("uses identical free, operator, stale and foreign-write bands for both file kinds", function()
        p.config.session_sync_stale_minutes = 0.01
        local typed, ordinary = pair()
        equivalent(typed, ordinary, "free: editing takes your turn", "ParleySessionSyncFree")
        for _, item in ipairs({ typed, ordinary }) do
            vim.api.nvim_buf_set_lines(item.buf, -1, -1, false, { "operator edit" })
        end
        await(function()
            return vim.wo[typed.win].winbar:find("yours ●", 1, true) ~= nil
                and vim.wo[ordinary.win].winbar:find("yours ●", 1, true) ~= nil
        end)
        equivalent(typed, ordinary, "your turn, Alt+Return to submit", "ParleySessionSyncOperator")
        await(function()
            return vim.wo[typed.win].winbar:find("stale", 1, true) ~= nil
                and vim.wo[ordinary.win].winbar:find("stale", 1, true) ~= nil
        end)
        equivalent(typed, ordinary, "unsent edits, Alt+Return to submit", "ParleySessionSyncStale")
        for _, item in ipairs({ typed, ordinary }) do
            vim.fn.writefile({ "agent replacement under operator lock" }, item.path)
            assert.is_true(ss.prepare_submit(item.buf))
            assert.equals(1, vim.fn.filereadable(item.path .. ".clobbered"))
        end
        equivalent(typed, ordinary, "ops:0 wrote under your lock: yours kept, theirs in .clobbered", "ParleySessionSyncOperator")
    end)

    it("renders the same owed status from real Couch responses for both file kinds", function()
        local now = os.time()
        vim.env.FAKE_COUCH_STATUS = vim.json.encode({ Code = "ok", Status = {
            Owed = { { ID = "obligation", At = os.date("!%Y-%m-%dT%H:%M:%SZ", now - 180) } },
            LastWrite = os.date("!%Y-%m-%dT%H:%M:%SZ", now),
        } })
        local typed, ordinary = pair()
        -- The label only appears once each real status subprocess has completed.
        await(function()
            return vim.wo[typed.win].winbar:find("owes a response", 1, true) ~= nil
                and vim.wo[ordinary.win].winbar:find("owes a response", 1, true) ~= nil
        end)
        local label = feedback_label(ordinary)
        assert.matches("^ops:0 owes a response, %d+ min$", label)
        equivalent(typed, ordinary, label, "ParleySessionSyncOwed")
    end)

    it("renders successful, unchanged, resent and failed submissions identically for admitted file kinds", function()
        rawset(os, "date", function(format, ...)
            if format == "%H:%M" then return "14:23" end
            return saved.date(format, ...)
        end)
        local typed = open("admitted-session", true)
        register(typed); admit(typed)
        local ordinary = open("admitted-ordinary")
        register(ordinary); admit(ordinary)
        local function submitted(item, expected, is_error)
            document.submit(item.buf)
            await(function()
                local status, label = document.status(item.buf), feedback_label(item)
                return status and status.phase == "registered" and not status.operation
                    and label and label:find(expected, 1, true) ~= nil
            end)
            local label = feedback_label(item)
            expect_view(item, label, is_error and "DiagnosticError" or "DiagnosticOk")
            return observe(item), label
        end
        local snapshots = {}
        for _, item in ipairs({ typed, ordinary }) do
            local receipt, receipt_label = submitted(item, "submitted to", false)
            assert.equals("submitted to ops:0 · 14:23", receipt_label)
            local unchanged, unchanged_label = submitted(item, "nothing to submit", false)
            assert.equals("nothing to submit: no changes since 14:23", unchanged_label)
            -- Press again immediately; another document's subprocess must not
            -- consume this document's two-second explicit-resend window.
            local resent, resent_label = submitted(item, "resent to", false)
            assert.equals("resent to ops:0 · 14:23", resent_label)
            snapshots[#snapshots + 1] = { receipt = receipt, unchanged = unchanged, resent = resent }
        end
        assert.same(snapshots[1], snapshots[2])
        vim.env.FAKE_COUCH_EXIT = "1"
        local failures = {}
        for _, item in ipairs({ typed, ordinary }) do
            vim.api.nvim_buf_set_lines(item.buf, -1, -1, false, { "new submission" })
            failures[#failures + 1] = submitted(item, "operation failed:", true)
        end
        assert.same(failures[1], failures[2])
    end)

    it("renders an uncertain registration failure before attachment like session feedback", function()
        local typed = open("typed-pending", true); ss.attach(typed.buf)
        local ordinary = open("pending")
        p.setup_markdown_keymaps(ordinary.buf)
        await(function() return document.status(ordinary.buf).phase == "plain" end)
        vim.env.FAKE_COUCH_REGISTRY_MODE = "uncertain"
        document.submit(ordinary.buf)
        await(function() return document.status(ordinary.buf).phase == "pending" end)
        assert.is_nil(ss.identity(ordinary.buf))
        compare_feedback(typed, ordinary, "operation failed: published but reply unavailable", true)
    end)

    it("highlights a real pending move recovery when OLD is reopened", function()
        local ordinary = open("move-old")
        register(ordinary); admit(ordinary)
        vim.api.nvim_buf_set_lines(ordinary.buf, -1, -1, false, { "held edit" })
        local destination = root .. "/move-new.md"
        vim.env.FAKE_COUCH_REGISTRY_MODE = "uncertain"
        vim.api.nvim_buf_call(ordinary.buf, function()
            vim.cmd("saveas " .. vim.fn.fnameescape(destination))
        end)
        await(function() return document.status(ordinary.buf).phase == "pending" end)
        document.detach(ordinary.buf)
        vim.api.nvim_buf_delete(ordinary.buf, { force = true })
        vim.api.nvim_set_current_win(ordinary.win)
        vim.cmd("edit " .. vim.fn.fnameescape(ordinary.path))
        ordinary.buf = vim.api.nvim_get_current_buf()
        vim.wo[ordinary.win].winbar = "original"
        vim.wo[ordinary.win].winhighlight = "StatusLine:Search"
        p.setup_markdown_keymaps(ordinary.buf)
        local label = "Pending document move: open " .. destination .. " to recover"
        await(function() return feedback_label(ordinary) == label end)
        assert.is_truthy(ss.identity(ordinary.buf), "known pending document retains its attachment")
        assert.equals("StatusLine:ParleySessionSyncOperator", vim.wo[ordinary.win].winhighlight)
        assert.truthy(vim.wo[ordinary.win].winbar:find("yours", 1, true))
        assert.is_nil(vim.wo[ordinary.win].winbar:find("unknown", 1, true))
    end)

    it("restores original options after unknown-to-registered handoff and detach", function()
        local unrelated = open("unrelated", true); ss.attach(unrelated.buf)
        local ordinary = open("handoff")
        vim.env.FAKE_COUCH_REGISTRY_MODE = "unsupported"
        p.setup_markdown_keymaps(ordinary.buf)
        await(function() return document.status(ordinary.buf).phase == "unknown" end)
        expect_view(ordinary, "Couch unavailable: agentic state unknown", "WarningMsg")
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        register(ordinary)
        document.recheck(ordinary.buf)
        await(function() return document.identity(ordinary.buf) ~= nil end)
        expect_view(ordinary, "free: editing takes your turn", "ParleySessionSyncFree")
        document.detach(ordinary.buf)
        assert.same({ winbar = "original", winhighlight = "StatusLine:Search" }, observe(ordinary))
        expect_view(unrelated, "free: editing takes your turn", "ParleySessionSyncFree")
    end)

    it("keeps matching trails and lock cells for actual session and registered file states", function()
        vim.fn.mkdir(root .. "/typed", "p"); vim.fn.mkdir(root .. "/ordinary", "p")
        local typed = open("typed/question", true); ss.attach(typed.buf)
        local ordinary = open("ordinary/question"); register(ordinary); admit(ordinary)
        local history = require("parley.file_history")
        history.setup()
        local base = root .. "/2026-10-16-root.md"; vim.fn.writefile({ "root" }, base)
        for _, item in ipairs({ typed, ordinary }) do
            assert.is_true(history.restore(item.win, { version = 1, paths = { base, item.path }, omitted = 0 }))
        end
        assert.same(observe(typed), observe(ordinary))
        assert.truthy(vim.wo[ordinary.win].winbar:find("root › question", 1, true))
        for _, item in ipairs({ typed, ordinary }) do
            vim.api.nvim_buf_set_lines(item.buf, -1, -1, false, { "unsubmitted" })
            assert.is_true(ss.set_submission_feedback(item.buf, "submit failed: busy", true))
        end
        assert.same(observe(typed), observe(ordinary))
        for _, item in ipairs({ typed, ordinary }) do
            assert.equals("StatusLine:ParleySessionSyncOperator", vim.wo[item.win].winhighlight)
            assert.truthy(vim.wo[item.win].winbar:find("yours ●", 1, true))
            assert.truthy(vim.wo[item.win].winbar:find("submit failed: busy", 1, true))
            assert.truthy(vim.wo[item.win].winbar:find("root › question", 1, true))
        end
    end)

    it("composes independent trails in two windows showing the same attached buffer", function()
        local item = open("same-window-buffer", true); ss.attach(item.buf)
        local history = require("parley.file_history"); history.setup()
        local first = item.win
        vim.cmd("vsplit")
        local second = vim.api.nvim_get_current_win()
        local a, b = root .. "/first.md", root .. "/second.md"
        vim.fn.writefile({ "a" }, a); vim.fn.writefile({ "b" }, b)
        assert.is_true(history.restore(first, { version = 1, paths = { a, item.path }, omitted = 0 }))
        assert.is_true(history.restore(second, { version = 1, paths = { b, item.path }, omitted = 0 }))
        assert.is_true(ss.set_submission_feedback(item.buf, "submitted to ops:0 · 14:23", false))
        assert.truthy(vim.wo[first].winbar:find("first › same-window-buffer", 1, true))
        assert.truthy(vim.wo[second].winbar:find("second › same-window-buffer", 1, true))
        for _, win in ipairs({ first, second }) do
            assert.truthy(vim.wo[win].winbar:find("submitted to ops:0", 1, true))
            assert.equals("StatusLine:ParleySessionSyncFree", vim.wo[win].winhighlight)
        end
        vim.api.nvim_win_set_width(second, 24)
        vim.api.nvim_exec_autocmds("WinResized", {})
        local rendered = vim.api.nvim_eval_statusline(vim.wo[second].winbar,
            { winid = second, use_winbar = true, maxwidth = 1000 }).str
        assert.is_true(vim.fn.strdisplaywidth(vim.trim(rendered)) <= 24)
        assert.truthy(vim.wo[first].winbar:find("first › same-window-buffer", 1, true))
    end)

    local function renderer(item)
        local ok, module = pcall(require, "parley.document_band")
        assert.is_true(ok, "shared renderer module must load")
        return module.new(item.buf)
    end
    local free = { state = "free", label = "free: editing takes your turn", hl = "ParleySessionSyncFree" }
    local failure = { state = "free", label = "submit failed: 50% unavailable", hl = "ParleySessionSyncFree",
        feedback = { label = "submit failed: 50% unavailable", hl = "DiagnosticError" } }

    it("keeps a combining accent attached to the retained leaf at narrow adapter widths", function()
        local item = open("éééé")
        local history = require("parley.file_history"); history.setup()
        local ancestor = root .. "/root.md"
        vim.fn.writefile({ "root" }, ancestor)
        vim.cmd("vsplit")
        assert.is_true(history.restore(item.win, { version = 1, paths = { ancestor, item.path }, omitted = 0 }))
        local owner = renderer(item)
        owner.render(free)
        vim.api.nvim_win_set_width(item.win, 12)
        require("parley.document_band").refresh(item.win)
        assert.equals("%#ParleySessionSyncFree#free      …é%=", vim.wo[item.win].winbar)
        owner.render({ state = "free", hl = "ParleySessionSyncFree",
            feedback = { label = "éééé", hl = "DiagnosticError" } })
        assert.equals("%#ParleySessionSyncFree#free      %#DiagnosticError#é…%=", vim.wo[item.win].winbar)
        owner.clear()
    end)

    it("retires never-installed plain roots without poisoning later renders or cleanup", function()
        local item = open("never-installed")
        local owner = renderer(item)
        local original = observe(item)
        owner.render({ state = "plain", hl = "WinBar" })
        assert.same(original, observe(item))
        owner.clear()
        owner.render({ state = "plain", hl = "WinBar" })
        local other = open("after-plain-root")
        vim.api.nvim_win_set_buf(item.win, other.buf)
        owner.clear()
        vim.api.nvim_win_set_buf(item.win, item.buf)
        owner.render(free)
        expect_view(item, free.label, free.hl)
        owner.clear()
        assert.same(original, observe(item))
    end)

    for _, kind in ipairs({ "breadcrumb-only", "state-owned" }) do
        for _, overridden in ipairs({ "winbar", "winhighlight", "both" }) do
            it("preserves " .. overridden .. " overrides through resize, refresh and cleanup for " .. kind, function()
                local item = open("override-" .. kind .. "-" .. overridden)
                local history, band = require("parley.file_history"), require("parley.document_band")
                history.setup()
                local ancestor = root .. "/ancestor.md"
                vim.fn.writefile({ "ancestor" }, ancestor)
                assert.is_true(history.restore(item.win, { version = 1, paths = { ancestor, item.path }, omitted = 0 }))
                local owner = renderer(item)
                if kind == "state-owned" then owner.render(free) end
                local custom = { winbar = "operator custom bar", winhighlight = "StatusLine:IncSearch" }
                local expected = { winbar = "original", winhighlight = "StatusLine:Search" }
                for _, option in ipairs({ "winbar", "winhighlight" }) do
                    if overridden == option or overridden == "both" then
                        vim.wo[item.win][option] = custom[option]
                        expected[option] = custom[option]
                    end
                end
                for _ = 1, 2 do
                    vim.api.nvim_exec_autocmds("WinResized", {})
                    band.refresh(item.win)
                    if kind == "state-owned" then owner.render(failure) end
                    for _, option in ipairs({ "winbar", "winhighlight" }) do
                        if overridden == option or overridden == "both" then
                            assert.equals(custom[option], vim.wo[item.win][option])
                        else
                            assert.is_true(vim.wo[item.win][option] ~= expected[option], "unclaimed override must not disable owned option")
                        end
                    end
                end
                owner.clear()
                assert.is_true(history.restore(item.win, { version = 1, paths = { item.path }, omitted = 0 }))
                band.refresh(item.win)
                assert.same(expected, observe(item))
            end)
        end
    end

    it("restores a still-live session layer after temporary coordinator feedback clears", function()
        local item = open("layered")
        local session, coordinator = renderer(item), renderer(item)
        session.render(free)
        coordinator.render(failure)
        expect_view(item, failure.label, "DiagnosticError")
        coordinator.clear()
        expect_view(item, free.label, free.hl)
        session.clear()
        assert.same({ winbar = "original", winhighlight = "StatusLine:Search" }, observe(item))
    end)

    it("keeps a pending overlay above refreshed lock state without hiding the lock cell", function()
        local item = open("overlay-held", true); ss.attach(item.buf)
        vim.api.nvim_buf_set_lines(item.buf, -1, -1, false, { "unsent" })
        local overlay = renderer(item)
        overlay.render({ overlay = true, state = "unknown", hl = "WarningMsg",
            feedback = { label = "Pending document move", hl = "WarningMsg" } })
        assert.truthy(vim.wo[item.win].winbar:find("yours ●", 1, true))
        assert.truthy(vim.wo[item.win].winbar:find("Pending document move", 1, true))
        assert.equals("StatusLine:ParleySessionSyncOperator", vim.wo[item.win].winhighlight)
        assert.is_true(ss.set_submission_feedback(item.buf, "new state receipt", false))
        assert.truthy(vim.wo[item.win].winbar:find("Pending document move", 1, true))
        assert.truthy(vim.wo[item.win].winbar:find("yours ●", 1, true))
        overlay.clear()
        assert.truthy(vim.wo[item.win].winbar:find("new state receipt", 1, true))
        assert.truthy(vim.wo[item.win].winbar:find("yours ●", 1, true))
        assert.equals("StatusLine:ParleySessionSyncOperator", vim.wo[item.win].winhighlight)
        overlay.render({ overlay = true, state = "unknown", hl = "WarningMsg",
            feedback = { label = "Pending document move", hl = "WarningMsg" } })
        ss.detach(item.buf)
        assert.equals("StatusLine:WarningMsg", vim.wo[item.win].winhighlight)
        assert.truthy(vim.wo[item.win].winbar:find("unknown", 1, true))
        overlay.clear()
        assert.same({ winbar = "original", winhighlight = "StatusLine:Search" }, observe(item))
    end)

    it("does not let an older owner clear a newer identical band", function()
        local item = open("identical")
        local older, newer = renderer(item), renderer(item)
        older.render(free); newer.render(free)
        older.clear()
        expect_view(item, free.label, free.hl)
        newer.clear()
        assert.same({ winbar = "original", winhighlight = "StatusLine:Search" }, observe(item))
    end)

    it("keeps another window owner intact and preserves user option overrides", function()
        local first, second = open("first"), open("second")
        local a, b = renderer(first), renderer(second)
        a.render(free); b.render(free)
        vim.wo[first.win].winbar = "operator custom bar"
        vim.wo[first.win].winhighlight = "StatusLine:IncSearch"
        a.clear()
        assert.same({ winbar = "operator custom bar", winhighlight = "StatusLine:IncSearch" }, observe(first))
        expect_view(second, free.label, free.hl)
        b.clear()
        assert.same({ winbar = "original", winhighlight = "StatusLine:Search" }, observe(second))
    end)

    it("retires the previous buffer's ownership when a window changes buffers", function()
        local first, second = open("old-buffer"), open("new-buffer")
        local older, newer = renderer(first), renderer(second)
        older.render(free)
        vim.api.nvim_win_set_buf(first.win, second.buf)
        newer.render(free)
        older.clear()
        expect_view(first, free.label, free.hl)
        newer.clear()
        assert.same({ winbar = "original", winhighlight = "StatusLine:Search" }, observe(first))
    end)

    for _, mode in ipairs({ "native :buffer", "noncurrent nvim_win_set_buf" }) do
        it("restores distinct A and B baselines through an A→B→A roundtrip with " .. mode, function()
            local a, b = open("roundtrip-a"), open("roundtrip-b")
            local target = a.win
            local function switch(buf)
                if mode == "native :buffer" then
                    vim.api.nvim_set_current_win(target)
                    vim.cmd("buffer " .. buf)
                else
                    vim.api.nvim_set_current_win(b.win)
                    assert.is_true(target ~= vim.api.nvim_get_current_win())
                    vim.api.nvim_win_set_buf(target, buf)
                end
            end
            local original_a = { winbar = "original A", winhighlight = "StatusLine:Search" }
            local original_b = { winbar = "original B", winhighlight = "StatusLine:IncSearch" }
            vim.wo[target].winbar, vim.wo[target].winhighlight = original_a.winbar, original_a.winhighlight
            local owner_a, owner_b = renderer(a), renderer(b)
            owner_a.render(free)
            switch(b.buf)
            vim.wo[target].winbar, vim.wo[target].winhighlight = original_b.winbar, original_b.winhighlight
            owner_b.render(free)
            switch(a.buf)
            owner_a.render(free)
            owner_a.clear()
            assert.same(original_a, observe(a), "A must recover its own options after returning from B")
            switch(b.buf)
            owner_b.render(free)
            owner_b.clear()
            assert.same(original_b, observe(a), "B must recover its own options after returning from A")
        end)
    end

    it("clearing a hidden old owner cannot restore its options into B or disturb another A window", function()
        local a, b = open("hidden-a"), open("hidden-b")
        local target = a.win
        vim.api.nvim_set_current_win(target)
        vim.wo[target].winbar, vim.wo[target].winhighlight = "original A", "StatusLine:Search"
        local hidden = renderer(a)
        hidden.render(free)
        vim.cmd("vsplit")
        local other_a = { buf = a.buf, win = vim.api.nvim_get_current_win() }
        local visible = renderer(a)
        visible.render(free)
        vim.api.nvim_win_set_buf(target, b.buf)
        vim.wo[target].winbar, vim.wo[target].winhighlight = "original B", "StatusLine:IncSearch"
        local owner_b = renderer(b)
        owner_b.render(free)
        hidden.clear()
        expect_view(a, free.label, free.hl)
        expect_view(other_a, free.label, free.hl)
        owner_b.clear()
        assert.same({ winbar = "original B", winhighlight = "StatusLine:IncSearch" }, observe(a))
        expect_view(other_a, free.label, free.hl)
        visible.clear()
    end)

end)
