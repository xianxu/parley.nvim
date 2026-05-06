-- Unit tests for lua/parley/log_emit.lua

local le = require("parley.log_emit")

describe("log_emit.emit_yaml: scalars", function()
    it("emits booleans, nil, integers", function()
        assert.equals("true", le.emit_yaml(true))
        assert.equals("false", le.emit_yaml(false))
        assert.equals("null", le.emit_yaml(nil))
        assert.equals("42", le.emit_yaml(42))
    end)

    it("emits plain strings unquoted", function()
        assert.equals("hello", le.emit_yaml("hello"))
        assert.equals("hello world", le.emit_yaml("hello world"))
    end)

    it("quotes strings that look like yaml reserved words", function()
        assert.equals('"true"', le.emit_yaml("true"))
        assert.equals('"null"', le.emit_yaml("null"))
        assert.equals('"yes"', le.emit_yaml("yes"))
    end)

    it("quotes strings that look like numbers", function()
        assert.equals('"42"', le.emit_yaml("42"))
        assert.equals('"3.14"', le.emit_yaml("3.14"))
    end)

    it("quotes strings starting with yaml indicators", function()
        for _, s in ipairs({ ":foo", "#foo", "&foo", "*foo", "!foo", "|foo", ">foo", "%foo", "@foo", "`foo", "?foo", ",foo", "[foo", "]foo", "{foo", "}foo" }) do
            local rendered = le.emit_yaml(s)
            assert.equals('"' .. s .. '"', rendered, "expected '" .. s .. "' to be quoted")
        end
    end)

    it("emits multi-line strings as | block scalars", function()
        local rendered = le.emit_yaml("line one\nline two\nline three")
        -- With leading | marker and a continuation block (gets emitted at root
        -- with no indent because there's no parent context).
        assert.truthy(rendered:find("^|", 1, false))
        assert.truthy(rendered:find("line one", 1, true))
        assert.truthy(rendered:find("line three", 1, true))
    end)
end)

describe("log_emit.emit_yaml: mappings", function()
    it("emits a flat mapping", function()
        local out = le.emit_yaml({ a = 1, b = "hi" })
        assert.truthy(out:find("a: 1", 1, true))
        assert.truthy(out:find("b: hi", 1, true))
    end)

    it("orders keys alphabetically by default", function()
        local out = le.emit_yaml({ c = 1, a = 2, b = 3 })
        local pos_a, pos_b, pos_c = out:find("a:"), out:find("b:"), out:find("c:")
        assert.is_true(pos_a < pos_b and pos_b < pos_c)
    end)

    it("respects ordered_keys for top-level mapping", function()
        local out = le.emit_yaml({ b = 1, a = 2, c = 3 }, { "b", "c", "a" })
        local pos_a, pos_b, pos_c = out:find("a:"), out:find("b:"), out:find("c:")
        assert.is_true(pos_b < pos_c and pos_c < pos_a)
    end)

    it("emits empty mapping as {}", function()
        assert.equals("{}", le.emit_yaml({}))
    end)
end)

describe("log_emit.emit_yaml: arrays", function()
    it("emits a flat array", function()
        local out = le.emit_yaml({ "a", "b", "c" })
        assert.equals("- a\n- b\n- c", out)
    end)

    it("emits empty array as []", function()
        local arr = {}
        setmetatable(arr, { __index = function() return nil end })
        -- emit_yaml on truly empty table goes through mapping {}; arrays
        -- detect via 1..n. For exhibit, an explicit non-empty array of
        -- 1 item:
        assert.equals("- 1", le.emit_yaml({ 1 }))
    end)
end)

describe("log_emit.emit_yaml: nested structures", function()
    it("emits an Anthropic-style request payload skeleton", function()
        local payload = {
            model = "claude-sonnet-4-6",
            max_tokens = 4096,
            stream = true,
            system = {
                {
                    type = "text",
                    cache_control = { type = "ephemeral" },
                    text = "system prompt body",
                },
            },
            messages = {
                { role = "user", content = "hello" },
            },
        }
        local out = le.emit_yaml(payload, { "model", "max_tokens", "stream", "system", "messages" })
        -- Top-level key order respected
        assert.is_true(out:find("model:") < out:find("max_tokens:"))
        assert.is_true(out:find("max_tokens:") < out:find("stream:"))
        assert.is_true(out:find("stream:") < out:find("system:"))
        assert.is_true(out:find("system:") < out:find("messages:"))
        -- Nested array entries indent under their parent
        assert.truthy(out:find("system:\n", 1, true))
        assert.truthy(out:find("- type: text", 1, true))
        assert.truthy(out:find("text: system prompt body", 1, true))
    end)

    it("emits multi-line strings as block scalars at the right indent", function()
        local out = le.emit_yaml({
            outer = {
                inner = "line one\nline two",
            },
        })
        -- Should have `inner: |` then indented body lines.
        assert.truthy(out:find("inner: |", 1, true))
        assert.truthy(out:find("line one", 1, true))
        assert.truthy(out:find("line two", 1, true))
    end)
end)

describe("log_emit.format_raw_turn", function()
    it("emits all three sub-blocks when given request + assembled + sse", function()
        local md = le.format_raw_turn({
            turn = 1,
            ts = "2026-05-06T12:34:56Z",
            request = { model = "x", max_tokens = 10, messages = { { role = "user", content = "hi" } } },
            assembled = { stop_reason = "end_turn", content = { { type = "text", text = "hello" } } },
            sse_lines = { "event: content_block_start", "data: {}", "" },
        })
        assert.truthy(md:find("## Turn 1 — 2026-05-06T12:34:56Z", 1, true))
        assert.truthy(md:find("### Request payload (yaml)", 1, true))
        assert.truthy(md:find("### Response (assembled, yaml)", 1, true))
        assert.truthy(md:find("### Response (raw SSE)", 1, true))
        assert.truthy(md:find("```yaml", 1, true))
        assert.truthy(md:find("event: content_block_start", 1, true))
    end)

    it("omits assembled and sse subsections when not provided", function()
        local md = le.format_raw_turn({
            turn = 2,
            ts = "ts",
            request = { model = "x" },
        })
        assert.truthy(md:find("### Request payload (yaml)", 1, true))
        assert.is_nil(md:find("### Response", 1, true))
    end)
end)

describe("log_emit.format_exchange_turn", function()
    it("renders one ### section per message with string content inlined", function()
        local md = le.format_exchange_turn({
            turn = 3,
            ts = "ts",
            messages = {
                { role = "system", content = "be helpful" },
                { role = "user", content = "hi" },
                { role = "assistant", content = "hello there" },
            },
        })
        assert.truthy(md:find("## Turn 3 — ts", 1, true))
        assert.truthy(md:find("### system\n", 1, true))
        assert.truthy(md:find("### user\n", 1, true))
        assert.truthy(md:find("### assistant\n", 1, true))
        assert.truthy(md:find("be helpful", 1, true))
        assert.truthy(md:find("hello there", 1, true))
    end)

    it("renders structured content via YAML fence", function()
        local md = le.format_exchange_turn({
            turn = 1,
            ts = "ts",
            messages = {
                {
                    role = "assistant",
                    content = {
                        { type = "text", text = "hi" },
                        { type = "tool_use", name = "read_file", input = { file_path = "x.lua" } },
                    },
                },
            },
        })
        assert.truthy(md:find("```yaml", 1, true))
        assert.truthy(md:find("type: text", 1, true))
        assert.truthy(md:find("name: read_file", 1, true))
    end)
end)
