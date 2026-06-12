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
local READONLY_TOOLS = { "read_file", "ls", "find", "grep", "chat_history_search" }

for _, name in ipairs(FIXTURES) do
    local payload = harness.build_payload(
        "tests/fixtures/transcripts/" .. name .. ".md",
        { agent_name = "ToolSonnet", tools = READONLY_TOOLS }
    )
    local path = "tests/fixtures/golden_payloads/" .. name .. ".json"
    local f = assert(io.open(path, "w"))
    f:write(vim.json.encode(payload))
    f:close()
    print("wrote " .. path)
end
