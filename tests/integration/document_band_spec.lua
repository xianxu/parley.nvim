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
    local function expect_view(item, label, highlight)
        assert.same({ winbar = "%#" .. highlight .. "# " .. label:gsub("%%", "%%%%") .. "%=",
            winhighlight = "StatusLine:" .. highlight }, observe(item))
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
        vim.cmd("silent only")
        for _, key in ipairs(env_keys) do vim.env[key] = saved.env[key] end
        p.config.state_dir, p.config.review_shortcut_next = saved.state_dir, saved.shortcut
        p.config.session_sync_stale_minutes, ss.POLL_MS, ss.PING_CHECK_MS = saved.stale, saved.poll, saved.ping
        vim.fn.delete(root, "rf")
    end)

    it("renders unknown membership identically for both file kinds", function()
        vim.env.FAKE_COUCH_REGISTRY_MODE = "unsupported"
        local typed = open("typed-unknown", true)
        p.setup_markdown_keymaps(typed.buf)
        await(function() return document.status(typed.buf).phase == "unknown" end)
        expect_view(typed, "Couch unavailable: agentic state unknown", "WarningMsg")
        local typed_view = observe(typed)
        local ordinary = open("unknown")
        p.setup_markdown_keymaps(ordinary.buf)
        await(function() return document.status(ordinary.buf).phase == "unknown" end)
        expect_view(ordinary, "Couch unavailable: agentic state unknown", "WarningMsg")
        assert.same(typed_view, observe(ordinary))
    end)

    it("renders a pre-attachment submit error identically to attached session feedback", function()
        local typed = open("typed", true); ss.attach(typed.buf)
        local ordinary = open("unresolved")
        p.setup_markdown_keymaps(ordinary.buf)
        await(function() return document.status(ordinary.buf).phase == "plain" end)
        vim.env.FAKE_COUCH_ACTORS = vim.json.encode({ Code = "ok", Actors = {} })
        document.submit(ordinary.buf)
        local message = "submit failed: cannot resolve this pane's agent"
        await(function() return vim.wo[ordinary.win].winbar:find(message, 1, true) ~= nil end)
        assert.is_true(ss.set_submission_feedback(typed.buf, message, true))
        assert.same(observe(typed), observe(ordinary))
        expect_view(ordinary, message, "DiagnosticError")
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
        return vim.wo[item.win].winbar:match("^%%#[^#]+# (.*)%%=$")
    end
    local function compare_feedback(typed, ordinary, fragment, is_error)
        await(function()
            local status = document.status(ordinary.buf)
            local label = feedback_label(ordinary)
            return status and not status.operation and label and label:find(fragment, 1, true) ~= nil
        end)
        local label = feedback_label(ordinary)
        assert.is_true(ss.set_submission_feedback(typed.buf, label, is_error))
        equivalent(typed, ordinary, label, is_error and "DiagnosticError" or "DiagnosticOk")
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
            return vim.wo[typed.win].winbar:find("your turn", 1, true) ~= nil
                and vim.wo[ordinary.win].winbar:find("your turn", 1, true) ~= nil
        end)
        equivalent(typed, ordinary, "your turn, Alt+Return to submit", "ParleySessionSyncOperator")
        await(function()
            return vim.wo[typed.win].winbar:find("unsent edits", 1, true) ~= nil
                and vim.wo[ordinary.win].winbar:find("unsent edits", 1, true) ~= nil
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
        expect_view(ordinary, label, "WarningMsg")
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

    local function renderer(item)
        local ok, module = pcall(require, "parley.document_band")
        assert.is_true(ok, "shared renderer module must load")
        return module.new(item.buf)
    end
    local free = { label = "free: editing takes your turn", hl = "ParleySessionSyncFree" }
    local failure = { label = "submit failed: 50% unavailable", hl = "DiagnosticError" }

    it("restores a still-live session layer after temporary coordinator feedback clears", function()
        local item = open("layered")
        local session, coordinator = renderer(item), renderer(item)
        session.render(free)
        coordinator.render(failure)
        expect_view(item, failure.label, failure.hl)
        coordinator.clear()
        expect_view(item, free.label, free.hl)
        session.clear()
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

end)
