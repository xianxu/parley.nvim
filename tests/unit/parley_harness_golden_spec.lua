-- Round-trip test: harness output equals captured golden payload.
--
-- Catches drift in the parser → build_messages → prepare_payload chain.
-- If any of those modules change shape, the goldens fail and force a
-- conscious re-capture. See Task 0.8 of #90.

local harness = require("scripts.parley_harness")
local golden = require("scripts.golden_fixture")
local GOLDEN_AGENT = golden.AGENT
local READONLY_TOOLS = golden.READONLY_TOOLS

local FIXTURES = golden.FIXTURES

-- Pin the client-side tool list explicitly rather than inheriting it from
-- the shipped ToolSonnet agent. ToolSonnet ships the `@all` sentinel, which
-- expands from the live registry (pulling in write tools plus optional ones
-- like `ack` when installed) — making the payload machine-dependent. Goldens
-- must be deterministic and portable, so we fix a small read-only subset here
-- (edit_file/write_file deliberately excluded to keep golden output stable).


-- Comparison is on DECODED tables, deliberately. vim.json.encode does not fix
-- key order, so regenerating a golden yields a byte-different but semantically
-- identical file. Never "tighten" this into a string compare — it would flake
-- on every regeneration while catching nothing extra. (#198)
local function read_json(path)
    local f = assert(io.open(path, "r"))
    local s = f:read("*a")
    f:close()
    return vim.json.decode(s)
end

describe("parley_harness golden round-trip", function()
    for _, name in ipairs(FIXTURES) do
        it("payload for " .. name .. " matches golden", function()
            local payload = harness.build_payload(
                "tests/fixtures/transcripts/" .. name .. ".md",
                { agent = GOLDEN_AGENT, tools = READONLY_TOOLS }
            )
            local golden = read_json("tests/fixtures/golden_payloads/" .. name .. ".json")
            assert.same(golden, payload)
        end)
    end
end)

-- #198: the same transcripts through the OPENAI wire. Only the tool-bearing
-- ones are interesting — they are where the shapes diverge (tool_calls with
-- JSON-string arguments on the assistant message, one role:"tool" message per
-- result, `function` tool envelopes). Provider and model are pinned explicitly
-- rather than named via a shipped agent, for the same machine-independence
-- reason READONLY_TOOLS exists.
local OPENAI_FIXTURES = golden.OPENAI_FIXTURES

describe("parley_harness golden round-trip (openai wire)", function()
    for _, name in ipairs(OPENAI_FIXTURES) do
        it("openai payload for " .. name .. " matches golden", function()
            local payload = harness.build_payload(
                "tests/fixtures/transcripts/" .. name .. ".md",
                {
                    agent = GOLDEN_AGENT,
                    tools = READONLY_TOOLS,
                    provider = "cliproxyapi",
                    model = { model = "gpt-5.6-sol" },
                }
            )
            local golden = read_json("tests/fixtures/golden_payloads/openai-" .. name .. ".json")
            assert.same(golden, payload)
        end)
    end
end)
