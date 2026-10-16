-- #242 M1: the Anthropic provider through the REAL path, dispatcher.query ->
-- curl -> out_reader, against fake_provider's anthropic dialect. One case per
-- row of the plan's scenario table; the fake is structurally faithful, not
-- intelligent (its bytes come from sse_dialects, built on the recorded fixtures).
local dispatcher = require("parley.dispatcher")
local scenarios = require("tests.helpers.provider_scenarios")
local fixture_process = require("tests.helpers.fixture_process")
local wire = require("parley.tools.wire_anthropic")

local MODEL = { model = "claude-sonnet-4-6" }
local FIXTURE_TEXT = "Hello, world! 👋"
local function messages(text) return { { role = "user", content = text or "hi" } } end
local function payload(msgs, tools) return dispatcher.prepare_payload(msgs, MODEL, "anthropic", tools) end
local function any(lines, needle)
    for _, l in ipairs(lines) do if l:find(needle, 1, true) then return true end end
    return false
end

describe("anthropic through dispatcher -> curl -> fake_provider (#242)", function()
    local mark, log
    before_each(function()
        mark = fixture_process.mark()
        log = vim.fn.tempname() .. "-requests.jsonl"
        require("parley.tools").register_builtins()
    end)
    after_each(function()
        fixture_process.reap({ since = mark, signal = "sigterm" })
        vim.fn.delete(log) -- the spec owns the request log (PQ-4)
    end)

    it("S1 plain stream: the answer is the fake's text, byte for byte, with no notice", function()
        local port = scenarios.start("anthropic", "ok")
        local out = scenarios.query("anthropic", port, payload(messages()))
        assert.is_nil(out.failure)
        assert.equals(FIXTURE_TEXT, out.response)
        assert.same({}, out.errors)
    end)

    it("S2 two-call tool loop: the second request carries the first call's tool_result", function()
        local port = scenarios.start("anthropic", "ok", nil, { PARLEY_FAKE_REQUEST_LOG = log })
        local first = scenarios.query("anthropic", port, payload(messages("read it"), { "read_file" }))
        assert.is_nil(first.failure)
        local calls = wire.decode_tool_calls_from_stream(first.qt.raw_response)
        assert.equals(1, #calls)
        local followup = messages("read it")
        followup[#followup + 1] = { role = "assistant", content = {
            { type = "tool_use", id = calls[1].id, name = calls[1].name, input = calls[1].input } } }
        followup[#followup + 1] = { role = "user", content = {
            { type = "tool_result", tool_use_id = calls[1].id, content = "README CONTENT" } } }
        local second = scenarios.query("anthropic", port, payload(followup, { "read_file" }))
        assert.is_nil(second.failure)
        assert.equals("Done: the tool result was received.", second.response)
        local sent = scenarios.requests(log)
        assert.equals(2, #sent)
        local last = sent[2].json.messages[#sent[2].json.messages]
        local block = type(last.content) == "table" and last.content[1] or {}
        assert.equals("tool_result", block.type)
        assert.equals(calls[1].id, block.tool_use_id)
    end)

    it("S3 in-band error mid-stream: the truncation notice names the error, not a clean answer (#228)", function()
        local port = scenarios.start("anthropic", "inband_error")
        local out = scenarios.query("anthropic", port, payload(messages()))
        assert.equals("Starting the answer and then ", out.response)
        -- Text arrived first, so the dispatcher logs the ending at warning
        -- level: the answer is truncated by the provider's in-band error.
        assert.is_true(any(out.warnings, "in-band — Overloaded"), "no in-band notice: " .. vim.inspect(out.warnings))
    end)

    for _, case in ipairs({ { 429, "rate limit" }, { 529, "Overloaded" }, { 500, "Internal server error" } }) do
        local status, message = case[1], case[2]
        it("S4 HTTP " .. status .. ": a failure carrying the API's message, and no retry", function()
            local port = scenarios.start("anthropic", "http_" .. status, nil, { PARLEY_FAKE_REQUEST_LOG = log })
            local out = scenarios.query("anthropic", port, payload(messages()))
            assert.is_table(out.failure, "an HTTP " .. status .. " completed as success")
            assert.equals(status, out.failure.http_status)
            assert.is_truthy(tostring(out.failure.body):find(message, 1, true), vim.inspect(out.failure))
            assert.equals(1, #scenarios.requests(log), "the request was retried")
        end)
    end

    it("S5 output cap: the cap notice, and the partial answer kept (#228)", function()
        local port = scenarios.start("anthropic", "cap")
        local out = scenarios.query("anthropic", port, payload(messages()))
        assert.is_nil(out.failure)
        assert.equals("The answer was cut off at the cap", out.response)
        assert.is_true(any(out.warnings, "max_tokens") or any(out.errors, "max_tokens"),
            "no cap notice: " .. vim.inspect({ out.warnings, out.errors }))
    end)

    it("S6 split frames: every SSE frame split at every byte boundary, same answer", function()
        local port = scenarios.start("anthropic", "ok", "every_byte")
        local started, raw_at_first_chunk = vim.uv.now(), nil
        local out = scenarios.query("anthropic", port, payload(messages()), {
            on_chunk = function(n, _, qt) if n == 1 then raw_at_first_chunk = #qt.raw_response end end,
        })
        assert.is_nil(out.failure)
        assert.equals(FIXTURE_TEXT, out.response)
        -- The split reached the reader: the first answer piece was decoded
        -- before the body had fully arrived. One coalesced read would not.
        assert.is_true(raw_at_first_chunk < #out.qt.raw_response,
            ("the stream arrived in one read (%s of %d bytes)"):format(tostring(raw_at_first_chunk), #out.qt.raw_response))
        assert.is_true(vim.uv.now() - started < 5000, "the split case exceeded its 5 s envelope (PQ-7)")
    end)

    for _, split in ipairs({ "frames", "random:7" }) do
        it("S6 split " .. split .. ": same answer", function()
            local out = scenarios.query("anthropic", scenarios.start("anthropic", "ok", split), payload(messages()))
            assert.is_nil(out.failure)
            assert.equals(FIXTURE_TEXT, out.response)
        end)
    end

    it("thinking: the reasoning reaches on_progress and only the text is the answer", function()
        local out = scenarios.query("anthropic", scenarios.start("anthropic", "thinking"), payload(messages()))
        assert.is_nil(out.failure)
        assert.equals(FIXTURE_TEXT, out.response)
        local reasoning = {}
        for _, e in ipairs(out.progress) do
            if e.kind == "reasoning" then reasoning[#reasoning + 1] = e.text end
        end
        assert.same({ "Let me plan the answer." }, reasoning, vim.inspect(out.progress))
    end)

    it("no stop reason: the answer is kept, and the ending is not reported as a clean finish", function()
        local out = scenarios.query("anthropic", scenarios.start("anthropic", "no_stop"), payload(messages()))
        assert.is_nil(out.failure)
        assert.equals(FIXTURE_TEXT, out.response)
        assert.equals("unknown", dispatcher._classify_ending(out.qt).class)
    end)

    it("S7a disconnect after N bytes: a failure, and the partial answer kept", function()
        local port = scenarios.start("anthropic", "disconnect_after:600")
        local out = scenarios.query("anthropic", port, payload(messages()))
        assert.is_table(out.failure, "a truncated transfer completed as success")
        assert.is_truthy(out.failure.exit, "the failure does not say how the transfer ended")
        -- The 600-byte cut ends after the first text delta.
        assert.equals("Hello,", out.qt.response)
        assert.is_true(out.failure.streamed)
    end)

    it("S7b a throwing output handler stops the attempt; no later chunk is consumed (#229)", function()
        local port = scenarios.start("anthropic", "ok", "every_byte")
        local out = scenarios.query("anthropic", port, payload(messages()), {
            on_chunk = function(n) if n == 1 then error("consumer invalidated mid-stream") end end,
        })
        assert.is_table(out.failure, "the attempt went on after its reader threw")
        assert.is_truthy(tostring(out.failure.exit):find("reader", 1, true), vim.inspect(out.failure.exit))
        assert.equals(1, #out.chunks, "chunks were consumed after the throw")
    end)

    it("S7b frame-aligned reads: the line that threw is never decoded again at EOF (#242)", function()
        -- One frame per read, so the throwing line's read ends at its newline.
        -- That left the line in the reader's buffer, and the EOF flush decoded
        -- it a second time: the same delta written twice.
        local port = scenarios.start("anthropic", "ok", "frames", nil, 20)
        local out = scenarios.query("anthropic", port, payload(messages()), {
            on_chunk = function(n) if n == 1 then error("consumer invalidated mid-stream") end end,
        })
        assert.is_table(out.failure, "the attempt went on after its reader threw")
        assert.same({ "Hello," }, out.chunks)
    end)
end)
