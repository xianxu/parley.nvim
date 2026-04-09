-- Unit tests for M._build_messages in lua/parley/init.lua
--
-- _build_messages is the extracted message-building logic from chat_respond.
-- It's pure logic except for file I/O via helpers.format_file_content,
-- which we stub out in tests.

local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-build-messages-" .. os.time()

-- Bootstrap parley
local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
    chat_memory = {
        enable = true,
        max_full_exchanges = 2,
        omit_user_text = "[Previous messages omitted]"
    },
    raw_mode = {
        parse_raw_request = false
    }
})

-- Helper to create a minimal agent
local function agent(name, provider, system_prompt)
    return {
        name = name or "test-agent",
        provider = provider or "openai",
        model = "gpt-4o",
        system_prompt = system_prompt or "You are a helpful assistant."
    }
end

-- Helper to create a minimal parsed_chat structure
local function parsed_chat(exchanges, headers)
    return {
        headers = headers or {},
        exchanges = exchanges or {}
    }
end

-- Helper to create an exchange
local function exchange(question_content, answer_content, summary_content, file_refs)
    local ex = {
        question = {
            line_start = 10,
            line_end = 10,
            content = question_content or "Test question",
            file_references = file_refs or {}
        }
    }
    if answer_content then
        ex.answer = {
            line_start = 12,
            line_end = 12,
            content = answer_content
        }
    end
    if summary_content then
        ex.summary = {
            content = summary_content
        }
    end
    return ex
end

-- Stub helpers for file I/O
local stub_helpers = {
    is_remote_url = function(path) return path:match("^https?://") ~= nil end,
    is_directory = function(path) return false end,
    format_file_content = function(path) return "File content: " .. path end,
    process_directory_pattern = function(path) return "Directory content: " .. path end
}

-- Stub logger
local stub_logger = {
    debug = function(msg) end,
    warning = function(msg) end
}

