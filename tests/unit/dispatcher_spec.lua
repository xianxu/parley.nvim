-- Unit tests for D.prepare_payload in lua/parley/dispatcher.lua
--
-- prepare_payload is a pure table transformation function (no I/O, no curl).
-- It does require("parley") inside provider branches to read _state.web_search,
-- so we set parley._state directly in test setup.

local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-dispatcher-" .. os.time()

-- Bootstrap parley so that require("parley") works and _state is populated.
local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

local dispatcher = require("parley.dispatcher")

-- Helper to build a simple messages array.
local function msgs(...)
    local result = {}
    for _, m in ipairs({ ... }) do
        table.insert(result, m)
    end
    return result
end

local function user(text)     return { role = "user",      content = text } end
local function assistant(text) return { role = "assistant", content = text } end
local function system(text)   return { role = "system",    content = text } end

describe("prepare_payload: string model (passthrough)", function()
    it("returns model, stream=true, and messages as-is", function()
        local m = msgs(user("hello"))
        local payload = dispatcher.prepare_payload(m, "gpt-4o", "openai")
        assert.equals("gpt-4o", payload.model)
        assert.is_true(payload.stream)
        assert.equals(1, #payload.messages)
    end)
end)

describe("prepare_payload: openai provider (table model)", function()
    local model = { model = "gpt-4o", temperature = 0.9, top_p = 0.95, max_tokens = 2048 }

    it("includes stream=true", function()
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "openai")
        assert.is_true(payload.stream)
    end)

    it("includes stream_options.include_usage", function()
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "openai")
        assert.is_not_nil(payload.stream_options)
        assert.is_true(payload.stream_options.include_usage)
    end)

    it("sets max_tokens for standard models", function()
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "openai")
        assert.equals(2048, payload.max_tokens)
    end)

    it("uses max_completion_tokens instead of max_tokens for gpt-5 models", function()
        local gpt5 = { model = "gpt-5", temperature = 1.0, top_p = 1.0, max_tokens = 4096 }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), gpt5, "openai")
        assert.equals(4096, payload.max_completion_tokens)
        assert.is_nil(payload.max_tokens)
    end)

    it("preserves system messages for gpt-4o", function()
        local m = msgs(system("You are helpful."), user("hi"))
        local payload = dispatcher.prepare_payload(m, model, "openai")
        -- system message should remain
        local has_system = false
        for _, msg in ipairs(payload.messages) do
            if msg.role == "system" then has_system = true end
        end
        assert.is_true(has_system)
    end)

    it("preserves system messages for o3 models (reasoning models now support them)", function()
        local o3 = { model = "o3-mini", temperature = 1.0, top_p = 1.0, max_tokens = 4096 }
        local m = msgs(system("You are helpful."), user("hi"))
        local payload = dispatcher.prepare_payload(m, o3, "openai")
        local has_system = false
        for _, msg in ipairs(payload.messages) do
            if msg.role == "system" then has_system = true end
        end
        assert.is_true(has_system)
    end)

    it("sets reasoning_effort for o3 models", function()
        local o3 = { model = "o3-mini", temperature = 1.0, top_p = 1.0, max_tokens = 4096, reasoning_effort = "high" }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), o3, "openai")
        assert.equals("high", payload.reasoning_effort)
    end)

    it("removes temperature, top_p, max_tokens for o-series (reasoning models)", function()
        local o3 = { model = "o3-mini", temperature = 1.0, top_p = 1.0, max_tokens = 4096 }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), o3, "openai")
        assert.is_nil(payload.temperature)
        assert.is_nil(payload.top_p)
        assert.is_nil(payload.max_tokens)
    end)

    it("uses base model when web_search is false", function()
        parley._state = parley._state or {}
        parley._state.web_search = false
        local m = { model = "gpt-4o", temperature = 0.9, top_p = 0.95, max_tokens = 2048, search_model = "gpt-4o-search-preview" }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), m, "openai")
        assert.equals("gpt-4o", payload.model)
    end)

    it("swaps to search_model when web_search is true", function()
        parley._state = parley._state or {}
        parley._state.web_search = true
        local m = { model = "gpt-4o", temperature = 0.9, top_p = 0.95, max_tokens = 2048, search_model = "gpt-4o-search-preview" }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), m, "openai")
        assert.equals("gpt-4o-search-preview", payload.model)
        parley._state.web_search = false
    end)

    it("does not swap model without search_model attribute", function()
        parley._state = parley._state or {}
        parley._state.web_search = true
        local m = { model = "gpt-4", temperature = 1.0, top_p = 1.0, max_tokens = 4096 }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), m, "openai")
        assert.equals("gpt-4", payload.model)
        parley._state.web_search = false
    end)
