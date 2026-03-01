-- Unit tests for D.prepare_payload in lua/parley/dispatcher.lua
--
-- prepare_payload is a pure table transformation function (no I/O, no curl).
-- It does require("parley") inside the anthropic branch to read _state.claude_web_search,
-- so we set parley._state directly in test setup.

local tmp_dir = "/tmp/parley-test-dispatcher-" .. os.time()

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

    it("strips system messages for o3 models", function()
        local o3 = { model = "o3-mini", temperature = 1.0, top_p = 1.0, max_tokens = 4096 }
        local m = msgs(system("You are helpful."), user("hi"))
        local payload = dispatcher.prepare_payload(m, o3, "openai")
        for _, msg in ipairs(payload.messages) do
            assert.not_equals("system", msg.role)
        end
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
end)

describe("prepare_payload: anthropic provider", function()
    before_each(function()
        -- Disable web search by default for most tests
        parley._state = parley._state or {}
        parley._state.claude_web_search = false
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

    it("does NOT add tools when claude_web_search is false", function()
        parley._state.claude_web_search = false
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "anthropic")
        assert.is_nil(payload.tools)
    end)

    it("adds web_search and web_fetch tools when claude_web_search is true", function()
        parley._state.claude_web_search = true
        local payload = dispatcher.prepare_payload(msgs(user("hi")), model, "anthropic")
        assert.is_not_nil(payload.tools)
        assert.equals(2, #payload.tools)
        local names = {}
        for _, t in ipairs(payload.tools) do names[t.name] = true end
        assert.is_true(names["web_search"])
        assert.is_true(names["web_fetch"])
        -- reset
        parley._state.claude_web_search = false
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
