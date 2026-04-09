-- Unit tests for anthropic.decode_tool_calls_from_stream in
-- lua/parley/providers.lua.
--
-- The decoder walks the full captured SSE response (produced by the
-- existing curl-based streaming path) and assembles a list of
-- client-side ToolCalls the tool_loop should dispatch.
--
-- Anthropic's tool use streaming shape (per docs):
--
--   data: {"type":"content_block_start","index":1,
--          "content_block":{"type":"tool_use","id":"toolu_X","name":"read_file","input":{}}}
--   data: {"type":"content_block_delta","index":1,
--          "delta":{"type":"input_json_delta","partial_json":"{\"pa"}}
--   data: {"type":"content_block_delta","index":1,
--          "delta":{"type":"input_json_delta","partial_json":"th\":\"foo.txt\"}"}}
--   data: {"type":"content_block_stop","index":1}
--   data: {"type":"message_delta", ...}
--   data: {"type":"message_stop"}
--
-- The decoder must:
--   1. Recognize content_block_start with type=tool_use
--   2. Accumulate input_json_delta.partial_json by index
--   3. On content_block_stop, decode the assembled JSON into input
--   4. Return the list of ToolCalls in the order they were streamed
--   5. IGNORE server-side tools (server_tool_use / web_search /
--      web_fetch) — those are resolved by Anthropic server-side and
--      do not need a client-side tool_result
--   6. IGNORE text and thinking blocks
--
-- Fixtures are synthetic, based on Anthropic's official tool use
-- streaming documentation. A second fixture captured from a real
-- API call should be added later (see
-- scripts/capture_anthropic_tool_use_stream.sh) and tested here to
-- lock in doc-vs-reality parity.

local providers = require("parley.providers")

-- Helper: build a raw SSE response from a list of event objects.
-- Each Anthropic streaming event is `event: <type>\ndata: <json>\n\n`
-- but the existing parse_usage walker uses a simple line-based
-- gmatch, so we only need to ensure each `data: { ... }` payload
-- lives on its own line.
local function sse(events)
    local out = {}
    for _, ev in ipairs(events) do
        table.insert(out, "event: " .. (ev.type or "unknown"))
        table.insert(out, "data: " .. vim.json.encode(ev))
        table.insert(out, "")
    end
    return table.concat(out, "\n")
end

