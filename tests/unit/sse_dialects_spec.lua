-- #242: the shared SSE dialects emit bytes the REAL decoders read, with the
-- recorded fixtures' event shape. Each case runs the dialect module itself and
-- decodes its output through parley's own parsers.
local providers = require("parley.providers")
local vocabulary = require("tests.helpers.provider_vocabulary")
local MODULE = vim.fn.getcwd() .. "/tests/fixtures/sse_dialects.py"

local function emit(dialect, kind)
    local res = vim.system({ "python3", "-I", MODULE, "emit", dialect, kind }, { text = true }):wait()
    assert(res.code == 0, res.stderr)
    return res.stdout
end

local function decode_text(adapter, raw)
    local out = {}
    for line in raw:gmatch("[^\n]+") do
        local piece = adapter.parse_sse_content(line)
        if piece and piece ~= "" then out[#out + 1] = piece end
    end
    return table.concat(out)
end

local function present(raw, entries)
    local missing = {}
    for _, needle in ipairs(entries) do
        local compact = raw:gsub('": "', '":"')
        if not compact:find(needle, 1, true) then missing[#missing + 1] = needle end
    end
    return missing
end

describe("sse_dialects: anthropic (#242)", function()
    local anthropic = providers.get("anthropic")

    it("text decodes to the fixture's answer, with every vocabulary event", function()
        local raw = emit("anthropic", "text")
        assert.equals("Hello, world! 👋", decode_text(anthropic, raw))
        assert.same({}, present(raw, vocabulary.anthropic.text))
        -- The recorded fixture streams the same event sequence.
        local recorded = table.concat(vim.fn.readfile("tests/fixtures/anthropic_stream.txt"), "\n")
        local function events(s)
            local out = {}
            for name in s:gmatch("event: ([%w_]+)") do out[#out + 1] = name end
            return out
        end
        assert.same(events(recorded), events(raw))
        assert.equals(decode_text(anthropic, recorded), decode_text(anthropic, raw))
    end)

    it("tool_use decodes to one call with its id, name and input", function()
        local raw = emit("anthropic", "tool_use")
        local calls = require("parley.tools.wire_anthropic").decode_tool_calls_from_stream(raw)
        assert.equals(1, #calls)
        assert.equals("toolu_fake_1", calls[1].id)
        assert.equals("read_file", calls[1].name)
        assert.same({ path = "README.md" }, calls[1].input)
        assert.same({}, present(raw, vocabulary.anthropic.tool_use))
    end)

    it("thinking decodes to one reasoning event, and only the text is content", function()
        local raw = emit("anthropic", "thinking")
        assert.equals("Hello, world! 👋", decode_text(anthropic, raw))
        local reasoning = {}
        for line in raw:gmatch("[^\n]+") do
            local e = anthropic.parse_sse_progress_event(line)
            if e and e.kind == "reasoning" then reasoning[#reasoning + 1] = e.text end
        end
        assert.same({ "Let me plan the answer." }, reasoning)
        assert.same({}, present(raw, vocabulary.anthropic.thinking))
    end)

    it("inband_error, cap and no_stop carry what the ending classifier reads", function()
        local D = require("parley.dispatcher")
        local inband = emit("anthropic", "inband_error")
        assert.is_truthy(D._inband_error(inband), "the in-band error event is not recognised")
        assert.equals("max_tokens", D._extract_stop_reason(emit("anthropic", "cap")))
        assert.is_nil(D._extract_stop_reason(emit("anthropic", "no_stop")))
    end)
end)
