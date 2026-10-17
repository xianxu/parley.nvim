-- #354: every Alt+Return submit that Couch accepted is recorded for the
-- attention finder, through the one hook both paths share (session_sync's
-- release_and_send): an agentic document, and a `type: session-sync` file.
local arrival = require("tests.helpers.arrival")
local Attention = require("parley.attention")
local Store = require("parley.attention_store")
local Model = require("parley.attention_model")
local logger = require("parley.logger")
local p = require("parley")

local function await(predicate, why)
    assert.is_true(vim.wait(arrival.MS, predicate, 10), why)
end

-- The stored entry for `path`, or nil.
local function entry(path)
    return Store.load().entries[path]
end

-- A temporary root with the fake Couch on PATH and the state directory in it.
-- Returns the root and a restore function.
local function fake_couch_root(env)
    local root = vim.fn.resolve(vim.fn.tempname()); vim.fn.mkdir(root, "p")
    require("tests.helpers.fake_couch").write(root, root .. "/sent", root .. "/argv")
    local names = { "PATH", "COUCH_THREAD_SCOPE", "COUCH_THREAD_TAG", "FAKE_COUCH_REGISTRY", "FAKE_COUCH_REGISTRY_MODE",
        "FAKE_COUCH_ACTORS", "FAKE_COUCH_EXIT", "FAKE_COUCH_SLEEP", "FAKE_COUCH_STATUS", "FAKE_COUCH_OWED",
        "COUCH_ISOLATED_ROOT" }
    local saved = { state_dir = p.config.state_dir, env = {} }
    for _, name in ipairs(names) do saved.env[name] = vim.env[name] or false end
    vim.env.PATH = root .. "/bin:" .. vim.env.PATH
    vim.env.FAKE_COUCH_EXIT = "0"
    for name, value in pairs(env) do vim.env[name] = value end
    p.config.state_dir = root .. "/state"
    return root, function()
        for name, value in pairs(saved.env) do vim.env[name] = value or nil end
        p.config.state_dir = saved.state_dir
        vim.fn.delete(root, "rf")
    end
end

local function keymap(buf, lhs)
    local mapping = vim.api.nvim_buf_call(buf, function() return vim.fn.maparg(lhs, "n", false, true) end)
    assert.equals(1, mapping.buffer)
    return mapping.callback
end

describe("attention: an agentic document's Alt+Return", function()
    local root, restore, file, buf, document
    before_each(function()
        root, restore = fake_couch_root({
            COUCH_THREAD_SCOPE = "scope-test", COUCH_THREAD_TAG = "tag-test",
            FAKE_COUCH_ACTORS = vim.json.encode({ Code = "ok", Actors = {
                { Binding = { Slot = "ops:0", Scope = "scope-test", Tag = "tag-test" } } } }),
        })
        vim.env.FAKE_COUCH_REGISTRY = root .. "/registry.json"
        vim.env.FAKE_COUCH_OWED = "1"
        file = root .. "/ordinary.md"
        vim.fn.writefile({ "---", "owner: business-team", "---", "# Question", "original" }, file)
        vim.cmd("edit " .. vim.fn.fnameescape(file)); buf = vim.api.nvim_get_current_buf()
        document = require("parley.agentic_document")
        p.setup_markdown_keymaps(buf)
    end)
    after_each(function()
        document.detach(buf)
        vim.api.nvim_buf_delete(buf, { force = true })
        require("parley.document_registry").shutdown()
        restore()
    end)

    it("records one waiting entry carrying Couch's message ID", function()
        await(function() return document.status(buf).phase == "plain" end, "document never opened plain")
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "edited question" })
        keymap(buf, "<M-CR>")()
        await(function() return entry(file) ~= nil end, "the submit was never recorded")
        assert.same({ "msg-1" }, vim.tbl_keys(entry(file).pending))
        assert.equals("waiting", Model.state_of(entry(file)))
        -- The fake's ledger owes that ID until the agent folds it.
        local function owed()
            local result = vim.system({ "couch", "--session-sync", "status", "--json", file }, { text = true }):wait()
            local status = vim.json.decode(result.stdout).Status or {}
            return vim.tbl_map(function(event) return event.ID end, status.Owed or {})
        end
        assert.same({ "msg-1" }, owed())
        require("tests.helpers.fake_couch").fold(vim.env.FAKE_COUCH_REGISTRY, file, "msg-1")
        assert.same({}, owed())
    end)
end)