end)

describe("prepare_payload: anthropic provider", function()
    before_each(function()
        -- Disable web search by default for most tests
        parley._state = parley._state or {}
        parley._state.web_search = false
    end)

    local model = { model = "claude-haiku-20240307", temperature = 0.8, top_p = 1.0, max_tokens = 1024 }

    it("extracts system messages into payload.system array", function()
        local m = msgs(system("You are helpful."), user("hi"))
        local payload = dispatcher.prepare_payload(m, model, "anthropic")
        assert.is_not_nil(payload.system)
        assert.equals(1, #payload.system)
        assert.equals("You are helpful.", payload.system[1].text)
        assert.equals("text", payload.system[1].type)
    end)

    it("removes system messages from payload.messages", function()
        local m = msgs(system("You are helpful."), user("hi"))
        local payload = dispatcher.prepare_payload(m, model, "anthropic")
        for _, msg in ipairs(payload.messages) do
            assert.not_equals("system", msg.role)
        end
    end)

    it("preserves cache_control on system blocks", function()
        local m = msgs(
            { role = "system", content = "cached system prompt", cache_control = { type = "ephemeral" } },
            user("hello")
        )
        local payload = dispatcher.prepare_payload(m, model, "anthropic")
        assert.is_not_nil(payload.system[1].cache_control)
        assert.equals("ephemeral", payload.system[1].cache_control.type)
    end)

    it("handles multiple system messages", function()
        local m = msgs(
            system("Prompt 1."),
            system("Prompt 2."),
            user("hi")
        )
        local payload = dispatcher.prepare_payload(m, model, "anthropic")
        assert.equals(2, #payload.system)
    end)

    it("omits payload.system when there are no system messages", function()
        local m = msgs(user("hi"))
        local payload = dispatcher.prepare_payload(m, model, "anthropic")
        assert.is_nil(payload.system)
    end)

    it("does NOT add tools when web_search is false", function()
        parley._state.web_search = false
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "anthropic")
        assert.is_nil(payload.tools)
    end)

    it("adds web_search and web_fetch tools when web_search is true", function()
        parley._state.web_search = true
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "anthropic")
        assert.is_not_nil(payload.tools)
        assert.equals(2, #payload.tools)
        local names = {}
        local types = {}
        for _, t in ipairs(payload.tools) do
            names[t.name] = true
            types[t.name] = t.type
        end
        assert.is_true(names["web_search"])
        assert.is_true(names["web_fetch"])
        assert.equals("web_search_20260209", types["web_search"])
        assert.equals("web_fetch_20260209", types["web_fetch"])
        -- reset
        parley._state.web_search = false
    end)

    it("sets allowed_callers={direct} for claude-haiku-4-5 web tools", function()
        parley._state.web_search = true
        local haiku45 = { model = "claude-haiku-4-5-20251001", temperature = 0.8, top_p = 1.0, max_tokens = 1024 }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), haiku45, "anthropic")
        assert.is_not_nil(payload.tools)
        assert.equals(2, #payload.tools)
        for _, t in ipairs(payload.tools) do
            assert.is_not_nil(t.allowed_callers)
            assert.equals(1, #t.allowed_callers)
            assert.equals("direct", t.allowed_callers[1])
        end
        parley._state.web_search = false
    end)

    it("does not set allowed_callers for non-haiku-4-5 models", function()
        parley._state.web_search = true
        local sonnet = { model = "claude-sonnet-4-6-20251105", temperature = 0.8, top_p = 1.0, max_tokens = 1024 }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), sonnet, "anthropic")
        assert.is_not_nil(payload.tools)
        for _, t in ipairs(payload.tools) do
            assert.is_nil(t.allowed_callers)
        end
        parley._state.web_search = false
    end)

    it("sets stream=true", function()
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "anthropic")
        assert.is_true(payload.stream)
    end)

    it("sets max_tokens from model", function()
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "anthropic")
        assert.equals(1024, payload.max_tokens)
    end)
