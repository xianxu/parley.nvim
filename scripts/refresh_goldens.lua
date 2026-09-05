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

-- #198 added openai-wire goldens and a spec that verifies them, but this
-- regenerator was never extended to write them — so a prompt or tool change
-- refreshed half the goldens and left the other half stale, failing the suite
-- with no way to fix it but hand-editing JSON. Provider/model pinned exactly as
-- the verifier pins them (tests/unit/parley_harness_golden_spec.lua:57-65).
for _, name in ipairs(golden.OPENAI_FIXTURES) do
    local payload = harness.build_payload(
        "tests/fixtures/transcripts/" .. name .. ".md",
        {
            agent = GOLDEN_AGENT,
            tools = READONLY_TOOLS,
            provider = "cliproxyapi",
            model = { model = "gpt-5.6-sol" },
        }
    )
    local path = "tests/fixtures/golden_payloads/openai-" .. name .. ".json"
    local f = assert(io.open(path, "w"))
    f:write(vim.json.encode(payload))
    f:close()
    print("wrote " .. path)
end
