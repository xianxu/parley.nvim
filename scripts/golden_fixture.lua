-- The agent goldens are built with, and the tool list they pin.
--
-- ONE definition, required by both the regenerator (scripts/refresh_goldens.lua)
-- and the verifier (tests/unit/parley_harness_golden_spec.lua). They held
-- verbatim copies kept equal by hand, which is the same failure the pin exists
-- to prevent: a golden must depend on nothing a person has to remember.
--
-- Why pinned at all: `get_agent` falls back with a warning when a name is
-- missing, so naming a SHIPPED agent means a roster change silently regenerates
-- or verifies goldens against a different agent — which is how a
-- synthetic-system-prompt agent's extra message pair entered a comparison (#205).
local M = {}

M.AGENT = {
    name = "GoldenAgent",
    provider = "anthropic",
    model = { model = "claude-sonnet-4-6" },
    system_prompt = "You are a helpful assistant.",
}

-- A small read-only subset: `@all` expands from the live registry (write tools,
-- plus optional ones like `ack` when installed), which would make goldens
-- machine-dependent.
M.READONLY_TOOLS = { "read_file", "ls", "find", "grep", "chat_history_search" }

-- The transcripts both the regenerator and the verifier walk. Duplicating this
-- list was the other half of the same hand-sync it replaced.
M.FIXTURES = {
    "single-user",
    "simple-chat",
    "one-round-tool-use",
    "two-round-tool-use",
    "mixed-text-and-tools",
    "tool-error",
    "dynamic-fence-stress",
}

M.OPENAI_FIXTURES = {
    "one-round-tool-use",
    "two-round-tool-use",
    "tool-error",
    "mixed-text-and-tools",
}

return M
