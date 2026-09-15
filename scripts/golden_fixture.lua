-- luacheck: globals vim
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

-- The openai-wire pinning. Both the regenerator and the verifier need it and
-- were hand-syncing it — the same duplication this module exists to end
-- ("a golden must depend on nothing a person has to remember").
M.OPENAI_WIRE = { provider = "cliproxyapi", model = { model = "gpt-5.6-sol" } }

M.OPENAI_FIXTURES = {
    "one-round-tool-use",
    "two-round-tool-use",
    "tool-error",
    "mixed-text-and-tools",
}

-- Compare captured wire payloads without depending on local command version
-- probes, which asynchronous builtins no longer run. Normalize at comparison time: the regenerator
-- can retain the real wire description, and older captures remain comparable.
-- Restrict this to the dedicated backend metadata of grep/history, ls, and find;
-- message text, schemas, other tools, and substantive descriptions still count.
function M.normalize_payload(payload)
    local normalized = vim.deepcopy(payload)
    for _, tool in ipairs(normalized.tools or {}) do
        local definition = tool.type == "function" and tool["function"] or tool
        if definition.name == "grep" or definition.name == "chat_history_search" then
            definition.description = definition.description:gsub(
                "%(ripgrep %d+%.%d+%.%d+%)", "(ripgrep)"
            )
        elseif definition.name == "ls" or definition.name == "find" then
            -- %b() includes nested metadata such as BSD ls (macOS); anchoring
            -- the dedicated leading sentence leaves substantive prose intact.
            local prefix = definition.name == "ls" and "List directory contents using the system ls command "
                or "Search for files and directories using the system find command "
            definition.description = definition.description:gsub(
                "^(" .. prefix .. ")%b()(%.)", "%1(" .. definition.name .. ")%2", 1
            )
        end
    end
    return normalized
end

return M
