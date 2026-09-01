-- Regenerate tests/fixtures/golden_payloads/*.json by running the
-- harness against each transcript fixture. Run via:
--   nvim --headless --noplugin -u tests/minimal_init.vim \
--     -c 'luafile scripts/refresh_goldens.lua' -c 'qa!'

local harness = require("scripts.parley_harness")

local FIXTURES = {
    "single-user",
    "simple-chat",
    "one-round-tool-use",
    "two-round-tool-use",
    "mixed-text-and-tools",
    "tool-error",
    "dynamic-fence-stress",
}

-- Keep in sync with READONLY_TOOLS in tests/unit/parley_harness_golden_spec.lua.
-- Pinned explicitly so goldens stay deterministic and portable (ToolSonnet now
-- uses the `@readonly` sentinel, which would pull in optional tools like `ack`).
-- Pinned, not named: goldens must not depend on which agents happen to ship.
-- `get_agent` falls back with a warning when a name is missing, so naming a
-- shipped agent means a roster change silently regenerates goldens against a
-- DIFFERENT agent — which is how a synthetic-system-prompt agent's extra
-- message pair got into a comparison (#205).
local GOLDEN_AGENT = {
    name = "GoldenAgent",
    provider = "anthropic",
    model = { model = "claude-sonnet-4-6" },
    system_prompt = "You are a helpful assistant.",
}

local READONLY_TOOLS = { "read_file", "ls", "find", "grep", "chat_history_search" }

for _, name in ipairs(FIXTURES) do
    local payload = harness.build_payload(
        "tests/fixtures/transcripts/" .. name .. ".md",
        { agent = GOLDEN_AGENT, tools = READONLY_TOOLS }
    )
    local path = "tests/fixtures/golden_payloads/" .. name .. ".json"
    local f = assert(io.open(path, "w"))
    f:write(vim.json.encode(payload))
    f:close()
    print("wrote " .. path)
end
