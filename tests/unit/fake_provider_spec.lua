-- #242 Task 2: fake_provider's pure core (sse_dialects.behaviour / split /
-- check_mode, run directly) and its thin shell (spawned, then curled). The
-- shell must fail the way the real API does, and refuse a mode it does not know.
local fixture_process = require("tests.helpers.fixture_process")
local scenarios = require("tests.helpers.provider_scenarios")
local FIXTURES = vim.fn.getcwd() .. "/tests/fixtures"

-- Evaluate a Python expression over sse_dialects; returns its JSON value.
local function py(expr)
    local code = "import json, sys; sys.path.insert(0, sys.argv[1]); import sse_dialects as d; print(json.dumps(" .. expr .. "))"
    local res = vim.system({ "python3", "-I", "-B", "-c", code, FIXTURES }, { text = true }):wait()
    assert(res.code == 0, res.stderr)
    return vim.json.decode(res.stdout)
end

local function post(port, body, path)
    local res = vim.system({ "curl", "-s", "-w", "\n%{http_code}", "-X", "POST", "--max-time", "5",
        "http://127.0.0.1:" .. port .. (path or "/v1/messages"), "-d", body or "{}" }, { text = true }):wait()
    local text, code = res.stdout:match("^(.*)\n(%d+)$")
    return tonumber(code), text, res.code
end

describe("fake_provider: behaviour, split and mode checks (pure) (#242)", function()
    it("chooses the reply from the request, never from a counter", function()
        local cases = {
            { "{}", "ok", "text" },
            { '{"tools":[{"name":"read_file"}]}', "ok", "tool_use" },
            { '{"tools":[{"name":"read_file"}],"messages":[{"role":"user","content":[{"type":"tool_result","tool_use_id":"x"}]}]}',
                "ok", "text" },
            { "{}", "inband_error", "inband_error" }, { "{}", "cap", "cap" }, { "{}", "no_stop", "no_stop" },
            { "{}", "thinking", "thinking" }, { "{}", "cap_empty", "cap" }, { "{}", "inband_error_empty", "inband_error" },
        }
        for _, c in ipairs(cases) do
            local kind = py(("d.behaviour(json.loads(%q), %q)['kind']"):format(c[1], c[2]))
            assert.equals(c[3], kind, c[1] .. " / " .. c[2])
        end
        -- The same request asked twice gets the same reply.
        assert.equals(py("d.behaviour({'tools': [1]}, 'ok')['kind']"), py("d.behaviour({'tools': [1]}, 'ok')['kind']"))
    end)

    it("every split mode concatenates back to the body", function()
        for _, mode in ipairs({ "none", "every_byte", "frames", "random:1", "random:42" }) do
            local ok = py(("all(b''.join(d.split(d.anthropic(r), %q)) == d.anthropic(r) "
                .. "for r in [d.behaviour({}, 'ok'), d.behaviour({'tools': [1]}, 'ok'), d.behaviour({}, 'inband_error')])"):format(mode))
            assert.is_true(ok, mode)
        end
        assert.is_true(py("all(len(s) == 1 for s in d.split(d.anthropic(d.behaviour({}, 'ok')), 'every_byte'))"))
        assert.is_true(py("all(s.endswith(b'\\n\\n') for s in d.split(d.anthropic(d.behaviour({}, 'ok')), 'frames'))"))
    end)

    it("accepts every documented mode and refuses anything else", function()
        for _, mode in ipairs({ "ok", "http_429", "http_529_once", "disconnect_after:600", "thinking", "cap_empty" }) do
            assert.equals(mode, py(("d.check_mode(%q)"):format(mode)))
        end
        for _, mode in ipairs({ "oops", "http_", "http_abc", "http_200", "disconnect_after:x", "cap " }) do
            local res = vim.system({ "python3", "-I", "-B", "-c",
                "import sys; sys.path.insert(0, sys.argv[1]); import sse_dialects as d; d.check_mode(sys.argv[2])",
                FIXTURES, mode }, { text = true }):wait()
            assert.is_not.equals(0, res.code, "accepted " .. mode)
        end
    end)
end)

describe("fake_provider: the shell over the wire (#242)", function()
    local mark, log
    before_each(function()
        mark = fixture_process.mark()
        log = vim.fn.tempname() .. "-requests.jsonl"
    end)
    after_each(function()
        fixture_process.reap({ since = mark, signal = "sigterm" })
        vim.fn.delete(log)
    end)

    it("an HTTP error mode answers that status with the API's error body, every time", function()
        local port = scenarios.start("anthropic", "http_529")
        for _ = 1, 2 do
            local code, body = post(port)
            assert.equals(529, code)
            assert.same({ type = "error", error = { type = "overloaded_error", message = "Overloaded" } }, vim.json.decode(body))
        end
    end)

    it("an _once mode fails only the first request", function()
        local port = scenarios.start("anthropic", "http_429_once")
        assert.equals(429, (post(port)))
        local code, body = post(port)
        assert.equals(200, code)
        assert.is_truthy(body:find('"stop_reason":"end_turn"', 1, true))
    end)

    it("the stream modes answer 200 with their ending", function()
        for mode, needle in pairs({ inband_error = '"type":"error"', cap = '"stop_reason":"max_tokens"',
            thinking = '"type":"thinking_delta"' }) do
            local code, body = post(scenarios.start("anthropic", mode))
            assert.equals(200, code, mode)
            assert.is_truthy(body:find(needle, 1, true), mode)
        end
        local _, no_stop = post(scenarios.start("anthropic", "no_stop"))
        assert.is_nil(no_stop:find("message_delta", 1, true))
    end)

    it("disconnect_after cuts the transfer short, so curl reports a partial file", function()
        local code, body, exit = post(scenarios.start("anthropic", "disconnect_after:600"))
        assert.equals(200, code)
        assert.equals(600, #body)
        assert.equals(18, exit) -- CURLE_PARTIAL_FILE
    end)

    it("an unknown route is a 404", function()
        assert.equals(404, (post(scenarios.start("anthropic", "ok"), "{}", "/v1/other")))
    end)

    it("an unknown mode is refused at startup instead of serving text", function()
        local res = vim.system({ FIXTURES .. "/fake_provider", "--dialect", "anthropic", "--port", "1",
            "--mode", "inbnd_error" }, { text = true }):wait()
        assert.equals(2, res.code)
        assert.is_truthy(res.stderr:find("argument --mode", 1, true), res.stderr)
    end)

    it("writes the request log only when its variable is set", function()
        post(scenarios.start("anthropic", "ok"), '{"a":1}')
        assert.equals(0, vim.fn.filereadable(log))
        post(scenarios.start("anthropic", "ok", nil, { PARLEY_FAKE_REQUEST_LOG = log }), '{"a":1}')
        local entries = scenarios.requests(log)
        assert.equals(1, #entries)
        assert.equals("/v1/messages", entries[1].path)
        assert.same({ a = 1 }, entries[1].json)
    end)
end)