describe("_build_messages: basic structure", function()
    it("single exchange with no answer produces system + user message", function()
        local pc = parsed_chat({ exchange("What is Lua?") })
        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        assert.equals(2, #messages)
        assert.equals("system", messages[1].role)
        assert.is_true(#messages[1].content > 0) -- Has some system prompt content
        assert.equals("user", messages[2].role)
        assert.equals("What is Lua?", messages[2].content)
    end)

    it("single exchange with answer produces system + user + assistant", function()
        local pc = parsed_chat({ exchange("What is Lua?", "Lua is a scripting language.") })
        pc.exchanges[1].answer.line_start = 12

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 2, -- Simulate we're on a second question
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- Should have: system, user (Q1), assistant (A1)
        assert.equals(3, #messages)
        assert.equals("system", messages[1].role)
        assert.is_true(#messages[1].content > 0)
        assert.equals("user", messages[2].role)
        assert.equals("What is Lua?", messages[2].content)
        assert.equals("assistant", messages[3].role)
        assert.equals("Lua is a scripting language.", messages[3].content)
    end)
end)

describe("_build_messages: memory truncation", function()
    it("old exchanges beyond max_full_exchanges become placeholder text", function()
        local pc = parsed_chat({
            exchange("Question 1", "Answer 1"),
            exchange("Question 2", "Answer 2"),
            exchange("Question 3", "Answer 3"),
            exchange("Question 4") -- current question
        })

        -- Set line_start for each exchange
        pc.exchanges[1].question.line_start = 10
        pc.exchanges[1].answer.line_start = 12
        pc.exchanges[2].question.line_start = 14
        pc.exchanges[2].answer.line_start = 16
        pc.exchanges[3].question.line_start = 18
        pc.exchanges[3].answer.line_start = 20
        pc.exchanges[4].question.line_start = 22

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 4,
            agent = agent(),
            config = parley.config, -- max_full_exchanges = 2
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- Should have: system, placeholder (Q1), assistant (A1), user (Q2), assistant (A2), user (Q3), assistant (A3), user (Q4)
        -- Actually, with max_full_exchanges=2, exchanges 3 and 4 are preserved (last 2)
        -- Exchange 1 and 2 should be summarized
        assert.equals(8, #messages) -- system + Q1(placeholder) + A1 + Q2(placeholder) + A2 + Q3 + A3 + Q4
        assert.equals("system", messages[1].role)
        assert.equals("user", messages[2].role)
        assert.equals("[Previous messages omitted]", messages[2].content)
        assert.equals("assistant", messages[3].role)
        assert.equals("user", messages[4].role)
        assert.equals("[Previous messages omitted]", messages[4].content)
        assert.equals("assistant", messages[5].role)
        assert.equals("user", messages[6].role)
        assert.equals("Question 3", messages[6].content) -- Preserved (recent)
        assert.equals("assistant", messages[7].role)
        assert.equals("Answer 3", messages[7].content)
        assert.equals("user", messages[8].role)
        assert.equals("Question 4", messages[8].content) -- Current question
    end)
end)

describe("_build_messages: summary usage", function()
    it("when exchange has summary, uses summary instead of full answer", function()
        local ex = exchange("What is Lua?", "Lua is a scripting language designed for embedded use in applications.", "Summary: Lua is a scripting language.")
        ex.question.line_start = 10
        ex.answer.line_start = 12

        local pc = parsed_chat({ ex, exchange("Next question") })
        pc.exchanges[2].question.line_start = 14

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 2,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- Should use summary for first answer since it's not fully preserved
        -- Exchange 1 is old (beyond max_full_exchanges=2 from idx=2), but it's the only one before current
        -- Actually with 2 exchanges and exchange_idx=2, exchange 1 should be within range
        -- Let me adjust: with max_full_exchanges=2 and total=2, all are preserved
        -- But if exchange has file references, answer is summarized
        -- Let me create a clearer test

        -- Add a third exchange to push the first one out
        table.insert(pc.exchanges, 2, exchange("Middle question", "Middle answer"))
        pc.exchanges[2].question.line_start = 13
        pc.exchanges[2].answer.line_start = 14
        pc.exchanges[3].question.line_start = 15

        messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 3,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- With 3 exchanges and max_full_exchanges=2, exchanges 2 and 3 are preserved
        -- Exchange 1 should be summarized (not preserved)
        -- Since ex1 has summary, it should use the summary
        assert.equals(6, #messages) -- system + Q1(placeholder) + A1(summary) + Q2 + A2 + Q3
        assert.equals("system", messages[1].role)
        assert.equals("[Previous messages omitted]", messages[2].content)
        assert.equals("Summary: Lua is a scripting language.", messages[3].content)
    end)
end)

describe("_build_messages: file references", function()
    it("file reference injects system message with file content before user message", function()
        local file_refs = {{ path = "/path/to/file.lua", line = "@@/path/to/file.lua@@", original_line_index = 1 }}
        local ex = exchange("Explain this code", nil, nil, file_refs)
        ex.question.line_start = 10

        local pc = parsed_chat({ ex })

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        assert.equals(3, #messages) -- system prompt, file content (system), user question
        assert.equals("system", messages[1].role)
        assert.is_true(#messages[1].content > 0) -- Has system prompt
        assert.equals("system", messages[2].role)
        -- Note: file_content gets "\n" appended in the code
        assert.is_true(messages[2].content:match("^File content: /path/to/file%.lua") ~= nil)
        assert.is_not_nil(messages[2].cache_control)
        assert.equals("ephemeral", messages[2].cache_control.type)
        assert.equals("user", messages[3].role)
        assert.equals("Explain this code", messages[3].content)
    end)

    it("multiple file references accumulate file_content", function()
        local file_refs = {
            { path = "/path/to/file1.lua", line = "@@/path/to/file1.lua@@", original_line_index = 1 },
            { path = "/path/to/file2.lua", line = "@@/path/to/file2.lua@@", original_line_index = 2 }
        }
        local ex = exchange("Compare these files", nil, nil, file_refs)
        ex.question.line_start = 10

        local pc = parsed_chat({ ex })

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        assert.equals(3, #messages)
        assert.equals("system", messages[2].role)
        -- Both files should be in the same system message
        assert.is_true(messages[2].content:find("File content: /path/to/file1.lua") ~= nil)
        assert.is_true(messages[2].content:find("File content: /path/to/file2.lua") ~= nil)
    end)

    it("file reference with directory pattern calls process_directory_pattern", function()
        local custom_helpers = {
            is_directory = function(path) return false end,
            format_file_content = function(path) return "Single file: " .. path end,
            process_directory_pattern = function(path) return "Directory pattern: " .. path end
        }

        local file_refs = {{ path = "/path/**/*.lua", line = "@@/path/**/*.lua@@", original_line_index = 1 }}
        local ex = exchange("Analyze all Lua files", nil, nil, file_refs)
        ex.question.line_start = 10

        local pc = parsed_chat({ ex })

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = parley.config,
            helpers = custom_helpers,
            logger = stub_logger
        })

        assert.equals(3, #messages)
        assert.is_true(messages[2].content:match("^Directory pattern: /path/%*%*/%*%.lua") ~= nil)
    end)
end)

describe("_build_messages: Anthropic cache_control", function()
    it("system prompt gets cache_control for anthropic provider", function()
        local pc = parsed_chat({ exchange("Hello") })

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent("claude", "anthropic", "You are Claude."),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        assert.equals("system", messages[1].role)
        assert.is_not_nil(messages[1].cache_control)
        assert.equals("ephemeral", messages[1].cache_control.type)
    end)

    it("system prompt does NOT get cache_control for openai provider", function()
        local pc = parsed_chat({ exchange("Hello") })

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent("gpt", "openai", "You are GPT."),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        assert.equals("system", messages[1].role)
        assert.is_nil(messages[1].cache_control)
    end)
end)

describe("_build_messages: header config overrides", function()
    it("config_max_full_exchanges header overrides config value", function()
        local pc = parsed_chat({
            exchange("Question 1", "Answer 1"),
            exchange("Question 2", "Answer 2"),
            exchange("Question 3", "Answer 3"),
            exchange("Question 4") -- current
        }, { config_max_full_exchanges = 1 }) -- Override to only preserve 1

        pc.exchanges[1].question.line_start = 10
        pc.exchanges[1].answer.line_start = 12
        pc.exchanges[2].question.line_start = 14
        pc.exchanges[2].answer.line_start = 16
        pc.exchanges[3].question.line_start = 18
        pc.exchanges[3].answer.line_start = 20
        pc.exchanges[4].question.line_start = 22

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 4,
            agent = agent(),
            config = parley.config, -- default max_full_exchanges = 2
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- With max_full_exchanges=1 and total_exchanges=4, exchange_idx=4:
        -- Preserve if idx > (4 - 1) = 3, so only idx=4 is preserved by "recent" rule
        -- But idx=4 is also the current question, so it's always preserved
        -- Exchange 3 (idx=3) is NOT preserved by "recent" rule (3 is not > 3)
        -- So: Q1(placeholder), A1, Q2(placeholder), A2, Q3(placeholder), A3, Q4
        assert.equals(8, #messages) -- system + Q1(placeholder) + A1 + Q2(placeholder) + A2 + Q3(placeholder) + A3 + Q4
        assert.equals("[Previous messages omitted]", messages[2].content)
        assert.equals("[Previous messages omitted]", messages[4].content)
        assert.equals("[Previous messages omitted]", messages[6].content) -- Q3 is also placeholder
    end)
end)

describe("_build_messages: raw request mode", function()
    it("when question contains typed JSON request fence, stores raw_payload", function()
        local json_question = [[
What do you think?

```json {"type": "request"}
{"model": "gpt-4", "messages": [{"role": "user", "content": "custom"}]}
```
]]
        local ex = exchange(json_question)
        ex.question.line_start = 10

        local pc = parsed_chat({ ex })

        local config_with_raw = vim.deepcopy(parley.config)

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = config_with_raw,
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- The raw_payload should be attached to the exchange
        assert.is_not_nil(ex.question.raw_payload)
        assert.equals("table", type(ex.question.raw_payload))
        assert.equals("gpt-4", ex.question.raw_payload.model)
    end)

    it("ignores plain JSON fences without type:request metadata", function()
        local json_question = [[
Here is some JSON:

```json
{"model": "gpt-4", "messages": [{"role": "user", "content": "custom"}]}
```
]]
        local ex = exchange(json_question)
        ex.question.line_start = 10

        local pc = parsed_chat({ ex })

        local config_with_raw = vim.deepcopy(parley.config)

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = config_with_raw,
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- No raw_payload should be set since the fence lacks type:request
        assert.is_nil(ex.question.raw_payload)
    end)

    it("parses typed request fence even when parse_raw_request config is false", function()
        local json_question = [[
What do you think?

```json {"type": "request"}
{"model": "gpt-4", "messages": [{"role": "user", "content": "override"}]}
```
]]
        local ex = exchange(json_question)
        ex.question.line_start = 10

        local pc = parsed_chat({ ex })

        -- Explicitly set parse_raw_request to false
        local config_no_raw = vim.deepcopy(parley.config)
        config_no_raw.raw_mode = { parse_raw_request = false }

        parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = config_no_raw,
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- Typed fence should be detected regardless of parse_raw_request toggle
        assert.is_not_nil(ex.question.raw_payload)
        assert.equals("override", ex.question.raw_payload.messages[1].content)
    end)

    it("stores complete payload structure from typed request fence", function()
        local json_question = [[
Test question

```json {"type": "request"}
{"model": "gpt-4o", "messages": [{"role": "system", "content": "sys"}, {"role": "user", "content": "hello"}], "temperature": 0.5}
```
]]
        local ex = exchange(json_question)
        ex.question.line_start = 10

        local pc = parsed_chat({ ex })

        parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = vim.deepcopy(parley.config),
            helpers = stub_helpers,
            logger = stub_logger
        })

        assert.is_not_nil(ex.question.raw_payload)
        assert.equals("gpt-4o", ex.question.raw_payload.model)
        assert.equals(2, #ex.question.raw_payload.messages)
        assert.equals("system", ex.question.raw_payload.messages[1].role)
        assert.equals("user", ex.question.raw_payload.messages[2].role)
        assert.equals(0.5, ex.question.raw_payload.temperature)
    end)

    it("handles invalid JSON in typed request fence gracefully", function()
        local json_question = [[
Test question

```json {"type": "request"}
{this is not valid json}
```
]]
        local ex = exchange(json_question)
        ex.question.line_start = 10

        local pc = parsed_chat({ ex })

        -- Should not error out
        parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = vim.deepcopy(parley.config),
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- raw_payload should remain nil since JSON was invalid
        assert.is_nil(ex.question.raw_payload)
    end)

    it("ignores response type fences and only matches request type", function()
        local json_question = [[
Test question

```json {"type": "response"}
{"id": "chatcmpl-123", "choices": [{"message": {"content": "hello"}}]}
```
]]
        local ex = exchange(json_question)
        ex.question.line_start = 10

        local pc = parsed_chat({ ex })

        parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = vim.deepcopy(parley.config),
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- Response type fence should not be treated as a request payload
        assert.is_nil(ex.question.raw_payload)
    end)

    it("builds normal messages when question has no typed fence", function()
        local ex = exchange("Just a normal question")
        ex.question.line_start = 10

        local pc = parsed_chat({ ex })

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = vim.deepcopy(parley.config),
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- No raw_payload, normal message building
        assert.is_nil(ex.question.raw_payload)
        assert.equals(2, #messages) -- system + user
        assert.equals("user", messages[2].role)
        assert.is_true(messages[2].content:find("Just a normal question") ~= nil)
    end)
end)

describe("_build_messages: range filtering", function()
    it("only includes exchanges where question.line_start >= start_index", function()
        local pc = parsed_chat({
            exchange("Question 1", "Answer 1"), -- line_start = 5
            exchange("Question 2", "Answer 2"), -- line_start = 15
            exchange("Question 3")              -- line_start = 25, current
        })

        pc.exchanges[1].question.line_start = 5
        pc.exchanges[1].answer.line_start = 7
        pc.exchanges[2].question.line_start = 15
        pc.exchanges[2].answer.line_start = 17
        pc.exchanges[3].question.line_start = 25

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 10, -- Skip first exchange
            end_index = 100,
            exchange_idx = 3,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- Should only have system + Q2 + A2 + Q3
        assert.equals(4, #messages)
        assert.equals("system", messages[1].role)
        assert.equals("Question 2", messages[2].content)
        assert.equals("Answer 2", messages[3].content)
        assert.equals("Question 3", messages[4].content)
    end)

    it("only includes answers where answer.line_start <= end_index", function()
        local pc = parsed_chat({
            exchange("Question 1", "Answer 1"), -- answer at line 12
            exchange("Question 2", "Answer 2"), -- answer at line 22
            exchange("Question 3")              -- current, line 32
        })

        pc.exchanges[1].question.line_start = 10
        pc.exchanges[1].answer.line_start = 12
        pc.exchanges[2].question.line_start = 20
        pc.exchanges[2].answer.line_start = 22
        pc.exchanges[3].question.line_start = 32

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 15, -- Exclude second answer
            exchange_idx = 3,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- Should have system + Q1 + A1 + Q2 (no A2 because line_start=22 > end_index=15) + Q3
        assert.equals(5, #messages)
        assert.equals("Answer 1", messages[3].content)
        assert.equals("Question 2", messages[4].content)
        assert.equals("Question 3", messages[5].content)
    end)
end)

describe("_build_messages: whitespace trimming", function()
    it("trims leading and trailing whitespace from all message content", function()
        local ex = exchange("  Question with spaces  ", "  Answer with spaces  ")
        ex.question.line_start = 10
        ex.answer.line_start = 12

        local pc = parsed_chat({ ex, exchange("Next") })
        pc.exchanges[2].question.line_start = 14

        -- Use custom agent with spaces in system prompt
        local custom_agent = agent("test", "openai", "  Custom prompt  ")
        -- Override the system_prompt via headers.system_prompt
        pc.headers.system_prompt = "  Custom prompt  "

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 2,
            agent = custom_agent,
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- Check that whitespace is trimmed
        assert.equals("Custom prompt", messages[1].content)
        assert.equals("Question with spaces", messages[2].content)
        assert.equals("Answer with spaces", messages[3].content)
    end)
end)

describe("_build_messages: system_prompt+ header appends", function()
    it("appends system_prompt+ to selected/default system prompt", function()
        local pc = parsed_chat({ exchange("Q1") }, {
            role = nil,
            _append = { system_prompt = { "Extra sentence one.", "Extra sentence two." } }
        })

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent("test-agent", "openai", "Base prompt."),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        local selected = parley._state.system_prompt or "default"
        local base_prompt = parley.system_prompts[selected] and parley.system_prompts[selected].system_prompt or "Base prompt."
        local expected = base_prompt
        if expected:sub(-1) ~= "\n" then
            expected = expected .. "\n"
        end
        expected = expected .. "Extra sentence one.\nExtra sentence two.\n"
        assert.equals(expected, messages[1].content)
    end)

    it("uses system_prompt override then appends system_prompt+ values", function()
        local pc = parsed_chat({ exchange("Q1") }, {
            system_prompt = "Header base\\nline",
            _append = { system_prompt = { "Append one", "Append two" } }
        })

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent("test-agent", "openai", "Agent base"),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        assert.equals("Header base\nline\nAppend one\nAppend two\n", messages[1].content)
    end)

    it("supports legacy role and role+ aliases", function()
        local pc = parsed_chat({ exchange("Q1") }, {
            role = "Legacy base",
            _append = { role = { "Legacy append" } }
        })

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent("test-agent", "openai", "Agent base"),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        assert.equals("Legacy base\nLegacy append\n", messages[1].content)
    end)
end)

describe("_build_messages: file references with preserved answer", function()
    it("when exchange has file references, answer is summarized even if should_preserve", function()
        local file_refs = {{ path = "/file.lua", line = "@@/file.lua@@", original_line_index = 1 }}
        local ex = exchange("Explain this", "Long answer content", "Short summary")
        ex.question.file_references = file_refs
        ex.question.line_start = 10
        ex.answer.line_start = 12

        local pc = parsed_chat({ ex, exchange("Next question") })
        pc.exchanges[2].question.line_start = 14

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 2,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger
        })

        -- Exchange 1 should be preserved (recent), but because it has file refs, answer is summarized
        assert.equals(5, #messages) -- system, file content, Q1, A1(summary), Q2
        assert.equals("system", messages[1].role)
        assert.equals("system", messages[2].role) -- file content
        assert.equals("user", messages[3].role)
        assert.equals("Explain this", messages[3].content)
        assert.equals("assistant", messages[4].role)
        assert.equals("Short summary", messages[4].content) -- Uses summary, not full answer
        assert.equals("user", messages[5].role)
    end)
end)

describe("_build_messages: remote file references", function()
    it("uses resolved_remote_content for URL references", function()
        local file_refs = {
            { line = "@@https://docs.google.com/document/d/abc123/edit@@",
              path = "https://docs.google.com/document/d/abc123/edit",
              original_line_index = 2 }
        }
        local pc = parsed_chat({ exchange("Review this doc", nil, nil, file_refs) })

        local resolved = {
            ["https://docs.google.com/document/d/abc123/edit"] = 'File: Google Doc - "Test"\n```markdown\n1: Hello\n```\n\n'
        }

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger,
            resolved_remote_content = resolved,
        })

        -- Should have system (prompt) + system (file content) + user (question)
        assert.equals(3, #messages)
        assert.equals("system", messages[2].role)
        assert.is_true(messages[2].content:match("Google Doc") ~= nil)
        assert.equals("user", messages[3].role)
        assert.equals("Review this doc", messages[3].content)
    end)

    it("uses cached-miss placeholder for unresolved remote URL references", function()
        local file_refs = {
            { line = "@@https://docs.google.com/document/d/abc123/edit@@",
              path = "https://docs.google.com/document/d/abc123/edit",
              original_line_index = 2 }
        }
        local pc = parsed_chat({ exchange("Review this doc", nil, nil, file_refs) })

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger,
        })

        assert.equals(3, #messages)
        assert.equals("system", messages[2].role)
        assert.is_true(messages[2].content:match("Remote URL content is not cached") ~= nil)
    end)
end)

--------------------------------------------------------------------------------
-- M2 Task 2.6: content_blocks → Anthropic content-block message shape
--
-- When an answer carries content_blocks with tool_use or tool_result
-- entries (populated by chat_parser Task 2.5 when 🔧: / 📎: appear in
-- the buffer), build_messages must split it into the sequence of
-- messages Anthropic's API expects: an `assistant` message carries
-- [text, tool_use] content blocks, immediately followed by a `user`
-- message carrying [tool_result] content blocks, continuing that
-- pattern for every round of the tool loop.
--
-- Answers WITHOUT tool blocks continue to emit a single flat-string
-- assistant message (byte-identical to pre-#81 behavior — this is
-- the vanilla chat invariant locked in by dispatcher_spec.lua:190
-- and config_tools_spec.lua's byte-identity checks).
--------------------------------------------------------------------------------

-- Helper: build an exchange whose answer carries content_blocks.
-- The flat answer.content is also populated for backward compat
-- (mirrors what chat_parser produces).
local function ex_with_blocks(question_content, content_blocks, flat_content)
    local ex = {
        question = {
            line_start = 10,
            line_end = 10,
            content = question_content or "Test question",
            file_references = {},
        },
        answer = {
            line_start = 12,
            line_end = 20,
            content = flat_content or "",
            content_blocks = content_blocks,
        },
    }
    return ex
end

describe("_build_messages: content_blocks with tool round-trips", function()
    it("emits a single flat assistant message when content_blocks has only text", function()
        -- Vanilla-chat case: answer has content_blocks = [{text=...}].
        -- build_messages should IGNORE the blocks and emit the same
        -- flat `{role="assistant", content=<string>}` shape as pre-#81.
        local ex = ex_with_blocks(
            "What is Lua?",
            { { type = "text", text = "Lua is a scripting language." } },
            "Lua is a scripting language."
        )
        local pc = parsed_chat({ ex, exchange("Next question") })
        pc.exchanges[2].question.line_start = 14

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 2,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger,
        })

        -- system + Q1 + A1 + Q2 = 4 messages
        assert.equals(4, #messages)
        assert.equals("assistant", messages[3].role)
        -- Flat string, not a content-block list
        assert.equals("string", type(messages[3].content))
        assert.equals("Lua is a scripting language.", messages[3].content)
    end)

    it("emits assistant-with-content-blocks + user-with-tool_result for a single round", function()
        -- Single tool_use → tool_result → final text round.
        -- Expected message sequence for this exchange:
        --   user:      "Q"
        --   assistant: [text "I'll read it", tool_use toolu_1 read_file]
        --   user:      [tool_result toolu_1 "file contents"]
        --   assistant: [text "The file says hi"]
        local blocks = {
            { type = "text", text = "I'll read it" },
            { type = "tool_use", id = "toolu_1", name = "read_file", input = { path = "foo.txt" } },
            { type = "tool_result", id = "toolu_1", content = "hi", is_error = false },
            { type = "text", text = "The file says hi" },
        }
        local ex = ex_with_blocks("Read foo.txt", blocks, "I'll read it\n🔧: read_file id=toolu_1\n...etc...")
        local pc = parsed_chat({ ex, exchange("follow-up") })
        pc.exchanges[2].question.line_start = 50

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 2,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger,
        })

        -- Expected: system, user(Q1), assistant([text, tool_use]),
        --           user([tool_result]), assistant([text]), user(Q2)
        -- That's 6 messages.
        assert.equals(6, #messages)

        assert.equals("system", messages[1].role)
        assert.equals("user", messages[2].role)
        assert.equals("Read foo.txt", messages[2].content)

        -- Assistant message 3 has content-block list: [text, tool_use]
        assert.equals("assistant", messages[3].role)
        assert.equals("table", type(messages[3].content))
        assert.equals(2, #messages[3].content)
        assert.equals("text", messages[3].content[1].type)
        assert.equals("I'll read it", messages[3].content[1].text)
        assert.equals("tool_use", messages[3].content[2].type)
        assert.equals("toolu_1", messages[3].content[2].id)
        assert.equals("read_file", messages[3].content[2].name)
        assert.equals("foo.txt", messages[3].content[2].input.path)

        -- User message 4 carries the tool_result content block
        assert.equals("user", messages[4].role)
        assert.equals("table", type(messages[4].content))
        assert.equals(1, #messages[4].content)
        assert.equals("tool_result", messages[4].content[1].type)
        assert.equals("toolu_1", messages[4].content[1].tool_use_id)
        assert.equals("hi", messages[4].content[1].content)
        assert.equals(false, messages[4].content[1].is_error)

        -- Assistant message 5 has the final text
        assert.equals("assistant", messages[5].role)
        assert.equals("table", type(messages[5].content))
        assert.equals(1, #messages[5].content)
        assert.equals("text", messages[5].content[1].type)
        assert.equals("The file says hi", messages[5].content[1].text)

        -- User message 6 is the next question
        assert.equals("user", messages[6].role)
        assert.equals("follow-up", messages[6].content)
    end)

    it("emits multiple rounds of tool_use → tool_result correctly", function()
        -- Two sequential rounds: read one file, then read another.
        local blocks = {
            { type = "text", text = "Reading two files" },
            { type = "tool_use", id = "toolu_A", name = "read_file", input = { path = "a.txt" } },
            { type = "tool_result", id = "toolu_A", content = "A body", is_error = false },
            { type = "tool_use", id = "toolu_B", name = "read_file", input = { path = "b.txt" } },
            { type = "tool_result", id = "toolu_B", content = "B body", is_error = false },
            { type = "text", text = "Both files read" },
        }
        local ex = ex_with_blocks("Read two files", blocks, "flat")
        local pc = parsed_chat({ ex, exchange("next") })
        pc.exchanges[2].question.line_start = 99

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 2,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger,
        })

        -- Expected sequence:
        --   1 system
        --   2 user "Read two files"
        --   3 assistant [text, tool_use A]
        --   4 user [tool_result A]
        --   5 assistant [tool_use B]
        --   6 user [tool_result B]
        --   7 assistant [text "Both files read"]
        --   8 user "next"
        assert.equals(8, #messages)

        -- Verify role sequence
        local roles = {}
        for _, m in ipairs(messages) do table.insert(roles, m.role) end
        assert.same(
            { "system", "user", "assistant", "user", "assistant", "user", "assistant", "user" },
            roles
        )

        -- Verify tool ids flow correctly
        assert.equals("toolu_A", messages[3].content[2].id)
        assert.equals("toolu_A", messages[4].content[1].tool_use_id)
        assert.equals("toolu_B", messages[5].content[1].id)
        assert.equals("toolu_B", messages[6].content[1].tool_use_id)
    end)

    it("emits is_error=true tool_results correctly", function()
        local blocks = {
            { type = "tool_use", id = "toolu_err", name = "edit_file",
              input = { path = "x", old_string = "a", new_string = "b" } },
            { type = "tool_result", id = "toolu_err", content = "old_string not found", is_error = true },
        }
        local ex = ex_with_blocks("Edit x", blocks, "flat")
        local pc = parsed_chat({ ex, exchange("next") })
        pc.exchanges[2].question.line_start = 50

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 2,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger,
        })

        -- user(Q1), assistant[tool_use], user[tool_result error=true], user(Q2)
        -- Find the tool_result message
        local found = nil
        for _, m in ipairs(messages) do
            if type(m.content) == "table" and m.content[1] and m.content[1].type == "tool_result" then
                found = m.content[1]
                break
            end
        end
        assert.is_not_nil(found)
        assert.equals(true, found.is_error)
        assert.equals("old_string not found", found.content)
    end)

    it("includes the CURRENT exchange's partial answer when it has tool blocks (tool-loop recursion)", function()
        -- During tool loop recursion, the current exchange has a partial
        -- answer with tool blocks already written to the buffer. Those
        -- blocks must be re-sent to Anthropic so the model can continue.
        local blocks = {
            { type = "text", text = "Reading" },
            { type = "tool_use", id = "toolu_R", name = "read_file", input = { path = "x.txt" } },
            { type = "tool_result", id = "toolu_R", content = "x body", is_error = false },
        }
        local ex = ex_with_blocks("Please read x.txt", blocks, "flat")
        local pc = parsed_chat({ ex })

        -- IMPORTANT: exchange_idx = 1 (the current exchange). Pre-#81
        -- build_messages would skip the current exchange's answer. Tool
        -- loop recursion requires including it.
        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger,
        })

        -- system, user, assistant[text, tool_use], user[tool_result] = 4
        assert.equals(4, #messages)
        assert.equals("system", messages[1].role)
        assert.equals("user", messages[2].role)
        assert.equals("Please read x.txt", messages[2].content)
        assert.equals("assistant", messages[3].role)
        assert.equals("table", type(messages[3].content))
        assert.equals("user", messages[4].role)
        assert.equals("table", type(messages[4].content))
        assert.equals("tool_result", messages[4].content[1].type)
        assert.equals("toolu_R", messages[4].content[1].tool_use_id)
    end)

    it("does NOT include the current exchange's answer when it has NO tool blocks (vanilla resubmit)", function()
        -- Regression safeguard: if someone re-submits a vanilla chat at
        -- the current exchange, we should not echo the previously-
        -- generated answer back. Only exchanges with tool blocks in
        -- content_blocks get the current-exchange inclusion.
        local ex = exchange("Q", "A")
        ex.question.line_start = 10
        ex.answer.line_start = 12
        local pc = parsed_chat({ ex })

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger,
        })

        -- Only system + user. The answer "A" is NOT included because
        -- this is the current exchange without tool blocks.
        assert.equals(2, #messages)
        assert.equals("system", messages[1].role)
        assert.equals("user", messages[2].role)
        assert.equals("Q", messages[2].content)
    end)
end)
