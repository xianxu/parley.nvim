-- Unit tests for wire_openai.translate_messages (#198).
--
-- Parley's internal message shape is Anthropic's: an assistant turn carries
-- [text, tool_use] content blocks and the IMMEDIATELY FOLLOWING user turn
-- carries the matching [tool_result] blocks. chat_respond builds that shape
-- (and is the single place #155's "no dangling tool_use" and #156's "no
-- orphan tool_result" invariants are enforced).
--
-- OpenAI wants something structurally different: tool calls hang off the
-- assistant message as `tool_calls[]` with JSON-STRING arguments, and every
-- result is its OWN `{role = "tool"}` message.
--
-- This translation runs on EVERY openai-family request, tool-less ones
-- included, because a prior turn's tool blocks live in history. So the
-- pass-through path is the one that must not drift.

local wire = require("parley.tools.wire_openai")

describe("wire_openai.translate_messages", function()
    -- ---- pass-through: the majority path -------------------------------

    it("returns string-content messages by exact identity", function()
        local msgs = {
            { role = "system", content = "You are a peer." },
            { role = "user", content = "hi" },
            { role = "assistant", content = "hello" },
            { role = "user", content = "bye" },
        }
        assert.same(msgs, wire.translate_messages(vim.deepcopy(msgs)))
    end)

    it("preserves non-content fields on passed-through messages", function()
        local out = wire.translate_messages({
            { role = "system", content = "sys", cache_control = { type = "ephemeral" } },
        })
        assert.same({ type = "ephemeral" }, out[1].cache_control)
    end)

    it("returns an empty list for nil and empty input", function()
        assert.same({}, wire.translate_messages(nil))
        assert.same({}, wire.translate_messages({}))
    end)

    -- ---- assistant turns -----------------------------------------------

    it("converts assistant [text, tool_use] into content + tool_calls", function()
        local out = wire.translate_messages({
            {
                role = "assistant",
                content = {
                    { type = "text", text = "Let me check." },
                    { type = "tool_use", id = "call_a", name = "get_weather",
                      input = { city = "Paris" } },
                },
            },
        })

        assert.equals(1, #out)
        assert.equals("assistant", out[1].role)
        assert.equals("Let me check.", out[1].content)
        assert.equals(1, #out[1].tool_calls)
        assert.equals("call_a", out[1].tool_calls[1].id)
        assert.equals("function", out[1].tool_calls[1].type)
        assert.equals("get_weather", out[1].tool_calls[1]["function"].name)
        -- arguments is a JSON STRING, not a table
        assert.equals("string", type(out[1].tool_calls[1]["function"].arguments))
        assert.same({ city = "Paris" },
            vim.json.decode(out[1].tool_calls[1]["function"].arguments))
    end)

    it("leaves content nil on a tool-only assistant turn", function()
        local out = wire.translate_messages({
            { role = "assistant", content = {
                { type = "tool_use", id = "call_a", name = "ls", input = { path = "." } },
            } },
        })
        -- nil, not "": the live round-trip used explicit null, and an empty
        -- string risks reading as a real empty answer.
        assert.is_nil(out[1].content)
        assert.equals(1, #out[1].tool_calls)
    end)

    it("joins multiple text blocks with a blank line", function()
        local out = wire.translate_messages({
            { role = "assistant", content = {
                { type = "text", text = "First." },
                { type = "text", text = "Second." },
            } },
        })
        assert.equals("First.\n\nSecond.", out[1].content)
        assert.is_nil(out[1].tool_calls)
    end)

    it("encodes empty tool input as {} rather than []", function()
        local out = wire.translate_messages({
            { role = "assistant", content = {
                { type = "tool_use", id = "call_a", name = "noargs", input = {} },
            } },
        })
        assert.equals("{}", out[1].tool_calls[1]["function"].arguments)
    end)

    it("carries several parallel tool_use blocks in one assistant message", function()
        local out = wire.translate_messages({
            { role = "assistant", content = {
                { type = "tool_use", id = "call_a", name = "a", input = { x = 1 } },
                { type = "tool_use", id = "call_b", name = "b", input = { y = 2 } },
            } },
        })
        assert.equals(1, #out)
        assert.equals(2, #out[1].tool_calls)
        assert.equals("call_a", out[1].tool_calls[1].id)
        assert.equals("call_b", out[1].tool_calls[2].id)
    end)

    -- ---- tool results --------------------------------------------------

    it("splits a tool_result batch into one role:tool message each", function()
        local out = wire.translate_messages({
            { role = "user", content = {
                { type = "tool_result", tool_use_id = "call_a", content = "18C" },
                { type = "tool_result", tool_use_id = "call_b", content = "26C" },
            } },
        })

        assert.equals(2, #out)
        assert.same({ role = "tool", tool_call_id = "call_a", content = "18C" }, out[1])
        assert.same({ role = "tool", tool_call_id = "call_b", content = "26C" }, out[2])
    end)

    it("folds is_error into the tool content", function()
        -- OpenAI has no is_error field; without folding, the model cannot
        -- tell a failed call from a successful one returning error text.
        local out = wire.translate_messages({
            { role = "user", content = {
                { type = "tool_result", tool_use_id = "call_a",
                  content = "file not found", is_error = true },
            } },
        })
        assert.equals("tool", out[1].role)
        assert.matches("file not found", out[1].content)
        assert.are_not.equals("file not found", out[1].content)
    end)

    it("handles a tool_result with empty content", function()
        local out = wire.translate_messages({
            { role = "user", content = {
                { type = "tool_result", tool_use_id = "call_a" },
            } },
        })
        assert.equals("tool", out[1].role)
        assert.equals("", out[1].content)
    end)

    it("emits a user message for text blocks alongside tool results", function()
        local out = wire.translate_messages({
            { role = "user", content = {
                { type = "tool_result", tool_use_id = "call_a", content = "ok" },
                { type = "text", text = "and now this" },
            } },
        })
        assert.equals(2, #out)
        assert.equals("tool", out[1].role)
        assert.equals("user", out[2].role)
        assert.equals("and now this", out[2].content)
    end)

    -- ---- whole-loop ordering -------------------------------------------

    it("preserves message order across a two-round tool loop", function()
        local out = wire.translate_messages({
            { role = "user", content = "weather in Paris and Tokyo?" },
            { role = "assistant", content = {
                { type = "text", text = "Checking." },
                { type = "tool_use", id = "call_a", name = "get_weather", input = { city = "Paris" } },
            } },
            { role = "user", content = {
                { type = "tool_result", tool_use_id = "call_a", content = "18C" },
            } },
            { role = "assistant", content = {
                { type = "tool_use", id = "call_b", name = "get_weather", input = { city = "Tokyo" } },
            } },
            { role = "user", content = {
                { type = "tool_result", tool_use_id = "call_b", content = "26C" },
            } },
            { role = "assistant", content = "Paris 18C, Tokyo 26C." },
        })

        local roles = {}
        for _, m in ipairs(out) do
            table.insert(roles, m.role)
        end
        assert.same(
            { "user", "assistant", "tool", "assistant", "tool", "assistant" },
            roles
        )
        -- every tool message points at the call immediately before it
        assert.equals("call_a", out[3].tool_call_id)
        assert.equals("call_b", out[5].tool_call_id)
    end)
end)
