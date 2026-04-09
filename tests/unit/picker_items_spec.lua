local agent_picker         = require("parley.agent_picker")
local system_prompt_picker = require("parley.system_prompt_picker")
local outline              = require("parley.outline")
local custom_prompts       = require("parley.custom_prompts")
local helper               = require("parley.helper")

-- ---------------------------------------------------------------------------
-- Shared fake plugin state for agent / system-prompt picker tests
-- ---------------------------------------------------------------------------
local function make_plugin(current_agent)
    return {
        _agents = { "zebra", "alpha", "mango" },
        agents = {
            alpha = { provider = "openai",     model = "gpt-4"       },
            mango = { provider = "googleai",   model = "gemini-pro"  },
            zebra = { provider = "anthropic",  model = "claude-3"    },
        },
        _state = { agent = current_agent },
    }
end

local function make_prompt_plugin(current_prompt)
    local prompts = {
        concise = { system_prompt = "Be brief." },
        expert  = { system_prompt = "You are an expert." },
        verbose = { system_prompt = "Explain everything in great detail." },
    }
    return {
        _system_prompts = { "verbose", "concise", "expert" },
        system_prompts = prompts,
        _builtin_system_prompts = vim.deepcopy(prompts),
        _state = { system_prompt = current_prompt },
    }
end

-- Set up custom_prompts with a temp dir so source() works
local _tmpdir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-picker-items-" .. string.format("%x", math.random(0, 0xFFFFFF))
vim.fn.mkdir(_tmpdir, "p")
custom_prompts.setup(helper, _tmpdir)

-- ---------------------------------------------------------------------------
-- agent_picker._build_items
-- ---------------------------------------------------------------------------
describe("agent_picker item building", function()
    it("places the current agent first", function()
        local items = agent_picker._build_items(make_plugin("mango"))
        assert.equals("mango", items[1].name)
    end)

    it("marks the current agent with a check mark", function()
        local items = agent_picker._build_items(make_plugin("mango"))
        assert.truthy(items[1].display:find("✓", 1, true))
    end)

    it("does not mark non-current agents with a check mark", function()
        local items = agent_picker._build_items(make_plugin("mango"))
        for i = 2, #items do
            assert.falsy(items[i].display:find("✓", 1, true))
        end
    end)

    it("sorts remaining agents alphabetically after the current one", function()
        local items = agent_picker._build_items(make_plugin("zebra"))
        -- zebra is current (first); alpha and mango follow in alphabetical order
        assert.equals("zebra", items[1].name)
        assert.equals("alpha", items[2].name)
        assert.equals("mango", items[3].name)
    end)

    it("includes model name in display", function()
        local items = agent_picker._build_items(make_plugin("alpha"))
        local alpha = items[1]
        assert.truthy(alpha.display:find("gpt-4", 1, true))
    end)

    it("includes provider name in display", function()
        local items = agent_picker._build_items(make_plugin("alpha"))
        local alpha = items[1]
        assert.truthy(alpha.display:find("openai", 1, true))
    end)

    -- Task 1.7 of #81: [🔧] badge for agents opting into client-side tool use
    describe("tool badge", function()
        local function make_tool_plugin(current_agent)
            return {
                _agents = { "vanilla", "agentic", "empty_tools" },
                agents = {
                    vanilla = {
                        provider = "anthropic",
                        model = "claude-sonnet-4-6",
                    },
                    agentic = {
                        provider = "anthropic",
                        model = "claude-sonnet-4-6",
                        tools = { "read_file", "edit_file" },
                    },
                    empty_tools = {
                        provider = "anthropic",
                        model = "claude-sonnet-4-6",
                        tools = {},
                    },
                },
                _state = { agent = current_agent },
            }
        end

        it("shows [🔧] next to agents with a non-empty tools list", function()
            local items = agent_picker._build_items(make_tool_plugin("vanilla"))
            local agentic = nil
            for _, it in ipairs(items) do
                if it.name == "agentic" then agentic = it end
            end
            assert.is_not_nil(agentic)
            assert.truthy(agentic.display:find("[🔧]", 1, true))
        end)

        it("does NOT show [🔧] on vanilla agents (no tools field)", function()
            local items = agent_picker._build_items(make_tool_plugin("agentic"))
            local vanilla = nil
            for _, it in ipairs(items) do
                if it.name == "vanilla" then vanilla = it end
            end
            assert.is_not_nil(vanilla)
            assert.falsy(vanilla.display:find("[🔧]", 1, true))
        end)

        it("does NOT show [🔧] on agents with empty tools list", function()
            local items = agent_picker._build_items(make_tool_plugin("vanilla"))
            local empty = nil
            for _, it in ipairs(items) do
                if it.name == "empty_tools" then empty = it end
            end
            assert.is_not_nil(empty)
            assert.falsy(empty.display:find("[🔧]", 1, true))
        end)

        it("badge appears even when the agentic agent is the current one", function()
            local items = agent_picker._build_items(make_tool_plugin("agentic"))
            -- current agent is first
            assert.equals("agentic", items[1].name)
            assert.truthy(items[1].display:find("[🔧]", 1, true))
            -- and the current-agent check mark still renders
            assert.truthy(items[1].display:find("✓", 1, true))
        end)
    end)
end)

