-- Unit tests for scripts/parley_harness.lua
--
-- The harness builds the Anthropic payload that would be sent for the
-- LAST exchange in a parley transcript file. Used by the offline
-- test-anthropic-interaction.sh script and as a regression target for
-- golden payloads.

local harness = require("scripts.parley_harness")
local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-harness-test-" .. os.time()
vim.fn.mkdir(tmp, "p")

-- Pinned, not borrowed from the shipped roster. These asserted message COUNTS
-- while letting `get_agent` pick the default: when the shipped default became a
-- synthetic-system-prompt agent, it injected an extra pair and both counts went
-- wrong — a failure that reads as a payload bug and is really a roster change.
-- (`ClaudeAgentTools`, named below, does not ship either; get_agent warns and
-- falls back, so the name was decorative.)
local PLAIN_AGENT = {
    name = "HarnessAgent",
    provider = "anthropic",
    model = { model = "claude-sonnet-4-6" },
    system_prompt = "You are a helpful assistant.",
}

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
        local payload = harness.build_payload(p, { agent = PLAIN_AGENT })
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
        local payload = harness.build_payload(p, { agent = PLAIN_AGENT })
        assert.equals(3, #payload.messages)
        assert.equals("user", payload.messages[1].role)
        assert.equals("assistant", payload.messages[2].role)
        assert.equals("user", payload.messages[3].role)
        assert.is_table(payload.messages[3].content)
        assert.equals("tool_result", payload.messages[3].content[1].type)
    end)
end)
