-- Tests for the two wire_anthropic functions that are NOT verbatim moves
-- (#198 M1): has_tool_calls and encode_tool_choice.
--
-- The moved halves are covered by the untouched anthropic_tool_{encode,decode}
-- specs. These two were promoted from literals elsewhere — has_tool_calls from
-- dispatcher.lua's empty_response probe, encode_tool_choice from
-- skill_assembly.lua's forced-tool table — and M2 rewires both call sites onto
-- them. A drift here would silently break the PRIMARY provider, so they get
-- pinned by value rather than by inequality against the openai shape.

local wire = require("parley.tools.wire_anthropic")
local sse = require("parley.sse")

local function read_fixture(name)
    local f = assert(io.open("tests/fixtures/" .. name, "r"))
    local s = f:read("*a")
    f:close()
    return s
end

describe("wire_anthropic.encode_tool_choice", function()
    it("pins Anthropic's forced-tool shape by value", function()
        assert.same({ type = "tool", name = "propose_edits" },
            wire.encode_tool_choice("propose_edits"))
    end)
end)

describe("wire_anthropic.has_tool_calls", function()
    it("is true for the captured anthropic tool stream", function()
        assert.is_true(wire.has_tool_calls(read_fixture("anthropic_tool_use_stream_real.jsonl")))
    end)

    it("is false for a text-only anthropic stream", function()
        assert.is_false(wire.has_tool_calls(read_fixture("anthropic_stream.txt")))
    end)

    it("is false for empty and non-string input", function()
        assert.is_false(wire.has_tool_calls(""))
        assert.is_false(wire.has_tool_calls(nil))
    end)

    -- The probe is a plain-text find for the exact wire spelling. If Anthropic
    -- ever reformats that JSON (spaces after colons, say), this silently goes
    -- false and every tool-only turn reports an empty response.
    it("matches the exact wire spelling it depends on", function()
        assert.is_true(wire.has_tool_calls('{"type":"tool_use","id":"toolu_1"}'))
        assert.is_false(wire.has_tool_calls('{"type": "tool_use"}'))
    end)

    it("does not confuse a server_tool_use block for a client call", function()
        -- server_tool_use is resolved provider-side and needs no client
        -- result; the substring '"type":"tool_use"' must not match it.
        assert.is_false(wire.has_tool_calls('{"type":"server_tool_use","name":"web_search"}'))
    end)
end)

describe("wire_anthropic.decode_tool_calls_from_stream null-safety", function()
    -- Same class as the OpenAI decoder's C1: an explicit JSON null decodes to
    -- vim.NIL, which is truthy, and raises downstream when concatenated.
    it("yields nil, not vim.NIL, for a null id or name", function()
        local calls = wire.decode_tool_calls_from_stream(table.concat({
            'data: {"type":"content_block_start","index":0,"content_block":' ..
                '{"type":"tool_use","id":null,"name":null}}',
            'data: {"type":"content_block_delta","index":0,"delta":' ..
                '{"type":"input_json_delta","partial_json":"{}"}}',
            'data: {"type":"content_block_stop","index":0}',
        }, "\n"))
        assert.equals(1, #calls)
        assert.is_nil(calls[1].id)
        assert.is_nil(calls[1].name)
        assert.are_not.equal(vim.NIL, calls[1].name)
    end)
end)

describe("parley.sse.str", function()
    -- The helper that makes the vim.NIL class unrepresentable rather than
    -- fixed per-site. Both decoders read optional fields through it.
    it("passes a string through", function()
        assert.equals("hello", sse.str("hello"))
        assert.equals("", sse.str(""))
    end)

    it("collapses vim.NIL to nil", function()
        assert.is_nil(sse.str(vim.NIL))
    end)

    it("collapses nil and non-strings to nil", function()
        assert.is_nil(sse.str(nil))
        assert.is_nil(sse.str(42))
        assert.is_nil(sse.str({}))
        assert.is_nil(sse.str(true))
    end)
end)

describe("parley.sse.strip_data_prefix", function()
    it("strips the prefix", function()
        assert.equals("{}", sse.strip_data_prefix("data: {}"))
    end)

    it("leaves an unprefixed line alone", function()
        assert.equals("event: ping", sse.strip_data_prefix("event: ping"))
    end)

    -- Pins the single-return contract. gsub also returns a replacement count;
    -- leaking it makes f(strip_data_prefix(line)) pass TWO arguments.
    it("returns exactly one value", function()
        assert.equals(1, select("#", sse.strip_data_prefix("data: {}")))
    end)
end)

describe("parley.sse.safe_json_decode", function()
    it("decodes valid JSON", function()
        assert.same({ a = 1 }, sse.safe_json_decode('{"a":1}'))
    end)

    it("returns nil rather than raising on malformed input", function()
        assert.is_nil(sse.safe_json_decode('{"a":'))
        assert.is_nil(sse.safe_json_decode("not json"))
        assert.is_nil(sse.safe_json_decode(""))
    end)
end)
