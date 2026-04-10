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
                { agent_name = "ClaudeAgentTools" }
            )
            local golden = read_json("tests/fixtures/golden_payloads/" .. name .. ".json")
            assert.same(golden, payload)
        end)
    end
end)
