-- Unit tests for wire_openai.decode_tool_calls_from_stream (#198).
--
-- Structurally harder than the Anthropic decoder. Anthropic frames each
-- tool call with content_block_start / content_block_stop around a
-- top-level `.index`; OpenAI streams an ARRAY of partial tool_calls where:
--
--   * `index` (inside the array entry) keys the logical call,
--   * `id` and `function.name` appear ONLY in that call's first chunk,
--   * `function.arguments` accumulates as string fragments,
--   * and nothing closes an individual call.
--
-- The resilience cases matter more than usual: this runs mid-chat on
-- whatever the network produced, and a raising decoder would strand the
-- buffer with an unmatched tool_use block.
--
-- Real fixtures captured 2026-08-15 from cliproxyapi 7.2.110 against
-- gpt-5.6-sol on the codex channel.

local wire = require("parley.tools.wire_openai")

-- Build an SSE body from a list of decoded chunk tables.
local function sse(chunks)
    local lines = {}
    for _, c in ipairs(chunks) do
        table.insert(lines, "data: " .. vim.json.encode(c))
    end
    table.insert(lines, "data: [DONE]")
    return table.concat(lines, "\n\n")
end

-- One streaming chunk carrying a tool_calls delta.
local function tc_chunk(tool_calls, finish_reason)
    return {
        choices = {
            {
                index = 0,
                delta = { tool_calls = tool_calls },
                finish_reason = finish_reason,
            },
        },
    }
end

local function read_fixture(name)
    local f = assert(io.open("tests/fixtures/" .. name, "r"))
    local s = f:read("*a")
    f:close()
    return s
end

describe("wire_openai.decode_tool_calls_from_stream (synthetic)", function()
    it("reassembles one call split across chunks", function()
        local calls = wire.decode_tool_calls_from_stream(sse({
            tc_chunk({ {
                index = 0, id = "call_a", type = "function",
                ["function"] = { name = "get_weather", arguments = "" },
            } }),
            tc_chunk({ { index = 0, ["function"] = { arguments = '{"city":' } } }),
            tc_chunk({ { index = 0, ["function"] = { arguments = '"Paris"}' } } }),
            tc_chunk(nil, "tool_calls"),
        }))

        assert.same({ { id = "call_a", name = "get_weather", input = { city = "Paris" } } }, calls)
    end)

    it("keeps parallel calls separate when their chunks interleave", function()
        local calls = wire.decode_tool_calls_from_stream(sse({
            tc_chunk({ {
                index = 0, id = "call_a", type = "function",
                ["function"] = { name = "read_file", arguments = "" },
            } }),
            tc_chunk({ {
                index = 1, id = "call_b", type = "function",
                ["function"] = { name = "ls", arguments = "" },
            } }),
            -- interleaved argument fragments for both calls
            tc_chunk({ { index = 0, ["function"] = { arguments = '{"path":' } } }),
            tc_chunk({ { index = 1, ["function"] = { arguments = '{"path":"/tmp"}' } } }),
            tc_chunk({ { index = 0, ["function"] = { arguments = '"a.lua"}' } } }),
            tc_chunk(nil, "tool_calls"),
        }))

        assert.equals(2, #calls)
        assert.same({ id = "call_a", name = "read_file", input = { path = "a.lua" } }, calls[1])
        assert.same({ id = "call_b", name = "ls", input = { path = "/tmp" } }, calls[2])
    end)

    it("orders by first appearance, not by numeric index", function()
        local calls = wire.decode_tool_calls_from_stream(sse({
            tc_chunk({ { index = 7, id = "call_seven", ["function"] = { name = "b", arguments = "{}" } } }),
            tc_chunk({ { index = 2, id = "call_two", ["function"] = { name = "a", arguments = "{}" } } }),
            tc_chunk(nil, "tool_calls"),
        }))

        assert.equals(2, #calls)
        assert.equals("call_seven", calls[1].id)
        assert.equals("call_two", calls[2].id)
    end)

    it("handles several chunks carrying multiple calls each", function()
        local calls = wire.decode_tool_calls_from_stream(sse({
            tc_chunk({
                { index = 0, id = "call_a", ["function"] = { name = "a", arguments = "" } },
                { index = 1, id = "call_b", ["function"] = { name = "b", arguments = "" } },
            }),
            tc_chunk({
                { index = 0, ["function"] = { arguments = '{"x":1}' } },
                { index = 1, ["function"] = { arguments = '{"y":2}' } },
            }),
            tc_chunk(nil, "tool_calls"),
        }))

        assert.equals(2, #calls)
        assert.same({ x = 1 }, calls[1].input)
        assert.same({ y = 2 }, calls[2].input)
    end)

    -- ---- resilience: none of these may raise ----------------------------

    it("returns an empty list for a plain-text response", function()
        local calls = wire.decode_tool_calls_from_stream(sse({
            { choices = { { index = 0, delta = { content = "Hello" } } } },
            { choices = { { index = 0, delta = { content = " there" }, finish_reason = "stop" } } },
        }))
        assert.same({}, calls)
    end)

    it("returns an empty list for empty, nil and garbage input", function()
        assert.same({}, wire.decode_tool_calls_from_stream(""))
        assert.same({}, wire.decode_tool_calls_from_stream(nil))
        assert.same({}, wire.decode_tool_calls_from_stream("garbage\ndata: not json\n"))
    end)

    it("yields an empty input when arguments never arrive", function()
        local calls = wire.decode_tool_calls_from_stream(sse({
            tc_chunk({ { index = 0, id = "call_a", ["function"] = { name = "noargs" } } }),
            tc_chunk(nil, "tool_calls"),
        }))
        assert.equals(1, #calls)
        assert.equals("noargs", calls[1].name)
        assert.same({}, calls[1].input)
    end)

    it("yields an empty input when arguments are malformed JSON", function()
        local calls = wire.decode_tool_calls_from_stream(sse({
            tc_chunk({ {
                index = 0, id = "call_a",
                ["function"] = { name = "broken", arguments = '{"city": ' },
            } }),
            tc_chunk(nil, "tool_calls"),
        }))
        assert.equals(1, #calls)
        assert.same({}, calls[1].input)
    end)

    it("decodes a stream cut short with no finish_reason", function()
        -- Deliberately no terminating chunk and no [DONE]: a dropped
        -- connection still surfaces the call, so tool_loop can write a
        -- synthetic result rather than leaving an unmatched tool_use.
        local body = "data: " .. vim.json.encode(tc_chunk({ {
            index = 0, id = "call_a", type = "function",
            ["function"] = { name = "get_weather", arguments = '{"city":"Paris"}' },
        } }))
        local calls = wire.decode_tool_calls_from_stream(body)
        assert.equals(1, #calls)
        assert.same({ city = "Paris" }, calls[1].input)
    end)

    it("ignores a tool_calls delta that is not a list", function()
        local body = 'data: {"choices":[{"index":0,"delta":{"tool_calls":"nonsense"}}]}'
        assert.same({}, wire.decode_tool_calls_from_stream(body))
    end)

    -- M1 review C1. vim.json.decode turns an explicit JSON null into
    -- vim.NIL, which is TRUTHY in Lua — so `if tc.id then` accepted it and
    -- overwrote the good id with userdata. This wire emits explicit nulls
    -- freely ("finish_reason":null on every chunk), so it is reachable, and
    -- the userdata then raised on concatenation two frames downstream, in
    -- the registry lookup inside tools/dispatcher.
    it("does not let an explicit null clobber a captured id or name", function()
        local calls = wire.decode_tool_calls_from_stream(table.concat({
            'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_good",' ..
                '"type":"function","function":{"name":"get_weather","arguments":""}}]}}]}',
            'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":null,' ..
                '"function":{"name":null,"arguments":"{\\"city\\":\\"Paris\\"}"}}]}}]}',
        }, "\n\n"))

        assert.equals(1, #calls)
        assert.equals("call_good", calls[1].id)
        assert.equals("get_weather", calls[1].name)
        assert.same({ city = "Paris" }, calls[1].input)
        -- the actual downstream failure mode: this must not raise
        assert.has_no.errors(function()
            return "Tool '" .. calls[1].name .. "' is not available"
        end)
    end)

    it("drops an entry that never carried a name", function()
        -- A continuation fragment whose opening chunk never arrived. It has
        -- no analogue on the anthropic wire, and surfacing it would put an
        -- unexecutable ToolCall into the loop.
        local calls = wire.decode_tool_calls_from_stream(
            'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,' ..
            '"function":{"arguments":"{}"}}]}}]}')
        assert.same({}, calls)
    end)

    it("keeps a well-formed call when a nameless entry shares the stream", function()
        local calls = wire.decode_tool_calls_from_stream(table.concat({
            'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,' ..
                '"function":{"arguments":"{}"}}]}}]}',
            'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"id":"call_b",' ..
                '"function":{"name":"ls","arguments":"{}"}}]}}]}',
        }, "\n\n"))
        assert.equals(1, #calls)
        assert.equals("ls", calls[1].name)
    end)

    it("tolerates a missing index by defaulting to 0", function()
        local calls = wire.decode_tool_calls_from_stream(sse({
            tc_chunk({ { id = "call_a", ["function"] = { name = "x", arguments = "{}" } } }),
            tc_chunk(nil, "tool_calls"),
        }))
        assert.equals(1, #calls)
        assert.equals("call_a", calls[1].id)
    end)
end)

describe("wire_openai.decode_tool_calls_from_stream (real fixtures)", function()
    it("decodes the single-call capture", function()
        local calls = wire.decode_tool_calls_from_stream(read_fixture("openai_tool_use_stream.sse"))
        assert.equals(1, #calls)
        assert.equals("get_weather", calls[1].name)
        assert.equals("call_hFoar26SM0gDLW4JOCQ7qCKi", calls[1].id)
        assert.same({ city = "Paris" }, calls[1].input)
    end)

    it("decodes the parallel-call capture in stream order", function()
        local calls = wire.decode_tool_calls_from_stream(read_fixture("openai_parallel_tool_calls.sse"))
        assert.equals(2, #calls)
        assert.equals("get_weather", calls[1].name)
        assert.same({ city = "Paris" }, calls[1].input)
        assert.equals("get_weather", calls[2].name)
        assert.same({ city = "Tokyo" }, calls[2].input)
        -- ids are distinct: two genuinely separate calls, not one double-read
        assert.are_not.equals(calls[1].id, calls[2].id)
    end)

    it("produces inputs that are tables, not strings of JSON", function()
        local calls = wire.decode_tool_calls_from_stream(read_fixture("openai_parallel_tool_calls.sse"))
        assert.equals("table", type(calls[1].input))
        assert.equals("string", type(calls[1].input.city))
    end)
end)

describe("wire_openai.has_tool_calls", function()
    it("is true for a captured tool stream", function()
        assert.is_true(wire.has_tool_calls(read_fixture("openai_tool_use_stream.sse")))
    end)

    it("is false for a plain-text stream", function()
        local body = sse({ { choices = { { index = 0, delta = { content = "hi" } } } } })
        assert.is_false(wire.has_tool_calls(body))
    end)

    it("is false for empty and non-string input", function()
        assert.is_false(wire.has_tool_calls(""))
        assert.is_false(wire.has_tool_calls(nil))
    end)
end)
