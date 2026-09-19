-- Per-caller on_abort teardown tests (issue #131, boundary-review Important #3).
--
-- The e2e spec proves the abort CHAIN reaches on_abort via a spy; these drive
-- the REAL teardown bodies at each D.query caller so an arg-position regression
-- or a response-retirement bug is actually caught.

-- Fixture strings, not transport tokens: the harness watch for a refusal
-- with no words expects them (#261 M5).
vim.g.parley_expected_unkeyed={'test abort'}
local uv = vim.uv or vim.loop
local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/parley-cliproxy-teardown-" .. os.time()
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
local ready_port = require("tests.helpers.ready_port")
parley.setup({
    -- Teardown begins after model selection; the learner placeholder is unrelated.
    default_agent = "TeardownTest",
    agents = { { name = "TeardownTest", provider = "cliproxyapi", model = "claude-x",
        system_prompt = "Test assistant" } },
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

local cliproxy = require("parley.cliproxy")
local vault = require("parley.vault")

-- Redirect cliproxy's derived-artifact dir to a temp dir. Without this, a bare
-- `PlenaryBustedFile` run (outside `make`, so no XDG_DATA_HOME redirect) writes
-- the rendered config into the operator's REAL ~/.local/share/nvim — and the
-- running proxy's file watcher reloads it, leaving their live proxy answering on
-- a test port with a test api-key. That happened during #205.
require("parley.cliproxy")._set_data_dir(vim.fn.tempname())

local started = {}


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
        local port = ready_port.free_port()
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

    -- Public submission reaches the real response-provider abort callback at
    -- argument 8 and retires its write authority after positive transport stop.
    it("chat_respond on_abort retires the response and preserves its question", function()
        local test_file = tmp_dir .. "/2026-03-01.12-00-00.000_abort.md"
        local original = { "", "# topic: t", "- file: x.md", "---", "", "💬: What is Lua?" }
        vim.fn.writefile(original, test_file)
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_cursor(0, { 6, 0 })
        -- Earlier negative-path fixtures leave errors in Neovim's message area.
        -- Consume that redraw before timing asynchronous response completion.
        vim.cmd("redraw!")
        local saved_query = parley.dispatcher.query
        local mock_called, saw_fn = false, false
        parley.dispatcher.query = function(_b, _p, _pl, _h, _oe, _cb, _op, on_abort)
            mock_called = true
            saw_fn = type(on_abort) == "function"
            if on_abort then on_abort("test abort") end
        end
        local Respond = require("parley.chat_respond")
        local started, response = pcall(Respond.respond, { range = 0 })
        local settled = started and response and vim.wait(1000, function()
            return Respond.response_snapshot(response).status == "terminal"
        end, 10)
        parley.dispatcher.query = saved_query
        assert.is_true(started, tostring(response))
        assert.is_true(mock_called, "dispatcher.query mock was not reached")
        assert.is_true(saw_fn)
        assert.is_true(settled, vim.inspect(Respond.response_snapshot(response)))
        local generation = Respond.response_snapshot(response).generation
        assert.equals("provider_failed", generation.outcome)
        -- A transport string the vocabulary cannot resolve is the diagnosis, not
        -- the token the words are keyed by (#261 M5 close: BR-88).
        assert.is_nil(generation.failure)
        assert.equals("test abort", generation.diagnosis)
        assert.equals(0, generation.outstanding_operations)
        local Document = require("parley.document")
        assert.same({}, Document.snapshot(Document.get(buf)).grants)
        assert.same(original, vim.api.nvim_buf_get_lines(buf, 0, #original, false))
        assert.is_nil(require("parley.chat_pending").identity(buf))
        vim.api.nvim_buf_delete(buf, { force = true })
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

    it("skill_invoke transport terminal uses argument 10 exactly once", function()
        local skill_invoke = require("parley.skill_invoke")
        local doc = tmp_dir .. "/transport-doc.md"
        vim.fn.writefile({ "hello world" }, doc)
        vim.cmd("edit " .. doc)
        local buf = vim.api.nvim_get_current_buf()
        local manifest = {
            name = "testskill",
            source = function() return "System prompt." end,
            agent = "agentX",
        }
        local saved_get_agent = parley.get_agent
        parley.get_agent = function()
            return { provider = "cliproxyapi", model = { model = "claude-x" }, name = "agentX" }
        end
        local saved_query = parley.dispatcher.query
        local on_exit, on_error
        parley.dispatcher.query = function(_b, _p, _pl, _h, exit, _cb, _op, _abort, _activity, err)
            on_exit, on_error = exit, err
        end
        local events = {}
        skill_invoke.invoke(buf, manifest, {}, {
            detached_progress = false,
            on_terminal = function() table.insert(events, "terminal") end,
            on_done = function() table.insert(events, "done") end,
        })
        on_error("q", { code = 7 })
        on_exit("q")
        vim.wait(100, function() return false end)
        parley.get_agent = saved_get_agent
        parley.dispatcher.query = saved_query

        assert.are.same({ "terminal", "done" }, events)
        assert.is_false(skill_invoke.is_in_flight(buf))
    end)
end)
