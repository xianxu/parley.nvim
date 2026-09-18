-- Regenerate tests/fixtures/golden_payloads/*.json by running the
-- harness against each transcript fixture. Run via:
--   nvim --headless --noplugin -u tests/minimal_init.vim \
--     -c 'luafile scripts/refresh_goldens.lua' -c 'qa!'
--
-- Writes the NORMALIZED payload, not the raw one. Tool descriptions embed host
-- probe results -- "BSD ls (macOS)", "ripgrep 15.1.0" -- so a raw fixture
-- records whichever machine last regenerated it and flips back on the next
-- machine, churning the diff while the verifier (which normalizes both sides)
-- never notices either way. normalize_payload is idempotent, so writing it here
-- makes regeneration machine-independent and the committed fixture portable --
-- which is what the goldens claim to be.

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
    f:write(vim.json.encode(golden.normalize_payload(payload)))
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
            provider = golden.OPENAI_WIRE.provider,
            model = golden.OPENAI_WIRE.model,
        }
    )
    local path = "tests/fixtures/golden_payloads/openai-" .. name .. ".json"
    local f = assert(io.open(path, "w"))
    f:write(vim.json.encode(golden.normalize_payload(payload)))
    f:close()
    print("wrote " .. path)
end
