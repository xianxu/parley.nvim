-- Per-caller on_abort teardown tests (issue #131, boundary-review Important #3).
--
-- The e2e spec proves the abort CHAIN reaches on_abort via a spy; these drive
-- the REAL teardown bodies at each D.query caller so an arg-position regression
-- or a collapse_empty_answer bug is actually caught.

local uv = vim.uv or vim.loop
local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/parley-cliproxy-teardown-" .. os.time()
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

local cliproxy = require("parley.cliproxy")
local vault = require("parley.vault")

local started = {}

local function free_port()
    local s = uv.new_tcp()
    s:bind("127.0.0.1", 0)
    local port = s:getsockname().port
    s:close()
    return port
end

local function start_fake(port, mode)
    local handle, pid = uv.spawn(FAKE, { args = { "--port", tostring(port), "--mode", mode } }, function() end)
    assert(handle, "spawn fake")
    table.insert(started, pid)
    vim.wait(5000, function()
        local ok = false
        local c = uv.new_tcp()
        c:connect("127.0.0.1", port, function(err)
            ok = err == nil
            c:close()
        end)
        vim.wait(100, function() return false end)
        return ok
    end, 50)
    return pid
end

describe("cliproxy on_abort teardown per caller", function()
    after_each(function()
        for _, pid in ipairs(started) do
            pcall(uv.kill, pid, "sigkill")
        end
        for _, pid in ipairs(cliproxy.spawned_pids()) do
            pcall(uv.kill, pid, "sigkill")
        end
        cliproxy._reset_spawned()
        started = {}
        parley.config.cliproxy = nil
    end)

    -- memory_prefs: real chain — a foreign proxy aborts each tag, process_next
    -- must keep the batch moving so the callback still fires (no stall).
    it("memory_prefs advances the batch past aborted tags", function()
        local port = free_port()
        start_fake(port, "foreign")
        parley.dispatcher.providers.cliproxyapi = {
            endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(port),
        }
        vault.add_secret("cliproxyapi", "testkey")
        parley.config.cliproxy = { manage = true, binary_path = FAKE }

        local saved_get_agent = parley.get_agent
        parley.get_agent = function()
            return { provider = "cliproxyapi", model = { model = "claude-x" } }
        end

        local done
        require("parley.memory_prefs").generate_preferences(
            { topicA = { "s1" }, topicB = { "s2" } },
            function(prefs) done = prefs end
        )
        vim.wait(9000, function() return done ~= nil end, 20)
        parley.get_agent = saved_get_agent

        assert.is_truthy(done) -- callback fired → on_abort → process_next past BOTH tags
    end)

    it("memory_prefs advances every tag after drained transport failures", function()
        local tasker = require("parley.tasker")
        local agent = parley.get_agent()
        vault.resolve_secret(agent.provider, "test-secret", function() end)
        parley.dispatcher.providers[agent.provider] = parley.dispatcher.providers[agent.provider] or {}
        parley.dispatcher.providers[agent.provider].endpoint = "http://unused.test"

        local original_run = tasker.run
        local runs = 0
        tasker.run = function(_buf, _cmd, args, terminal, out_reader)
            runs = runs + 1
            local write_out
            for i, arg in ipairs(args) do
                if arg == "--write-out" then write_out = args[i + 1] end
            end
            local sentinel = write_out:match("%%{stderr}(.-)%%{http_code}")
            out_reader(nil, nil)
            terminal(7, 0, "", sentinel .. "000\n", nil)
        end

        local done
        require("parley.memory_prefs").generate_preferences(
            { topicA = { "s1" }, topicB = { "s2" } },
            function(prefs) done = prefs end)
        assert.is_true(vim.wait(1000, function() return done ~= nil end, 10))
        tasker.run = original_run

        assert.equals(2, runs)
        assert.same({}, done)
    end)

    -- chat_respond main path: mock D.query to invoke the real on_abort (arg 8);
    -- assert it's wired at the right position AND collapses the inserted answer
    -- block (default, non-web-search path — the round-2 gate's demanded test).
    it("chat_respond on_abort collapses the inserted empty answer block", function()
        -- filename needs a timestamp format to pass not_chat validation
        local test_file = tmp_dir .. "/2026-03-01-abort-" .. os.time() .. ".md"
        vim.fn.writefile({ "", "# topic: t", "- file: x.md", "---", "", "💬: What is Lua?" }, test_file)
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_cursor(0, { 6, 0 }) -- on the 💬 question line

        local saved_query = parley.dispatcher.query
        local mock_called, saw_fn, lines_at_query = false, false, nil
        parley.dispatcher.query = function(_b, _p, _pl, _h, _oe, _cb, _op, on_abort)
            mock_called = true
            saw_fn = type(on_abort) == "function"
            lines_at_query = vim.api.nvim_buf_line_count(buf)
            if on_abort then on_abort("test abort") end
        end
        local notes = {}
        local saved_notify = vim.notify
        vim.notify = function(msg, level)
            table.insert(notes, { msg = msg, level = level })
        end

        pcall(function() parley.chat_respond({ range = 0 }) end)
        vim.wait(1000, function()
            return vim.tbl_contains(vim.tbl_map(function(n) return n.msg end, notes), "test abort")
        end, 10)

        parley.dispatcher.query = saved_query
        vim.notify = saved_notify

        assert.is_true(mock_called, "dispatcher.query mock was not reached") -- respond got to the query
        assert.is_true(saw_fn) -- on_abort passed at arg position 8
        assert.is_truthy(lines_at_query) -- the placeholder was inserted before the query
        assert.is_truthy(vim.tbl_contains(vim.tbl_map(function(n) return n.msg end, notes), "test abort"))
        local lines_after = vim.api.nvim_buf_line_count(buf)
        assert.is_truthy(lines_after < lines_at_query) -- collapse removed the empty answer block
    end)

    -- skill_invoke: mock D.query to invoke the real on_abort (arg 8); assert the
    -- _in_flight guard is cleared so the buffer isn't blocked forever (#131).
    it("skill_invoke on_abort clears the _in_flight guard", function()
        local skill_invoke = require("parley.skill_invoke")

        -- a minimal real file + buffer to satisfy invoke's file-path/save steps
        local doc = tmp_dir .. "/doc.md"
        vim.fn.writefile({ "hello world" }, doc)
        vim.cmd("edit " .. doc)
        local buf = vim.api.nvim_get_current_buf()

        -- a minimal manifest with a body source + a resolvable agent
        local manifest = {
            name = "testskill",
            source = function() return "System prompt for the test skill." end,
            agent = "agentX",
        }

        local saved_get_agent = parley.get_agent
        parley.get_agent = function()
            return { provider = "cliproxyapi", model = { model = "claude-x" }, name = "agentX" }
        end
        local saved_query = parley.dispatcher.query
        local saw_fn = false
        parley.dispatcher.query = function(_b, _p, _pl, _h, _oe, _cb, _op, on_abort)
            saw_fn = type(on_abort) == "function"
            if on_abort then on_abort("test abort") end
        end

        pcall(function() skill_invoke.invoke(buf, manifest, {}, {}) end)
        vim.wait(300, function() return not skill_invoke.is_in_flight(buf) end, 10)

        parley.get_agent = saved_get_agent
        parley.dispatcher.query = saved_query

        assert.is_true(saw_fn) -- on_abort wired at arg position 8
        assert.is_false(skill_invoke.is_in_flight(buf)) -- guard cleared, buffer not blocked
    end)
end)
