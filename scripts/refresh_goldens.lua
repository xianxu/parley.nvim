-- Regenerate tests/fixtures/golden_payloads/*.json by running the
-- harness against each transcript fixture. Run via:
--   nvim --headless --noplugin -u tests/minimal_init.vim \
--     -c 'luafile scripts/refresh_goldens.lua' -c 'qa!'

local harness = require("scripts.parley_harness")
local golden = require("scripts.golden_fixture")
local GOLDEN_AGENT = golden.AGENT
local READONLY_TOOLS = golden.READONLY_TOOLS

local FIXTURES = golden.FIXTURES

-- Keep in sync with READONLY_TOOLS in tests/unit/parley_harness_golden_spec.lua.
-- Pinned explicitly so goldens stay deterministic and portable (the shipped roster now
-- uses the `@readonly` sentinel, which would pull in optional tools like `ack`).


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