describe("attention: a session-sync file's Alt+Return", function()
    local root, restore, file, buf, saved_history
    local header = { "---", "type: session-sync", "owner: ops:0", "operator: test", "---", "", "## Needs you", "- item" }
    local function open()
        vim.fn.writefile(header, file)
        vim.cmd("edit " .. vim.fn.fnameescape(file))
        buf = vim.api.nvim_get_current_buf()
        p.setup_markdown_keymaps(buf)
    end
    local function edit(text)
        vim.api.nvim_buf_set_lines(buf, 7, 8, false, { text })
        vim.api.nvim_exec_autocmds("BufModifiedSet", { buffer = buf })
    end
    before_each(function()
        root, restore = fake_couch_root({
            COUCH_ISOLATED_ROOT = nil,
            FAKE_COUCH_ACTORS = vim.json.encode({ Code = "ok", Actors = {
                { Binding = { Slot = "ops:0" }, Known = true, Resting = true,
                  LastActivity = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() - 60) } } }),
        })
        vim.env.COUCH_ISOLATED_ROOT = root
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
        p.config.review_shortcut_next = { modes = { "n", "i" }, shortcut = "<M-CR>" }
        file = root .. "/tl-status.md"
        saved_history = package.loaded["parley.file_history"]
    end)
    after_each(function()
        package.loaded["parley.file_history"] = saved_history
        if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        restore()
    end)

    it("records the submit, with the breadcrumb #353's seam gives at send time", function()
        local history = vim.deepcopy(saved_history or {})
        history.snapshot = function(win)
            assert.equals(vim.fn.bufwinid(buf), win)
            return { version = 1, paths = { "/root.md", file } }
        end
        package.loaded["parley.file_history"] = history
        open()
        edit("- item 🤖[ok?]")
        keymap(buf, "<M-CR>")()
        await(function() return entry(file) ~= nil end, "the submit was never recorded")
        assert.same({ "msg-1" }, vim.tbl_keys(entry(file).pending))
        assert.same({ version = 1, paths = { "/root.md", file } }, entry(file).breadcrumb)
    end)

    for _, seam in ipairs({ "real", "unavailable" }) do
        it("records two pending IDs with the " .. seam .. " breadcrumb seam", function()
            if seam == "unavailable" then package.loaded["parley.file_history"] = {} end
            open()
            local expected
            if seam == "real" then
                expected = assert(require("parley.file_history").snapshot(vim.fn.bufwinid(buf)))
            end
            edit("- first")
            keymap(buf, "<M-CR>")()
            await(function() return entry(file) and entry(file).pending["msg-1"] ~= nil end,
                "the first accepted submit was never recorded")
            assert.same(expected, entry(file).breadcrumb)
            edit("- second")
            keymap(buf, "<M-CR>")()
            await(function() return entry(file) and vim.tbl_count(entry(file).pending) == 2 end,
                "the second submit was never recorded")
            assert.same({ "msg-1", "msg-2" }, vim.fn.sort(vim.tbl_keys(entry(file).pending)))
            -- A real one-file root is an opaque value, even though it draws no
            -- trail. Nil belongs to an unavailable seam, not a normal file.
            assert.same(expected, entry(file).breadcrumb)
        end)
    end

    -- ARCH-ORDER late completion: the send completes after its buffer is
    -- gone, so the engine's stale-state guard drops the callback. The message
    -- was sent, so the record must land anyway.
    it("records a send that completes after its buffer was wiped", function()
        vim.env.FAKE_COUCH_SLEEP = "0.3"
        open()
        local expected = assert(require("parley.file_history").snapshot(vim.fn.bufwinid(buf)))
        edit("- item")
        keymap(buf, "<M-CR>")()
        vim.api.nvim_buf_delete(buf, { force = true })
        await(function() return entry(file) and entry(file).pending["msg-1"] ~= nil end,
            "a send completing after its buffer was wiped was not recorded")
        assert.same({ "msg-1" }, vim.tbl_keys(entry(file).pending))
        assert.same(expected, entry(file).breadcrumb)
    end)

    it("a record that throws leaves the submit's own completion intact", function()
        local record, notify, notices = Attention.record, vim.notify, {}
        Attention.record = function() error("store exploded") end
        vim.notify = function(message) notices[#notices + 1] = message end
        local ok, err = pcall(function()
            open()
            edit("- item")
            keymap(buf, "<M-CR>")()
            await(function()
                return vim.iter(notices):any(function(m) return m:find("submitted to ops:0", 1, true) ~= nil end)
            end, "the submit never completed")
        end)
        Attention.record, vim.notify = record, notify
        assert(ok, err)
        assert.is_true(vim.iter(notices):any(function(m) return m:find("not tracked: .*store exploded") ~= nil end))
    end)

    it("records nothing when the send fails", function()
        vim.env.FAKE_COUCH_EXIT = "1"
        open()
        edit("- item")
        keymap(buf, "<M-CR>")()
        await(function() return vim.fn.filereadable(root .. "/argv") == 1 end, "nothing was sent")
        vim.wait(200)
        assert.is_nil(entry(file))
    end)
end)

describe("attention.record without a message ID", function()
    local saved_warning, warnings, restore
    before_each(function()
        local _
        _, restore = fake_couch_root({})
        warnings, saved_warning = {}, logger.warning
        logger.warning = function(message) warnings[#warnings + 1] = message end
    end)
    after_each(function()
        logger.warning = saved_warning
        restore()
    end)

    it("records nothing and warns", function()
        local done
        Attention.record("/a.md", nil, { code = 0, stdout = "" }, nil, function(state, err) done = { state, err } end)
        assert.same({ nil, "no message id" }, done)
        assert.is_nil(entry("/a.md"))
        assert.matches("no message ID", warnings[1])
    end)

    local shapes = {
        { "8aa0e99d-0be4 parley.nvim:3 -> ops:0 queued\nposition 1\n", "8aa0e99d-0be4" },
        { "msg-1 a:1 -> b:2 delivered", "msg-1" },
        { "", nil },
        { "queued", nil },
        { "error: no such peer", nil },
    }
    for _, shape in ipairs(shapes) do
        it(("parses %q as %s"):format(shape[1], tostring(shape[2])), function()
            assert.equals(shape[2], Attention.parse_message_id(shape[1]))
        end)
    end
end)