describe("anthropic.decode_tool_calls_from_stream (synthetic fixtures)", function()
    it("returns empty list when the stream has no tool_use blocks", function()
        local raw = sse({
            { type = "message_start", message = { id = "msg_1", model = "claude-sonnet-4-6" } },
            { type = "content_block_start", index = 0, content_block = { type = "text", text = "" } },
            { type = "content_block_delta", index = 0, delta = { type = "text_delta", text = "Hello" } },
            { type = "content_block_stop", index = 0 },
            { type = "message_delta", delta = { stop_reason = "end_turn" }, usage = { output_tokens = 5 } },
            { type = "message_stop" },
        })
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.same({}, calls)
    end)

    it("decodes a single tool_use with all input streamed in one delta", function()
        local raw = sse({
            { type = "message_start", message = { id = "msg_2" } },
            { type = "content_block_start", index = 0,
              content_block = { type = "tool_use", id = "toolu_A", name = "read_file", input = {} } },
            { type = "content_block_delta", index = 0,
              delta = { type = "input_json_delta", partial_json = '{"path":"foo.txt"}' } },
            { type = "content_block_stop", index = 0 },
            { type = "message_stop" },
        })
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.equals(1, #calls)
        assert.equals("toolu_A", calls[1].id)
        assert.equals("read_file", calls[1].name)
        assert.same({ path = "foo.txt" }, calls[1].input)
    end)

    it("decodes a single tool_use with input streamed across multiple deltas", function()
        local raw = sse({
            { type = "content_block_start", index = 0,
              content_block = { type = "tool_use", id = "toolu_B", name = "edit_file", input = {} } },
            { type = "content_block_delta", index = 0,
              delta = { type = "input_json_delta", partial_json = '{"pa' } },
            { type = "content_block_delta", index = 0,
              delta = { type = "input_json_delta", partial_json = 'th":"foo' } },
            { type = "content_block_delta", index = 0,
              delta = { type = "input_json_delta", partial_json = '.txt","old_string":"a","new_string":"b"}' } },
            { type = "content_block_stop", index = 0 },
            { type = "message_stop" },
        })
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.equals(1, #calls)
        assert.equals("edit_file", calls[1].name)
        assert.equals("foo.txt", calls[1].input.path)
        assert.equals("a", calls[1].input.old_string)
        assert.equals("b", calls[1].input.new_string)
    end)

    it("decodes multiple tool_use blocks in one message, preserving order", function()
        -- Parallel tool calls: model emits multiple tool_use blocks
        -- before stopping. Each has its own index.
        local raw = sse({
            { type = "content_block_start", index = 0,
              content_block = { type = "tool_use", id = "toolu_1", name = "read_file", input = {} } },
            { type = "content_block_delta", index = 0,
              delta = { type = "input_json_delta", partial_json = '{"path":"a.txt"}' } },
            { type = "content_block_stop", index = 0 },
            { type = "content_block_start", index = 1,
              content_block = { type = "tool_use", id = "toolu_2", name = "list_dir", input = {} } },
            { type = "content_block_delta", index = 1,
              delta = { type = "input_json_delta", partial_json = '{"path":"lua/"}' } },
            { type = "content_block_stop", index = 1 },
            { type = "message_stop" },
        })
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.equals(2, #calls)
        assert.equals("toolu_1", calls[1].id)
        assert.equals("read_file", calls[1].name)
        assert.equals("a.txt", calls[1].input.path)
        assert.equals("toolu_2", calls[2].id)
        assert.equals("list_dir", calls[2].name)
        assert.equals("lua/", calls[2].input.path)
    end)

    it("handles interleaved text + tool_use (assistant explains then calls)", function()
        local raw = sse({
            { type = "content_block_start", index = 0, content_block = { type = "text", text = "" } },
            { type = "content_block_delta", index = 0, delta = { type = "text_delta", text = "Let me read that file." } },
            { type = "content_block_stop", index = 0 },
            { type = "content_block_start", index = 1,
              content_block = { type = "tool_use", id = "toolu_C", name = "read_file", input = {} } },
            { type = "content_block_delta", index = 1,
              delta = { type = "input_json_delta", partial_json = '{"path":"foo"}' } },
            { type = "content_block_stop", index = 1 },
            { type = "message_stop" },
        })
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.equals(1, #calls)
        assert.equals("toolu_C", calls[1].id)
    end)

    it("handles a tool_use with empty input (partial_json is '{}')", function()
        local raw = sse({
            { type = "content_block_start", index = 0,
              content_block = { type = "tool_use", id = "toolu_D", name = "list_dir", input = {} } },
            { type = "content_block_delta", index = 0,
              delta = { type = "input_json_delta", partial_json = '{}' } },
            { type = "content_block_stop", index = 0 },
            { type = "message_stop" },
        })
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.equals(1, #calls)
        assert.is_table(calls[1].input)
    end)

    it("handles a tool_use with NO input deltas at all (malformed stream)", function()
        -- Defensive: if the model opens a tool_use block and stops it
        -- without streaming any input JSON, we still want a ToolCall
        -- with id/name/empty-input rather than dropping it entirely.
        local raw = sse({
            { type = "content_block_start", index = 0,
              content_block = { type = "tool_use", id = "toolu_E", name = "read_file", input = {} } },
            { type = "content_block_stop", index = 0 },
            { type = "message_stop" },
        })
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.equals(1, #calls)
        assert.equals("toolu_E", calls[1].id)
        assert.equals("read_file", calls[1].name)
        assert.same({}, calls[1].input)
    end)

    it("IGNORES server_tool_use blocks (web_search is resolved server-side)", function()
        local raw = sse({
            { type = "content_block_start", index = 0,
              content_block = { type = "server_tool_use", id = "srvtool_1", name = "web_search", input = {} } },
            { type = "content_block_delta", index = 0,
              delta = { type = "input_json_delta", partial_json = '{"query":"x"}' } },
            { type = "content_block_stop", index = 0 },
            { type = "message_stop" },
        })
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.same({}, calls)
    end)

    it("IGNORES thinking blocks", function()
        local raw = sse({
            { type = "content_block_start", index = 0, content_block = { type = "thinking", thinking = "" } },
            { type = "content_block_delta", index = 0, delta = { type = "thinking_delta", thinking = "hmm" } },
            { type = "content_block_stop", index = 0 },
            { type = "message_stop" },
        })
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.same({}, calls)
    end)

    it("coexists with server-side and client-side tools in same message", function()
        -- Mixed scenario: web_search (server-side) + read_file (client-side).
        -- Only read_file should appear in the decoded list.
        local raw = sse({
            { type = "content_block_start", index = 0,
              content_block = { type = "server_tool_use", id = "srv_1", name = "web_search", input = {} } },
            { type = "content_block_delta", index = 0,
              delta = { type = "input_json_delta", partial_json = '{"query":"lua"}' } },
            { type = "content_block_stop", index = 0 },
            { type = "content_block_start", index = 1,
              content_block = { type = "web_search_tool_result", content = "results..." } },
            { type = "content_block_stop", index = 1 },
            { type = "content_block_start", index = 2,
              content_block = { type = "tool_use", id = "toolu_F", name = "read_file", input = {} } },
            { type = "content_block_delta", index = 2,
              delta = { type = "input_json_delta", partial_json = '{"path":"x"}' } },
            { type = "content_block_stop", index = 2 },
            { type = "message_stop" },
        })
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.equals(1, #calls)
        assert.equals("toolu_F", calls[1].id)
        assert.equals("read_file", calls[1].name)
    end)

    it("returns empty list for malformed/empty raw response", function()
        assert.same({}, providers.decode_anthropic_tool_calls_from_stream(""))
        assert.same({}, providers.decode_anthropic_tool_calls_from_stream("garbage\ndata: not json\n"))
    end)

    it("tolerates missing `index` field by defaulting to 0", function()
        -- Defensive: some event shapes might omit index. If there's
        -- only one block, default-to-0 keeps the accumulation working.
        local raw = sse({
            { type = "content_block_start",
              content_block = { type = "tool_use", id = "toolu_G", name = "read_file", input = {} } },
            { type = "content_block_delta",
              delta = { type = "input_json_delta", partial_json = '{"path":"a"}' } },
            { type = "content_block_stop" },
            { type = "message_stop" },
        })
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.equals(1, #calls)
        assert.equals("a", calls[1].input.path)
    end)
end)

-- ---------------------------------------------------------------------------
-- Real-data fixture — captured by scripts/capture_anthropic_tool_use_stream.sh
-- against the live Anthropic API (claude-sonnet-4-6). The prompt asks the
-- model to read lua/parley/init.lua. This second test block is the doc-vs-
-- reality parity gate. If any assertion here fails after a future Anthropic
-- API change, real-data wins and the decoder is updated.
--
-- Observed real-stream shape vs synthetic (captured 2026-04-09):
--   - Trailing whitespace on JSON payload lines (decoder must tolerate — it
--     does, because vim.json.decode accepts trailing whitespace).
--   - Extra `event: ping` / `data: {"type": "ping"}` events interleaved with
--     content events. Decoder ignores unknown types correctly.
--   - `content_block_start` carries `caller: {type: "direct"}` on the tool_use
--     block (field we don't use). Harmless.
--   - First `input_json_delta` may have `partial_json = ""` before real JSON
--     starts streaming. Decoder handles by appending empty string.
--   - `message_delta` carries `stop_reason = "tool_use"` (not used by decoder).
--   - `message_start` has extra fields (cache_creation, inference_geo,
--     service_tier) not modeled in synthetic. Decoder ignores them.
-- ---------------------------------------------------------------------------
describe("anthropic.decode_tool_calls_from_stream (real fixture)", function()
    local function read_fixture()
        local f = io.open("tests/fixtures/anthropic_tool_use_stream_real.jsonl", "r")
        if not f then return nil end
        local raw = f:read("*a")
        f:close()
        return raw
    end

    it("real fixture exists (skip if user hasn't run capture script)", function()
        local raw = read_fixture()
        if not raw then
            pending("tests/fixtures/anthropic_tool_use_stream_real.jsonl not found — run scripts/capture_anthropic_tool_use_stream.sh")
            return
        end
        assert.is_string(raw)
        assert.is_true(#raw > 0)
    end)

    it("decodes the captured stream to exactly one ToolCall", function()
        local raw = read_fixture()
        if not raw then pending("no real fixture"); return end
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.equals(1, #calls)
    end)

    it("the ToolCall has a toolu_* id", function()
        local raw = read_fixture()
        if not raw then pending("no real fixture"); return end
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.matches("^toolu_", calls[1].id)
    end)

    it("the ToolCall name is read_file (the prompt was deliberate)", function()
        local raw = read_fixture()
        if not raw then pending("no real fixture"); return end
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.equals("read_file", calls[1].name)
    end)

    it("the ToolCall input has a path field (assembled from partial_json chunks)", function()
        -- The prompt asked Claude to read lua/parley/init.lua. The model
        -- may pick "lua/parley/init.lua" exactly, or a trivially different
        -- variant. We assert the path field is present and looks like a
        -- parley source file path.
        local raw = read_fixture()
        if not raw then pending("no real fixture"); return end
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.is_string(calls[1].input.path)
        assert.matches("parley", calls[1].input.path)
        assert.matches("%.lua$", calls[1].input.path)
    end)

    it("real captured input parses to a proper table (not a string of JSON)", function()
        -- Guards against a decoder bug where we'd return the raw JSON
        -- string instead of a decoded table.
        local raw = read_fixture()
        if not raw then pending("no real fixture"); return end
        local calls = providers.decode_anthropic_tool_calls_from_stream(raw)
        assert.is_table(calls[1].input)
        -- And it's not the empty fallback
        assert.is_not_nil(next(calls[1].input))
    end)

    it("trailing whitespace on data lines does not break decoding", function()
        -- The real fixture has lines like `data: {...}    ` with
        -- trailing spaces. This test verifies the decoder's JSON
        -- parse tolerates that. If vim.json.decode ever becomes
        -- strict, we'll catch it here rather than in a production
        -- tool loop.
        local raw = read_fixture()
        if not raw then pending("no real fixture"); return end
        -- A successful decode above proves this implicitly, but
        -- re-check the literal whitespace is in the fixture so we
        -- don't regress the observation. Use plain-text find() so
        -- the whitespace survives Lua pattern interpretation.
        assert.is_not_nil(raw:find("}   ", 1, true), "expected trailing whitespace after } on some data line in the captured fixture")
    end)
end)
