-- Unit tests for per-agent tools config and ToolSonnet default.
--
-- M1 Task 1.4: agents can declare a `tools` field (list of builtin tool
-- names) plus optional `max_tool_iterations` and `tool_result_max_bytes`
-- overrides. Setup validates that referenced tool names exist in the
-- registry, raises with the offending name on unknown entries, and
-- applies default values for the two numeric fields when absent.
--
-- Also verifies that the default `ToolSonnet` agent ships in the
-- default config selecting tools via the `@all` group sentinel
-- (read + edit/write) — an agentic Claude with the full builtin tool
-- set out of the box (#157: the default was deliberately swapped
-- @readonly → @all in commit 8381829). The intended default is pinned
-- once in EXPECTED_DEFAULT_TOOLS below, so a future swap fails in ONE
-- obvious place instead of drifting the suite silently.

local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-config-tools-" .. os.time()

local parley = require("parley")

-- Single source of truth for the shipped default Tool* agents' tool set
-- (mirrors the READONLY_TOOLS hoist in parley_harness_golden_spec.lua). Swap
-- this one line if the default permission posture changes; the canary test
-- below asserts every tool-enabled default agent matches it (#157).
local EXPECTED_DEFAULT_TOOLS = { "@all" }

-- parley.setup() merges into M.agents rather than resetting; wipe it
-- before each run so stale agents from prior tests (including one that
-- raised during validation) do not leak across fresh_setup calls.
local function fresh_setup(agents_override)
    parley.agents = {}
    parley.system_prompts = {}
    parley.hooks = {}
    parley.setup({
        chat_dir = tmp_dir,
        state_dir = tmp_dir .. "/state",
        providers = {},
        api_keys = {},
        agents = agents_override,
    })
end

describe("per-agent tools config", function()
    it("accepts an agent with a valid tools list", function()
        fresh_setup({
            {
                provider = "anthropic",
                name = "TestToolsAgent",
                model = { model = "claude-sonnet-4-6", temperature = 0.8 },
                system_prompt = "test",
                tools = { "read_file" },
            },
        })
        assert.is_not_nil(parley.agents["TestToolsAgent"])
        assert.same({ "read_file" }, parley.agents["TestToolsAgent"].tools)
    end)

    it("raises on unknown tool name, mentioning the offending name", function()
        local ok, err = pcall(fresh_setup, {
            {
                provider = "anthropic",
                name = "BadToolsAgent",
                model = { model = "claude-sonnet-4-6", temperature = 0.8 },
                system_prompt = "test",
                tools = { "nonexistent_tool" },
            },
        })
        assert.is_false(ok)
        assert.matches("nonexistent_tool", tostring(err))
    end)

    it("backward compatible: agent without tools field works unchanged", function()
        fresh_setup({
            {
                provider = "anthropic",
                name = "VanillaAgent",
                model = { model = "claude-sonnet-4-6", temperature = 0.8 },
                system_prompt = "test",
            },
        })
        assert.is_not_nil(parley.agents["VanillaAgent"])
        assert.is_nil(parley.agents["VanillaAgent"].tools)
        -- Defaults should NOT be applied to agents without tools
        assert.is_nil(parley.agents["VanillaAgent"].max_tool_iterations)
        assert.is_nil(parley.agents["VanillaAgent"].tool_result_max_bytes)
    end)

    it("single-sources the max_tool_iterations default in parley.defaults (= 42)", function()
        assert.equals(42, require("parley.defaults").max_tool_iterations)
    end)

    it("defaults max_tool_iterations to 42 when tools set but override absent", function()
        fresh_setup({
            {
                provider = "anthropic",
                name = "DefaultIterAgent",
                model = { model = "claude-sonnet-4-6", temperature = 0.8 },
                system_prompt = "test",
                tools = { "read_file" },
            },
        })
        assert.equals(42, parley.agents["DefaultIterAgent"].max_tool_iterations)
    end)

    it("defaults tool_result_max_bytes to 102400 when tools set but override absent", function()
        fresh_setup({
            {
                provider = "anthropic",
                name = "DefaultBytesAgent",
                model = { model = "claude-sonnet-4-6", temperature = 0.8 },
                system_prompt = "test",
                tools = { "read_file" },
            },
        })
        assert.equals(102400, parley.agents["DefaultBytesAgent"].tool_result_max_bytes)
    end)

    it("respects explicit max_tool_iterations override", function()
        fresh_setup({
            {
                provider = "anthropic",
                name = "CustomIterAgent",
                model = { model = "claude-sonnet-4-6", temperature = 0.8 },
                system_prompt = "test",
                tools = { "read_file" },
                max_tool_iterations = 3,
            },
        })
        assert.equals(3, parley.agents["CustomIterAgent"].max_tool_iterations)
    end)

    it("respects explicit tool_result_max_bytes override", function()
        fresh_setup({
            {
                provider = "anthropic",
                name = "CustomBytesAgent",
                model = { model = "claude-sonnet-4-6", temperature = 0.8 },
                system_prompt = "test",
                tools = { "read_file" },
                tool_result_max_bytes = 50000,
            },
        })
        assert.equals(50000, parley.agents["CustomBytesAgent"].tool_result_max_bytes)
    end)
end)

describe("default ToolSonnet", function()
    before_each(function() fresh_setup(nil) end)

    it("ships in the default config with the @all tool set", function()
        local agent = parley.agents["ToolSonnet"]
        assert.is_not_nil(agent, "ToolSonnet should ship as a default agent")
        assert.equals("anthropic", agent.provider)
        assert.is_table(agent.tools)
        -- ToolSonnet selects tools via the @all group sentinel (read +
        -- edit/write). The sentinel is carried verbatim on the config record
        -- and resolved to concrete tools at payload-build time.
        assert.same(EXPECTED_DEFAULT_TOOLS, agent.tools)
    end)

    it("has default loop limits applied", function()
        local agent = parley.agents["ToolSonnet"]
        assert.equals(42, agent.max_tool_iterations)
        assert.equals(102400, agent.tool_result_max_bytes)
    end)

    -- Anti-drift canary (#157): every tool-enabled default agent must match
    -- EXPECTED_DEFAULT_TOOLS. Discovered dynamically (not a hardcoded name
    -- list) so a future default swap — of the tool set OR the agent roster —
    -- fails loudly HERE, at the one source, instead of silently reddening the
    -- assertions scattered below.
    it("every tool-enabled default agent pins to EXPECTED_DEFAULT_TOOLS", function()
        local checked = 0
        for name, agent in pairs(parley.agents) do
            if type(agent.tools) == "table" then
                assert.same(EXPECTED_DEFAULT_TOOLS, agent.tools,
                    name .. " default tools drifted from EXPECTED_DEFAULT_TOOLS")
                checked = checked + 1
            end
        end
        assert.is_true(checked >= 1, "expected at least one tool-enabled default agent")
    end)
end)

-- Regression for the bug discovered during M1 Task 1.8 Stage 1 manual
-- verification: get_agent() returned a sanitized snapshot without the
-- tools / max_tool_iterations / tool_result_max_bytes fields, so
-- get_agent_info.tools was silently nil and prepare_payload never
-- received the agent's client-side tools. The user's first tool-use
-- request hit Anthropic as a vanilla call with only web_search/web_fetch.
--
-- The tests walk the FULL wiring chain M.agents → get_agent →
-- get_agent_info → prepare_payload to lock in the end-to-end
-- invariant, not just one hop at a time.
describe("get_agent forwards client-side tool config (full wiring chain)", function()
    before_each(function() fresh_setup(nil) end)

    it("get_agent(ToolSonnet) carries the tools field from M.agents", function()
        parley._state = parley._state or {}
        parley._state.agent = "ToolSonnet"
        local agent = parley.get_agent("ToolSonnet")
        assert.is_not_nil(agent)
        assert.is_table(agent.tools)
        assert.same(EXPECTED_DEFAULT_TOOLS, agent.tools)
    end)

    it("get_agent(ToolSonnet) forwards max_tool_iterations and tool_result_max_bytes", function()
        local agent = parley.get_agent("ToolSonnet")
        assert.equals(42, agent.max_tool_iterations)
        assert.equals(102400, agent.tool_result_max_bytes)
    end)

    it("get_agent on a vanilla agent has nil tools (no defaults leak)", function()
        local agent = parley.get_agent("Claude-Sonnet")
        assert.is_nil(agent.tools)
        assert.is_nil(agent.max_tool_iterations)
        assert.is_nil(agent.tool_result_max_bytes)
    end)

    it("get_agent_info(headers, get_agent('ToolSonnet')).tools carries the @all sentinel", function()
        local agent = parley.get_agent("ToolSonnet")
        local info = parley.get_agent_info({}, agent)
        assert.is_table(info.tools)
        assert.same(EXPECTED_DEFAULT_TOOLS, info.tools)
    end)

    -- THE end-to-end test that regresses the exact 1b8ceb8 bug. Walks all
    -- four hops: M.agents → get_agent → get_agent_info → prepare_payload
    -- and verifies the final payload.tools actually resolves the @all
    -- sentinel into concrete read+write tools. A naive bug anywhere in this
    -- chain (sanitized snapshot in get_agent, dropped field in
    -- get_agent_info, missing 4th arg in chat_respond, append-not-clobber
    -- regression in prepare_payload, broken sentinel expansion) is caught here.
    it("full wiring chain: ToolSonnet request payload resolves @all to the full read+write tool set", function()
        local dispatcher = require("parley.dispatcher")
        local agent = parley.get_agent("ToolSonnet")
        local info = parley.get_agent_info({}, agent)
        local msgs = { { role = "user", content = "hi" } }

        -- Disable web_search to isolate client-side tools in the output
        parley._state = parley._state or {}
        parley._state.web_search = false

        local payload = dispatcher.prepare_payload(msgs, info.model, info.provider, info.tools)
        assert.is_not_nil(payload.tools, "payload.tools must not be nil for a tools-enabled agent")

        -- @all expands to every registered builtin. The core read tools are
        -- present AND so are edit_file/write_file (this is a read+write agent).
        -- (ack is also a tool and may be present when installed, so assert
        -- membership, not an exact count — deterministic across machines.)
        local names = {}
        for _, t in ipairs(payload.tools) do names[t.name] = true end
        assert.is_true(names.read_file)
        assert.is_true(names.ls)
        assert.is_true(names.find)
        assert.is_true(names.grep)
        assert.is_true(names.chat_history_search)
        assert.is_true(names.edit_file, "edit_file must be present (@all agent)")
        assert.is_true(names.write_file, "write_file must be present (@all agent)")
    end)

    -- Same end-to-end chain but with web_search ENABLED, to verify that
    -- the append-not-clobber invariant holds when driven through the
    -- real agent/info objects (not just a hand-crafted agent_tools
    -- argument like dispatcher_spec.lua does).
    it("full wiring chain + web_search: @all client tools APPEND to web_search/web_fetch", function()
        local dispatcher = require("parley.dispatcher")
        local agent = parley.get_agent("ToolSonnet")
        local info = parley.get_agent_info({}, agent)
        local msgs = { { role = "user", content = "hi" } }

        parley._state = parley._state or {}
        parley._state.web_search = true

        local payload = dispatcher.prepare_payload(msgs, info.model, info.provider, info.tools)
        assert.is_not_nil(payload.tools)

        local names = {}
        for _, t in ipairs(payload.tools) do names[t.name] = true end
        assert.is_true(names.web_search, "web_search must be preserved")
        assert.is_true(names.web_fetch, "web_fetch must be preserved")
        assert.is_true(names.read_file, "read_file must be appended")
        assert.is_true(names.chat_history_search, "chat_history_search must be appended")
        assert.is_true(names.write_file, "write_file must be appended (@all agent)")

        parley._state.web_search = false
    end)
end)

-- Issue #118: get_agent must forward synthetic_system_prompt and
-- synthetic_system_prompt_ack through its sanitized snapshot, otherwise
-- agent_info.resolve sees nil and the synthetic transformation never
-- fires. Same sanitized-snapshot pitfall as the M1 tools field above.
describe("get_agent forwards synthetic_system_prompt config", function()
    before_each(function() fresh_setup(nil) end)

    it("forwards both fields when present on the agent record", function()
        parley.agents["SynTest"] = {
            provider = "anthropic",
            name = "SynTest",
            model = { model = "claude-sonnet-4-6" },
            system_prompt = "Be helpful.",
            synthetic_system_prompt = true,
            synthetic_system_prompt_ack = "Understood.",
        }
        local agent = parley.get_agent("SynTest")
        assert.is_true(agent.synthetic_system_prompt)
        assert.equals("Understood.", agent.synthetic_system_prompt_ack)
    end)

    it("forwards as nil when the agent has no synthetic config", function()
        local agent = parley.get_agent("ToolSonnet")
        assert.is_nil(agent.synthetic_system_prompt)
        assert.is_nil(agent.synthetic_system_prompt_ack)
    end)

    it("flag survives the full wiring chain into agent_info", function()
        parley.agents["SynTest"] = {
            provider = "anthropic",
            name = "SynTest",
            model = { model = "claude-sonnet-4-6" },
            system_prompt = "Be helpful.",
            synthetic_system_prompt = true,
        }
        local agent = parley.get_agent("SynTest")
        local info = parley.get_agent_info({}, agent)
        assert.is_true(info.synthetic_system_prompt)
    end)
end)

describe("new config prefix + shortcut defaults", function()
    it("defines chat_tool_use_prefix and chat_tool_result_prefix", function()
        fresh_setup(nil)
        assert.equals("🔧:", parley.config.chat_tool_use_prefix)
        assert.equals("📎:", parley.config.chat_tool_result_prefix)
    end)

    it("uses peer/branch defaults and leaves tool folds unbound", function()
        fresh_setup(nil)
        assert.equals("<C-g>p", parley.config.global_shortcut_super_repo_toggle.shortcut)
        assert.same({ "n", "i" }, parley.config.global_shortcut_super_repo_toggle.modes)
        assert.equals("<C-g>b", parley.config.chat_shortcut_prune.shortcut)
        assert.same({ "n" }, parley.config.chat_shortcut_prune.modes)
        assert.is_nil(parley.config.chat_shortcut_toggle_tool_folds)
    end)
end)