end)

describe("prepare_payload: googleai provider", function()
    before_each(function()
        parley._state = parley._state or {}
        parley._state.web_search = false
    end)

    local model = {
        model = "gemini-2.5-flash",
        temperature = 1.0,
        top_p = 1.0,
        top_k = 64,
        max_tokens = 8192,
    }

    it("renames system role to user", function()
        local m = msgs(system("Be helpful."), user("hi"))
        local payload = dispatcher.prepare_payload(m, model, "googleai")
        local has_system = false
        for _, msg in ipairs(payload.contents) do
            if msg.role == "system" then has_system = true end
        end
        assert.is_false(has_system)
        -- first should now be "user"
        assert.equals("user", payload.contents[1].role)
    end)

    it("renames assistant role to model", function()
        local m = msgs(user("hi"), assistant("hello back"))
        local payload = dispatcher.prepare_payload(m, model, "googleai")
        assert.equals("model", payload.contents[2].role)
    end)

    it("wraps content in parts array with text field", function()
        local m = msgs(user("hello"))
        local payload = dispatcher.prepare_payload(m, model, "googleai")
        assert.is_not_nil(payload.contents[1].parts)
        assert.equals("hello", payload.contents[1].parts[1].text)
        -- content field should be removed
        assert.is_nil(payload.contents[1].content)
    end)

    it("merges consecutive same-role messages", function()
        -- system messages become "user", so three consecutive "user" items collapse to one
        local m = msgs(
            { role = "system", content = "sys1" },
            { role = "system", content = "sys2" },
            user("actual question")
        )
        local payload = dispatcher.prepare_payload(m, model, "googleai")
        -- all three had role "user" after rename, so they merge into one content with 3 parts
        assert.equals("user", payload.contents[1].role)
        assert.equals(3, #payload.contents[1].parts)
        assert.equals(1, #payload.contents)
    end)

    it("merges two consecutive user messages but keeps a following model message separate", function()
        local m = msgs(
            user("first user"),
            user("second user"),
            assistant("assistant reply")
        )
        local payload = dispatcher.prepare_payload(m, model, "googleai")
        -- two user merged + one model = 2 contents
        assert.equals(2, #payload.contents)
        assert.equals("user", payload.contents[1].role)
        assert.equals(2, #payload.contents[1].parts)
        assert.equals("model", payload.contents[2].role)
    end)

    it("puts generation params in generationConfig", function()
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "googleai")
        assert.is_not_nil(payload.generationConfig)
        assert.equals(8192, payload.generationConfig.maxOutputTokens)
    end)

    it("uses contents key (not messages)", function()
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "googleai")
        assert.is_not_nil(payload.contents)
        assert.is_nil(payload.messages)
    end)

    it("includes safetySettings", function()
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "googleai")
        assert.is_not_nil(payload.safetySettings)
        assert.is_true(#payload.safetySettings > 0)
    end)

    it("does NOT add tools when web_search is false", function()
        parley._state.web_search = false
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "googleai")
        assert.is_nil(payload.tools)
    end)

    it("adds google_search tool when web_search is true", function()
        parley._state.web_search = true
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "googleai")
        assert.is_not_nil(payload.tools)
        assert.equals(1, #payload.tools)
        assert.is_not_nil(payload.tools[1].google_search)
        parley._state.web_search = false
    end)
end)

describe("prepare_payload: copilot provider", function()
    it("remaps gpt-4o to gpt-4o-2024-05-13", function()
        local model = { model = "gpt-4o", temperature = 1.0, top_p = 1.0, max_tokens = 4096 }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "copilot")
        assert.equals("gpt-4o-2024-05-13", payload.model)
    end)

    it("does not remap other copilot models", function()
        local model = { model = "claude-3-sonnet", temperature = 1.0, top_p = 1.0, max_tokens = 4096 }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "copilot")
        assert.equals("claude-3-sonnet", payload.model)
    end)
end)