-- ---------------------------------------------------------------------------
-- system_prompt_picker._build_items
-- ---------------------------------------------------------------------------
describe("system_prompt_picker item building", function()
    it("places the current prompt first", function()
        local items = system_prompt_picker._build_items(make_prompt_plugin("expert"))
        assert.equals("expert", items[1].name)
    end)

    it("marks the current prompt with a check mark", function()
        local items = system_prompt_picker._build_items(make_prompt_plugin("expert"))
        assert.truthy(items[1].display:find("✓", 1, true))
    end)

    it("sorts remaining prompts alphabetically after the current one", function()
        local items = system_prompt_picker._build_items(make_prompt_plugin("verbose"))
        assert.equals("verbose", items[1].name)
        assert.equals("concise", items[2].name)
        assert.equals("expert",  items[3].name)
    end)

    it("truncates long system prompt descriptions to 80 chars with ...", function()
        local plugin = {
            _system_prompts = { "long" },
            system_prompts  = { long = { system_prompt = string.rep("a", 200) } },
            _state          = { system_prompt = "other" },
        }
        local items = system_prompt_picker._build_items(plugin)
        -- description = first 80 chars + "..."
        local desc = items[1].display:match(" %- (.+)$")
        assert.is_not_nil(desc)
        assert.is_true(#desc <= 83 + 3) -- 80 chars + "..."
        assert.truthy(desc:find("%.%.%.", 1, false))
    end)
end)

-- ---------------------------------------------------------------------------
-- outline._build_picker_items
-- ---------------------------------------------------------------------------
describe("outline picker item building", function()
    local config = { chat_user_prefix = "💬:" }

    local function make_buf(lines)
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        return bufnr
    end

    it("returns items in document order (ascending line numbers)", function()
        local bufnr = make_buf({
            "💬: First question",
            "",
            "💬: Second question",
            "",
            "💬: Third question",
        })

        local items = outline._build_picker_items(bufnr, config)
        assert.equals(3, #items)
        -- Each successive item must have a higher line number
        for i = 2, #items do
            assert.is_true(
                items[i].value.lnum > items[i - 1].value.lnum,
                "items should be in ascending lnum order"
            )
        end
    end)

    it("excludes markdown headers from outline", function()
        local bufnr = make_buf({ "# Top heading", "## Sub heading" })
        local items = outline._build_picker_items(bufnr, config)
        assert.equals(0, #items)
    end)

    it("includes user-prefix lines", function()
        local bufnr = make_buf({ "💬: A question" })
        local items = outline._build_picker_items(bufnr, config)
        assert.equals(1, #items)
        assert.truthy(items[1].display:find("💬:", 1, true))
    end)

    it("skips lines inside code blocks", function()
        local bufnr = make_buf({
            "```",
            "💬: Not a question",
            "```",
            "💬: Real question",
        })
        local items = outline._build_picker_items(bufnr, config)
        assert.equals(1, #items)
        assert.truthy(items[1].display:find("Real question", 1, true))
    end)

    it("returns an empty list for a buffer with no outline items", function()
        local bufnr = make_buf({ "just plain text", "more plain text" })
        local items = outline._build_picker_items(bufnr, config)
        assert.equals(0, #items)
    end)

    it("stores the correct line number in item.value.lnum", function()
        local bufnr = make_buf({
            "plain",
            "💬: First question",  -- line 2
            "plain",
            "💬: Second question", -- line 4
        })
        local items = outline._build_picker_items(bufnr, config)
        assert.equals(2, items[1].value.lnum)
        assert.equals(4, items[2].value.lnum)
    end)
end)
