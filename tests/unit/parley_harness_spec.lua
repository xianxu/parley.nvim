-- Unit tests for scripts/parley_harness.lua
--
-- The harness builds the Anthropic payload that would be sent for the
-- LAST exchange in a parley transcript file. Used by the offline
-- test-anthropic-interaction.sh script and as a regression target for
-- golden payloads.

local harness = require("scripts.parley_harness")
local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-harness-test-" .. os.time()
vim.fn.mkdir(tmp, "p")

local function write_transcript(name, lines)
    local p = tmp .. "/" .. name
    vim.fn.writefile(lines, p)
    return p
end

describe("parley_harness", function()
    it("builds an Anthropic payload from a single-user transcript", function()
        local p = write_transcript("single-user.md", {
            "---",
            "topic: test",
            "file: dummy.md",
            "model: claude-sonnet-4-6",
            "provider: anthropic",
            "---",
            "",
            "💬: hello",
        })
        local payload = harness.build_payload(p)
        assert.is_table(payload)
        assert.is_table(payload.messages)
        assert.equals(1, #payload.messages)
        assert.equals("user", payload.messages[1].role)
        assert.matches("hello", payload.messages[1].content)
    end)

    it("builds a tool-loop recursive payload (3 messages ending in user[tool_result])", function()
        local p = write_transcript("one-round.md", {
            "---",
            "topic: t",
            "file: dummy.md",
            "model: claude-sonnet-4-6",
            "provider: anthropic",
            "---",
            "",
            "💬: read foo.txt",
            "",
            "🤖: [Claude]",
            "🔧: read_file id=toolu_X",
            "```json",
            '{"path":"foo.txt"}',
            "```",
            "📎: read_file id=toolu_X",
            "````",
            "    1  hi",
            "````",
        })
        local payload = harness.build_payload(p, { agent_name = "ClaudeAgentTools" })
        assert.equals(3, #payload.messages)
        assert.equals("user", payload.messages[1].role)
        assert.equals("assistant", payload.messages[2].role)
        assert.equals("user", payload.messages[3].role)
        assert.is_table(payload.messages[3].content)
        assert.equals("tool_result", payload.messages[3].content[1].type)
    end)
end)
