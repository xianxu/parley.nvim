-- End-to-end dispatch integration for managed cliproxy (issue #131).
--
-- Drives the REAL chain with no stubs on the cliproxy side:
--   dispatcher.query("cliproxyapi", …, on_abort)
--     → providers.cliproxyapi.pre_query  (real)
--       → cliproxy.ensure_running         (real)
--         → health_probe against a process-level fake
--           → on_error  → dispatcher abort channel → on_abort
-- proving the spec's central invariant: a failed managed proxy fails the
-- dispatch fast (never hangs) and a healthy one lets the query proceed.

local uv = vim.uv or vim.loop
local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

local dispatcher = require("parley.dispatcher")
local cliproxy = require("parley.cliproxy")
local vault = require("parley.vault")
local tasker = require("parley.tasker")
local parley = require("parley")

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

describe("managed cliproxy dispatch (e2e)", function()
    local saved_config, saved_providers, saved_tasker_run
    local ran_query

    before_each(function()
        saved_config = parley.config
        saved_providers = dispatcher.providers.cliproxyapi
        saved_tasker_run = tasker.run
        ran_query = false
        -- Capture whether the real query() proceeded to launch curl.
        tasker.run = function() ran_query = true end
        vault.add_secret("cliproxyapi", "testkey")
    end)

    after_each(function()
        parley.config = saved_config
        dispatcher.providers.cliproxyapi = saved_providers
        tasker.run = saved_tasker_run
        for _, pid in ipairs(started) do
            pcall(uv.kill, pid, "sigkill")
        end
        for _, pid in ipairs(cliproxy.spawned_pids()) do
            pcall(uv.kill, pid, "sigkill")
        end
        cliproxy._reset_spawned()
        started = {}
    end)

    local function dispatch(port)
        dispatcher.providers.cliproxyapi = {
            endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(port),
        }
        local outcome = { aborted = false, exited = false }
        dispatcher.query(
            nil, "cliproxyapi",
            { model = "claude-x", messages = { { role = "user", content = "hi" } } },
            function() end,           -- handler
            function() outcome.exited = true end, -- on_exit (qid-coupled)
            nil, nil,
            function(msg)             -- on_abort
                outcome.aborted = true
                outcome.msg = msg
            end
        )
        return outcome
    end

    it("aborts the dispatch (no hang) when the managed proxy is foreign", function()
        local port = free_port()
        start_fake(port, "foreign")
        parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
        local outcome = dispatch(port)
        vim.wait(9000, function() return outcome.aborted or ran_query end, 20)
        assert.is_true(outcome.aborted)   -- on_abort fired (fast-fail)
        assert.is_false(ran_query)        -- the query never launched
        assert.is_truthy(outcome.msg:find("non%-cliproxy"))
    end)

    it("proceeds to the query when the managed proxy is healthy", function()
        local port = free_port()
        start_fake(port, "healthy")
        parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
        local outcome = dispatch(port)
        vim.wait(9000, function() return outcome.aborted or ran_query end, 20)
        assert.is_true(ran_query)         -- query() launched
        assert.is_false(outcome.aborted)  -- no abort
    end)

    it("cold-starts then proceeds, and after stop re-spawns (transient stop)", function()
        local port = free_port()
        vim.env.PARLEY_FAKE_MODE = "healthy"
        parley.config = { cliproxy = { manage = true, binary_path = FAKE } }
        -- nothing listening → ensure_running spawns the fake, then proceeds
        local o1 = dispatch(port)
        vim.wait(9000, function() return o1.aborted or ran_query end, 20)
        assert.is_true(ran_query)
        assert.is_false(o1.aborted)
        assert.is_truthy(#cliproxy.spawned_pids() >= 1)
        -- :ParleyProxy stop is transient — the next dispatch revives it
        cliproxy.stop()
        assert.equals(0, #cliproxy.spawned_pids())
        ran_query = false
        local o2 = dispatch(port)
        vim.wait(9000, function() return o2.aborted or ran_query end, 20)
        assert.is_true(ran_query)
        assert.is_truthy(#cliproxy.spawned_pids() >= 1) -- re-spawned, no manual start
        vim.env.PARLEY_FAKE_MODE = nil
    end)
end)
