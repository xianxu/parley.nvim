-- Round-trip test: harness output equals captured golden payload.
--
-- Catches drift in the parser → build_messages → prepare_payload chain.
-- If any of those modules change shape, the goldens fail and force a
-- conscious re-capture. See Task 0.8 of #90.

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

-- Pin the client-side tool list explicitly rather than inheriting it from
-- the shipped ToolSonnet agent. ToolSonnet ships the `@all` sentinel, which
-- expands from the live registry (pulling in write tools plus optional ones
-- like `ack` when installed) — making the payload machine-dependent. Goldens
-- must be deterministic and portable, so we fix a small read-only subset here
-- (edit_file/write_file deliberately excluded to keep golden output stable).
local READONLY_TOOLS = { "read_file", "ls", "find", "grep", "chat_history_search" }

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
                { agent_name = "ToolSonnet", tools = READONLY_TOOLS }
            )
            local golden = read_json("tests/fixtures/golden_payloads/" .. name .. ".json")
            assert.same(golden, payload)
        end)
    end
end)