describe("prepare_payload: cliproxyapi provider", function()
    local function set_strategy(strategy)
        dispatcher.providers = dispatcher.providers or {}
        dispatcher.providers.cliproxyapi = dispatcher.providers.cliproxyapi or {}
        dispatcher.providers.cliproxyapi.web_search_strategy = strategy
    end

    before_each(function()
        set_strategy("none")
        parley._state = parley._state or {}
        parley._state.web_search = false
    end)

    it("uses openai-compatible streaming payload shape", function()
        local model = { model = "gpt-4o", temperature = 1.0, top_p = 1.0, max_tokens = 1024 }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "cliproxyapi")
        assert.equals("gpt-4o", payload.model)
        assert.is_true(payload.stream)
        assert.is_not_nil(payload.stream_options)
        assert.is_true(payload.stream_options.include_usage)
    end)

    it("applies gpt-5 max_completion_tokens mapping", function()
        local model = { model = "gpt-5.4", max_tokens = 3072 }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "cliproxyapi")
        assert.equals(3072, payload.max_completion_tokens)
        assert.is_nil(payload.max_tokens)
    end)

    it("does not swap to search_model when strategy is none", function()
        parley._state.web_search = true
        local model = { model = "gpt-5.4", search_model = "gpt-5-search-api" }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "cliproxyapi")
        assert.equals("gpt-5.4", payload.model)
    end)

    it("swaps to search_model in openai_search_model strategy", function()
        set_strategy("openai_search_model")
        parley._state.web_search = true
        local model = { model = "gpt-5.4", search_model = "gpt-5-search-api" }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "cliproxyapi")
        assert.equals("gpt-5-search-api", payload.model)
    end)

    it("uses openai web_search tools without model swap in openai_tools_route strategy", function()
        set_strategy("openai_tools_route")
        parley._state.web_search = true
        local model = { model = "gpt-5.4", search_model = "gpt-5-search-api" }
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "cliproxyapi")
        assert.equals("gpt-5.4", payload.model)
        assert.is_not_nil(payload.tools)
        assert.equals(1, #payload.tools)
        assert.equals("web_search", payload.tools[1].type)
        assert.equals("auto", payload.tool_choice)
    end)

    it("uses anthropic payload route for claude models in anthropic_tools_route strategy", function()
        set_strategy("anthropic_tools_route")
        parley._state.web_search = true
        local model = { model = "claude-sonnet-4-6", temperature = 0.8, max_tokens = 1024 }
        local payload = dispatcher.prepare_payload(msgs(system("sys"), user("hi")), model, "cliproxyapi")
        assert.equals("claude-sonnet-4-6", payload.model)
        assert.is_not_nil(payload.tools)
        assert.equals(2, #payload.tools)
        assert.is_nil(payload.tool_choice)
        assert.same({ "direct" }, payload.tools[1].allowed_callers)
        assert.same({ "direct" }, payload.tools[2].allowed_callers)
        assert.equals("anthropic", payload._parley_route)
    end)

    it("forces web_search tool_choice for code_execution models in anthropic_tools_route strategy", function()
        set_strategy("anthropic_tools_route")
        parley._state.web_search = true
        local model = { model = "code_execution_20260120", temperature = 0.8, max_tokens = 1024 }
        local payload = dispatcher.prepare_payload(msgs(system("sys"), user("hi")), model, "cliproxyapi")
        assert.equals("code_execution_20260120", payload.model)
        assert.is_not_nil(payload.tools)
        assert.equals(2, #payload.tools)
        assert.same({ "direct" }, payload.tools[1].allowed_callers)
        assert.same({ "direct" }, payload.tools[2].allowed_callers)
        assert.is_not_nil(payload.tool_choice)
        assert.equals("tool", payload.tool_choice.type)
        assert.equals("web_search", payload.tool_choice.name)
        assert.equals("anthropic", payload._parley_route)
    end)

    it("allows per-model strategy override over provider default", function()
        set_strategy("none")
        parley._state.web_search = true
        local model = {
            model = "claude-sonnet-4-6",
            temperature = 0.8,
            max_tokens = 1024,
            web_search_strategy = "anthropic_tools_route",
        }
        local payload = dispatcher.prepare_payload(msgs(system("sys"), user("hi")), model, "cliproxyapi")
        assert.is_not_nil(payload.tools)
        assert.equals("anthropic", payload._parley_route)
    end)
end)
