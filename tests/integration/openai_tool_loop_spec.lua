-- End-to-end OpenAI tool loop against a process-level fake (#198 M2).
--
-- The unit specs pin each wire function in isolation. This one proves the
-- pieces compose: a real curl request to a real HTTP server, a real SSE
-- stream, the real decoder, the real tool dispatcher executing a real file
-- read, and the real 🔧:/📎: buffer writes — with nothing stubbed on the
-- parley side.
--
-- ARCH-MOCK: the fake is stateful. It decides which round it is in by
-- inspecting the REQUEST (a body carrying a role:"tool" message is by
-- definition the second leg), so the two-round loop is modelled rather than
-- counted. A function-call mock cannot catch the interaction bugs this can —
-- notably the class the plan gate caught, where messages reached the wire
-- untranslated.

local uv = vim.uv or vim.loop
local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

local dispatcher = require("parley.dispatcher")
local ready_port = require("tests.helpers.ready_port")
local tool_loop = require("parley.tool_loop")
local registry = require("parley.tools")
local vault = require("parley.vault")
local parley = require("parley")

local started = {}


local function start_fake(port, response_mode, env)
    local handle, pid = uv.spawn(FAKE, {
        args = { "--port", tostring(port), "--response-mode", response_mode },
        env = env,
    }, function() end)
    assert(handle, "spawn fake")
    table.insert(started, pid)
    -- wait for the listener
    local up = false
    vim.wait(5000, function()
        local c = uv.new_tcp()
        c:connect("127.0.0.1", port, function(err)
            up = err == nil
            c:close()
        end)
        vim.wait(50, function() return false end)
        return up
    end, 50)
    assert(up, "fake did not come up on port " .. port)
    return pid
end

describe("openai tool loop against a stateful fake (#198)", function()
    local port, tmpdir, file_a, file_b
    local saved_endpoint, saved_manage

    before_each(function()
        registry.register_builtins()
        parley._state = parley._state or {}
        parley._state.web_search = false

        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        file_a = tmpdir .. "/alpha.txt"
        file_b = tmpdir .. "/beta.txt"
        vim.fn.writefile({ "ALPHA-CONTENT" }, file_a)
        vim.fn.writefile({ "BETA-CONTENT" }, file_b)

        port = ready_port.free_port()
        saved_endpoint = dispatcher.providers.cliproxyapi
            and dispatcher.providers.cliproxyapi.endpoint
        dispatcher.providers.cliproxyapi = dispatcher.providers.cliproxyapi or {}
        dispatcher.providers.cliproxyapi.endpoint =
            "http://127.0.0.1:" .. port .. "/v1/chat/completions"
        -- Do not let the managed-proxy hook try to start a real binary.
        local cliproxy = require("parley.cliproxy")
        saved_manage = cliproxy.is_managed
        cliproxy.is_managed = function() return false end

        vault.add_secret("cliproxyapi", "testkey")
    end)

    after_each(function()
        for _, pid in ipairs(started) do
            pcall(function() uv.kill(pid, "sigterm") end)
        end
        started = {}
        if saved_endpoint then
            dispatcher.providers.cliproxyapi.endpoint = saved_endpoint
        end
        require("parley.cliproxy").is_managed = saved_manage
        registry.register_builtins()
    end)

    -- Drive one request and hand the captured stream to the tool loop, which
    -- is exactly what chat_respond's on_exit does.
    local function run_round(bufnr, messages, model)
        start_fake(port, "tool_call", {
            "PARLEY_FAKE_TOOL_PATH_A=" .. file_a,
            "PATH=" .. (vim.env.PATH or ""),
        })

        local payload = dispatcher.prepare_payload(messages, model, "cliproxyapi", { "read_file" })
        local done, raw = false, nil
        dispatcher.query(nil, "cliproxyapi", payload, function() end, function(qid)
            raw = (require("parley.tasker").get_query(qid) or {}).raw_response
            done = true
        end)
        vim.wait(15000, function() return done end, 50)
        assert.is_true(done, "query never completed")
        return raw, payload
    end

    it("completes a tool round: request → tool_calls → execute → buffer blocks", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "💬: read alpha", "🤖: [ToolSol*]" })

        local raw = run_round(bufnr,
            { { role = "user", content = "read alpha" } },
            { model = "gpt-5.6-sol" })

        assert.is_truthy(raw, "no raw response captured")
        assert.matches("tool_calls", raw)

        local outcome = tool_loop.process_response(bufnr, raw, {
            provider = "cliproxyapi",
            model = { model = "gpt-5.6-sol" },
            max_tool_iterations = 20,
            cwd = tmpdir,
        })

        assert.equals("recurse", outcome)
        local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
        assert.matches("🔧: read_file id=call_fake_a", text)
        assert.matches("📎: read_file id=call_fake_a", text)
        -- the tool actually ran against the real file
        assert.matches("ALPHA%-CONTENT", text)
    end)

    it("second leg: a request carrying role:tool gets a plain answer, loop ends", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "💬: read alpha", "🤖: [ToolSol*]" })

        -- history with a completed tool round, in parley's internal shape;
        -- prepare_payload must translate it into role:"tool" for the fake to
        -- recognise the second leg at all. That IS the assertion.
        local raw = run_round(bufnr, {
            { role = "user", content = "read alpha" },
            { role = "assistant", content = {
                { type = "tool_use", id = "call_fake_a", name = "read_file",
                  input = { path = file_a } },
            } },
            { role = "user", content = {
                { type = "tool_result", tool_use_id = "call_fake_a", content = "ALPHA-CONTENT" },
            } },
        }, { model = "gpt-5.6-sol" })

        assert.matches("the tool result was received", raw)
        local outcome = tool_loop.process_response(bufnr, raw, {
            provider = "cliproxyapi",
            model = { model = "gpt-5.6-sol" },
            max_tool_iterations = 20,
            cwd = tmpdir,
        })
        assert.equals("done", outcome)
    end)

    it("the request body carries translated messages, not content blocks", function()
        local payload = dispatcher.prepare_payload({
            { role = "user", content = "read alpha" },
            { role = "assistant", content = {
                { type = "tool_use", id = "call_fake_a", name = "read_file",
                  input = { path = file_a } },
            } },
            { role = "user", content = {
                { type = "tool_result", tool_use_id = "call_fake_a", content = "ALPHA-CONTENT" },
            } },
        }, { model = "gpt-5.6-sol" }, "cliproxyapi", { "read_file" })

        local roles = {}
        for _, m in ipairs(payload.messages) do table.insert(roles, m.role) end
        assert.same({ "user", "assistant", "tool" }, roles)
        assert.equals("function", payload.tools[1].type)
    end)

    it("executes parallel tool calls in one round", function()
        start_fake(port, "tool_call_parallel", {
            "PARLEY_FAKE_TOOL_PATH_A=" .. file_a,
            "PARLEY_FAKE_TOOL_PATH_B=" .. file_b,
            "PATH=" .. (vim.env.PATH or ""),
        })

        local payload = dispatcher.prepare_payload(
            { { role = "user", content = "read both" } },
            { model = "gpt-5.6-sol" }, "cliproxyapi", { "read_file" })
        local done, raw = false, nil
        dispatcher.query(nil, "cliproxyapi", payload, function() end, function(qid)
            raw = (require("parley.tasker").get_query(qid) or {}).raw_response
            done = true
        end)
        vim.wait(15000, function() return done end, 50)
        assert.is_true(done, "query never completed")

        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "💬: read both", "🤖: [ToolSol*]" })
        local outcome = tool_loop.process_response(bufnr, raw, {
            provider = "cliproxyapi",
            model = { model = "gpt-5.6-sol" },
            max_tool_iterations = 20,
            cwd = tmpdir,
        })

        assert.equals("recurse", outcome)
        local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
        assert.matches("🔧: read_file id=call_fake_a", text)
        assert.matches("🔧: read_file id=call_fake_b", text)
        assert.matches("ALPHA%-CONTENT", text)
        assert.matches("BETA%-CONTENT", text)
    end)
end)
