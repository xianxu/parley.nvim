-- edit_round's hooks (#383): an agent write the buffer reloads draws its
-- round; a confirmed Alt+Return clears it; a reopen after that submit draws
-- nothing; a failed send keeps it. Rows are the S4 design's state rows.
local arrival = require("tests.helpers.arrival")
local fake_couch = require("tests.helpers.fake_couch")
local ss = require("parley.session_sync")
local uv = vim.uv or vim.loop

describe("edit_round hooks", function()
    local root, file, log_file, saved, buf
    local p = require("parley")
    local header = { "---", "type: session-sync", "owner: ops:0", "operator: xian-xu", "---", "", "## Needs you", "- item" }

    local function marks()
        return vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_create_namespace("parley_round_hl"), 0, -1, {})
    end

    local function open(lines)
        vim.fn.writefile(lines, file)
        vim.cmd("noswapfile edit " .. vim.fn.fnameescape(file))
        buf = vim.api.nvim_get_current_buf()
        p.setup_markdown_keymaps(buf)
    end

    local function sent() return uv.fs_stat(log_file) and vim.fn.readfile(log_file) or {} end

    -- An operator edit and Alt+Return, waited on until the send's outcome is
    -- back: the fake records the submit only after it logs the send.
    local outcomes
    local function submit(count)
        vim.api.nvim_buf_set_lines(buf, 7, 8, false, { "- edited " .. count })
        vim.api.nvim_exec_autocmds("BufModifiedSet", { buffer = buf })
        local km = vim.api.nvim_buf_call(buf, function() return vim.fn.maparg("<M-CR>", "n", false, true) end)
        km.callback()
        assert.is_true(vim.wait(arrival.MS, function() return #sent() == count and #outcomes == count end, 10))
    end

    -- The agent's write: its round lands in Couch's sidecar, then the file on
    -- disk, which the clean buffer reloads.
    local function agent_write(text, explain, base)
        local update = vim.deepcopy(base or header)
        update[8] = text
        fake_couch.round(vim.env.FAKE_COUCH_REGISTRY, file, { base_hash = "aaaaaaaaaaaaaaaa",
            result_hash = vim.fn.sha256(table.concat(update, "\n") .. "\n"):sub(1, 16),
            at = os.date("!%Y-%m-%dT%H:%M:%SZ"), presentation = "highlight",
            spans = { { start = { 7, 2 }, ["end"] = { 7, #text }, old = "edited", new = text:sub(3), explain = explain } } })
        vim.fn.writefile(update, file)
    end

    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname())
        vim.fn.mkdir(root, "p")
        file = root .. "/tl-status.md"
        log_file = root .. "/sent"
        fake_couch.write(root, log_file, root .. "/argv")
        saved = { path = vim.env.PATH, poll = ss.POLL_MS, state_dir = p.config.state_dir,
            shortcut = p.config.review_shortcut_next, env = {} }
        for _, name in ipairs({ "FAKE_COUCH_REGISTRY", "FAKE_COUCH_OWED", "FAKE_COUCH_ACTORS", "FAKE_COUCH_EXIT",
            "COUCH_ISOLATED_ROOT", "COUCH_THREAD_SCOPE", "COUCH_THREAD_TAG" }) do
            saved.env[name] = vim.env[name] or false
        end
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.FAKE_COUCH_REGISTRY = root .. "/registry.json"
        vim.env.FAKE_COUCH_OWED = "1"
        vim.env.FAKE_COUCH_EXIT = "0"
        vim.env.COUCH_ISOLATED_ROOT = root
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
        vim.env.FAKE_COUCH_ACTORS = vim.json.encode({ Code = "ok", Actors = { { Binding = { Slot = "ops:0" },
            Known = true, Resting = true, LastActivity = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() - 60) } } })
        ss.POLL_MS = 20
        p.config.state_dir = root .. "/state"
        p.config.review_shortcut_next = { modes = { "n", "i" }, shortcut = "<M-CR>" }
        outcomes, saved.notify = {}, vim.notify
        vim.notify = function(message)
            if message:find("submitted to", 1, true) or message:find("failed, Alt+Return resends", 1, true) then
                outcomes[#outcomes + 1] = message
            end
        end
    end)

    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        require("parley.agentic_document").detach(buf)
        require("parley.document_registry").shutdown()
        vim.env.PATH, ss.POLL_MS, vim.notify = saved.path, saved.poll, saved.notify
        p.config.state_dir, p.config.review_shortcut_next = saved.state_dir, saved.shortcut
        for name, value in pairs(saved.env) do vim.env[name] = value or nil end
        vim.fn.delete(root, "rf")
    end)

    it("draws the agent's round on reload, clears it on a confirmed submit, and not on reopen (29, 31, 32)", function()
        open(header)
        submit(1)
        -- the submit came before the agent's round
        fake_couch.submit_at(vim.env.FAKE_COUCH_REGISTRY, file, "2020-01-01T00:00:00-07:00")
        agent_write("- resolved by TL", "answered")
        assert.is_true(vim.wait(arrival.MS, function() return #marks() == 1 end, 10), "the round was not drawn")
        submit(2)
        assert.is_true(vim.wait(arrival.MS, function() return #marks() == 0 end, 10), "the submit did not clear it")
        vim.api.nvim_buf_delete(buf, { force = true })
        vim.cmd("noswapfile edit " .. vim.fn.fnameescape(file))
        buf = vim.api.nvim_get_current_buf()
        vim.wait(300, function() return false end, 10)
        assert.equals(0, #marks())
    end)

    it("keeps the round when the send fails", function()
        open(header)
        submit(1)
        fake_couch.submit_at(vim.env.FAKE_COUCH_REGISTRY, file, "2020-01-01T00:00:00Z")
        agent_write("- resolved by TL")
        assert.is_true(vim.wait(arrival.MS, function() return #marks() == 1 end, 10), "the round was not drawn")
        vim.env.FAKE_COUCH_EXIT = "1"
        submit(2)
        vim.wait(200, function() return false end, 10)
        assert.equals(1, #marks())
    end)

    it("draws and clears the round of a registered plain document", function()
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = "s2", "t2"
        vim.env.FAKE_COUCH_ACTORS = vim.json.encode({ Code = "ok", Actors = {
            { Binding = { Slot = "ariadne:2", Scope = "s2", Tag = "t2" } } } })
        file = root .. "/notes.md"
        local doc = { "---", 'process-instruction: "[copy-edit] keep the voice"', "---", "", "- a", "", "", "- item" }
        open(doc)
        submit(1)
        assert.truthy(require("parley.agentic_document").identity(buf))
        fake_couch.submit_at(vim.env.FAKE_COUCH_REGISTRY, file, "2020-01-01T00:00:00Z")
        agent_write("- resolved by the agent", nil, doc)
        assert.is_true(vim.wait(arrival.MS, function() return #marks() == 1 end, 10), "the round was not drawn")
        submit(2)
        assert.is_true(vim.wait(arrival.MS, function() return #marks() == 0 end, 10), "the submit did not clear it")
    end)

    it("draws a round already waiting when the document is opened", function()
        vim.fn.writefile(header, file)
        fake_couch.round(vim.env.FAKE_COUCH_REGISTRY, file, { base_hash = "a", result_hash = "b",
            at = "2020-01-01T00:00:00Z", presentation = "highlight",
            spans = { { start = { 7, 2 }, ["end"] = { 7, 6 }, old = "x", new = "item" } } })
        open(header)
        assert.is_true(vim.wait(arrival.MS, function() return #marks() == 1 end, 10))
    end)
end)
