-- Unit tests for D._extract_sse_content in lua/parley/dispatcher.lua
--
-- _extract_sse_content(line, provider) is a pure function that takes a raw SSE line
-- and a provider name, and returns extracted text content (or "").
--
-- No setup() needed, no process state, no network — just pure string transformation.

local dispatcher = require("parley.dispatcher")

describe("_extract_sse_content: line preprocessing", function()
    it("strips 'data: ' prefix before extraction", function()
        local line = 'data: {"choices":[{"delta":{"content":"hi"}}]}'
        local result = dispatcher._extract_sse_content(line, "openai")
        assert.equals("hi", result)
    end)

    it("handles line without 'data: ' prefix", function()
        local line = '{"choices":[{"delta":{"content":"world"}}]}'
        local result = dispatcher._extract_sse_content(line, "openai")
        assert.equals("world", result)
    end)

    it("returns empty string for empty line", function()
        local result = dispatcher._extract_sse_content("", "openai")
        assert.equals("", result)
    end)

    it("returns empty string for [DONE] marker", function()
        local result = dispatcher._extract_sse_content("[DONE]", "openai")
        assert.equals("", result)
    end)

    it("returns empty string for [DONE] with data: prefix", function()
        local result = dispatcher._extract_sse_content("data: [DONE]", "openai")
        assert.equals("", result)
    end)
end)

describe("_extract_sse_content: malformed input", function()
    it("returns empty string for malformed JSON", function()
        local result = dispatcher._extract_sse_content("{not valid json", "openai")
        assert.equals("", result)
    end)

    it("returns empty string for non-JSON text", function()
        local result = dispatcher._extract_sse_content("random text here", "openai")
        assert.equals("", result)
    end)

    it("returns empty string for incomplete JSON object", function()
        local result = dispatcher._extract_sse_content('{"choices":[{"delta":', "openai")
        assert.equals("", result)
    end)
end)

describe("_extract_sse_content: OpenAI format", function()
    it("extracts content from standard delta chunk", function()
        local line = '{"choices":[{"delta":{"content":"Hello"}}]}'
        local result = dispatcher._extract_sse_content(line, "openai")
        assert.equals("Hello", result)
    end)

    it("extracts content from delta with role field", function()
        local line = '{"choices":[{"delta":{"role":"assistant","content":"Hi"}}]}'
        local result = dispatcher._extract_sse_content(line, "openai")
        assert.equals("Hi", result)
    end)

    it("returns empty string when delta.content is null", function()
        local line = '{"choices":[{"delta":{"content":null}}]}'
        local result = dispatcher._extract_sse_content(line, "openai")
        assert.equals("", result)
    end)

    it("returns empty string when delta.content is missing", function()
        local line = '{"choices":[{"delta":{}}]}'
        local result = dispatcher._extract_sse_content(line, "openai")
        assert.equals("", result)
    end)

    it("returns empty string for empty choices array", function()
        local line = '{"choices":[]}'
        local result = dispatcher._extract_sse_content(line, "openai")
        assert.equals("", result)
    end)

    it("returns empty string for usage-only chunk (no delta content)", function()
        local line = '{"choices":[],"usage":{"prompt_tokens":11,"completion_tokens":4}}'
        local result = dispatcher._extract_sse_content(line, "openai")
        assert.equals("", result)
    end)

    it("extracts multi-word content", function()
        local line = '{"choices":[{"delta":{"content":"Hello, world!"}}]}'
        local result = dispatcher._extract_sse_content(line, "openai")
        assert.equals("Hello, world!", result)
    end)

    it("handles content with special characters", function()
        local line = '{"choices":[{"delta":{"content":"Line\\nbreak"}}]}'
        local result = dispatcher._extract_sse_content(line, "openai")
        assert.is_truthy(result:match("Line"))
    end)
end)

describe("_extract_sse_content: Anthropic format", function()
    it("extracts text from content_block_start with content_block.text", function()
        local line = '{"type":"content_block_start","content_block":{"text":"Hello"}}'
        local result = dispatcher._extract_sse_content(line, "anthropic")
        assert.equals("Hello", result)
    end)

    it("extracts text from content_block_delta with delta.text", function()
        local line = '{"type":"content_block_delta","delta":{"text":" world"}}'
        local result = dispatcher._extract_sse_content(line, "anthropic")
        assert.equals(" world", result)
    end)

    it("returns empty string for Anthropic line without 'text' key", function()
        local line = '{"type":"message_start","message":{"id":"msg_123"}}'
        local result = dispatcher._extract_sse_content(line, "anthropic")
        assert.equals("", result)
    end)

    it("returns empty string for Anthropic line without content_block markers", function()
        local line = '{"type":"ping"}'
        local result = dispatcher._extract_sse_content(line, "anthropic")
        assert.equals("", result)
    end)

    it("does NOT extract from Anthropic format when provider is openai", function()
        -- Anthropic-shaped line, but provider=openai should NOT trigger Anthropic parser
        local line = '{"type":"content_block_delta","delta":{"text":"test"}}'
        local result = dispatcher._extract_sse_content(line, "openai")
        assert.equals("", result)
    end)
end)

describe("_extract_sse_content: Google AI format", function()
    it("extracts text from line with 'text' key", function()
        local line = '"text": "Hello from Gemini"'
        local result = dispatcher._extract_sse_content(line, "googleai")
        assert.equals("Hello from Gemini", result)
    end)

    it("returns empty string for Google AI line without 'text' key", function()
        local line = '"finishReason": "STOP"'
        local result = dispatcher._extract_sse_content(line, "googleai")
        assert.equals("", result)
    end)

    it("does NOT extract from Google AI format when provider is openai", function()
        local line = '"text": "test"'
        local result = dispatcher._extract_sse_content(line, "openai")
        assert.equals("", result)
    end)

    it("does NOT extract from Google AI format when provider is anthropic", function()
        local line = '"text": "test"'
        local result = dispatcher._extract_sse_content(line, "anthropic")
        assert.equals("", result)
    end)
end)

describe("_extract_sse_content: provider isolation", function()
    it("OpenAI line does NOT trigger Anthropic extraction", function()
        local line = '{"choices":[{"delta":{"content":"OpenAI text"}}]}'
        local result = dispatcher._extract_sse_content(line, "anthropic")
        assert.equals("", result)
    end)

    it("Anthropic line does NOT trigger Google AI extraction", function()
        local line = '{"type":"content_block_delta","delta":{"text":"Anthropic text"}}'
        local result = dispatcher._extract_sse_content(line, "googleai")
        assert.equals("", result)
    end)
end)

describe("_extract_sse_progress_event", function()
    it("returns anthropic tool progress event for web_search tool_use start", function()
        local line = 'data: {"type":"content_block_start","content_block":{"type":"tool_use","name":"web_search"}}'
        local event = dispatcher._extract_sse_progress_event(line, "anthropic")
        assert.is_not_nil(event)
        assert.equals("content_block_start", event.type)
        assert.equals("tool_use", event.block_type)
        assert.equals("web_search", event.tool)
        assert.equals("Searching web...", event.message)
    end)

    it("returns anthropic progress event for server_tool_use web_search start", function()
        local line = 'data: {"type":"content_block_start","content_block":{"type":"server_tool_use","name":"web_search"}}'
        local event = dispatcher._extract_sse_progress_event(line, "anthropic")
        assert.is_not_nil(event)
        assert.equals("content_block_start", event.type)
        assert.equals("server_tool_use", event.block_type)
        assert.equals("web_search", event.tool)
        assert.equals("Searching web...", event.message)
    end)

    it("returns anthropic progress event for web_search_tool_result start", function()
        local line = 'data: {"type":"content_block_start","content_block":{"type":"web_search_tool_result"}}'
        local event = dispatcher._extract_sse_progress_event(line, "anthropic")
        assert.is_not_nil(event)
        assert.equals("content_block_start", event.type)
        assert.equals("web_search_tool_result", event.block_type)
        assert.equals("Search results received...", event.message)
    end)

    it("returns nil for anthropic text delta line", function()
        local line = 'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"hello"}}'
        local event = dispatcher._extract_sse_progress_event(line, "anthropic")
        assert.is_nil(event)
    end)

    it("returns nil for openai content chunk", function()
        local line = 'data: {"choices":[{"delta":{"content":"Hello"}}]}'
        local event = dispatcher._extract_sse_progress_event(line, "openai")
        assert.is_nil(event)
    end)

    it("returns openai reasoning progress event for reasoning_content delta", function()
        local line = 'data: {"choices":[{"delta":{"reasoning_content":"Thinking..."}}]}'
        local event = dispatcher._extract_sse_progress_event(line, "openai")
        assert.is_not_nil(event)
        assert.equals("reasoning_delta", event.type)
        assert.equals("reasoning_content", event.block_type)
        assert.equals("reasoning", event.kind)
        assert.equals("reasoning", event.phase)
        assert.equals("Reasoning...", event.message)
        assert.equals("Thinking...", event.text)
    end)

    it("returns openai progress event for chat-completions tool_calls delta", function()
        local line = 'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"web_search","arguments":"{"}}]}}]}'
        local event = dispatcher._extract_sse_progress_event(line, "openai")
        assert.is_not_nil(event)
        assert.equals("tool_call_delta", event.type)
        assert.equals("tool_calls_delta", event.block_type)
        assert.equals("web_search", event.tool)
        assert.equals("tool_update", event.kind)
        assert.equals("tooling", event.phase)
        assert.equals("Searching web...", event.message)
        assert.equals("{", event.text)
    end)

    it("returns openai progress event for responses output_item web_search_call added", function()
        local line = 'data: {"type":"response.output_item.added","item":{"type":"web_search_call","id":"ws_1","query":"latest ai news"}}'
        local event = dispatcher._extract_sse_progress_event(line, "openai")
        assert.is_not_nil(event)
        assert.equals("response.output_item.added", event.type)
        assert.equals("web_search_call", event.block_type)
        assert.equals("web_search", event.tool)
        assert.equals("Searching web...", event.message)
        assert.equals("latest ai news", event.text)
    end)

    it("returns openai progress event for responses output_item web_search_call done", function()
        local line = 'data: {"type":"response.output_item.done","item":{"type":"web_search_call","id":"ws_1","status":"completed"}}'
        local event = dispatcher._extract_sse_progress_event(line, "openai")
        assert.is_not_nil(event)
        assert.equals("response.output_item.done", event.type)
        assert.equals("web_search_call", event.block_type)
        assert.equals("web_search", event.tool)
        assert.equals("Search results received...", event.message)
    end)

    it("returns anthropic tool progress event with input query text", function()
        local line = 'data: {"type":"content_block_start","content_block":{"type":"tool_use","name":"web_search","input":{"query":"lua nvim events"}}}'
        local event = dispatcher._extract_sse_progress_event(line, "anthropic")
        assert.is_not_nil(event)
        assert.equals("tool_start", event.kind)
        assert.equals("Searching web...", event.message)
        assert.equals("lua nvim events", event.text)
    end)

    it("returns anthropic tool input_json_delta progress text", function()
        local line = 'data: {"type":"content_block_delta","delta":{"type":"input_json_delta","partial_json":"{\\"query\\":\\"lua"}}'
        local event = dispatcher._extract_sse_progress_event(line, "anthropic")
        assert.is_not_nil(event)
        assert.equals("tool_update", event.kind)
        assert.equals("Running tool...", event.message)
        assert.equals('{"query":"lua', event.text)
    end)

    it("returns googleai progress event for grounding webSearchQueries fragment", function()
        local line = 'data: "webSearchQueries": ["latest gemini release notes"]'
        local event = dispatcher._extract_sse_progress_event(line, "googleai")
        assert.is_not_nil(event)
        assert.equals("grounding_metadata", event.type)
        assert.equals("web_search_queries", event.block_type)
        assert.equals("web_search", event.tool)
        assert.equals("tool_update", event.kind)
        assert.equals("tooling", event.phase)
        assert.equals("Searching web...", event.message)
        assert.equals("latest gemini release notes", event.text)
    end)

    it("returns googleai progress event for escaped grounding uri fragment", function()
        local line = 'data: \\"uri\\": \\"https://example.com/article\\"'
        local event = dispatcher._extract_sse_progress_event(line, "googleai")
        assert.is_not_nil(event)
        assert.equals("grounding_metadata", event.type)
        assert.equals("grounding_uri", event.block_type)
        assert.equals("web_search", event.tool)
        assert.equals("tool_update", event.kind)
        assert.equals("tooling", event.phase)
        assert.equals("Search results received...", event.message)
        assert.equals("https://example.com/article", event.text)
    end)

    it("returns nil for googleai escaped full payload blob without explicit fragments", function()
        local line = 'data: "[{\\"candidates\\":[{\\"content\\":{\\"parts\\":[{\\"text\\":\\"hello\\"}]}}]}]"'
        local event = dispatcher._extract_sse_progress_event(line, "googleai")
        assert.is_nil(event)
    end)
end)

describe("_extract_sse_content: fixture-based smoke tests", function()
    it("processes openai_stream.txt fixture without error", function()
        local fixture_path = "tests/fixtures/openai_stream.txt"
        local exists = vim.fn.filereadable(fixture_path) == 1
        assert.is_true(exists, "openai_stream.txt fixture should exist at " .. fixture_path)

        local lines = vim.fn.readfile(fixture_path)
        local accumulated = ""
        for _, line in ipairs(lines) do
            local content = dispatcher._extract_sse_content(line, "openai")
            accumulated = accumulated .. content
        end
        -- The fixture should produce greeting text based on streamed deltas.
        assert.is_truthy(#accumulated > 0, "openai fixture should extract non-empty content")
        assert.is_truthy(accumulated:lower():match("hello"), "openai fixture should contain 'hello'")
    end)

    it("processes anthropic_stream.txt fixture without error", function()
        local fixture_path = "tests/fixtures/anthropic_stream.txt"
        local exists = vim.fn.filereadable(fixture_path) == 1
        assert.is_true(exists, "anthropic_stream.txt fixture should exist")

        local lines = vim.fn.readfile(fixture_path)
        -- Even if it's an error response, _extract_sse_content should not crash
        for _, line in ipairs(lines) do
            local ok = pcall(dispatcher._extract_sse_content, line, "anthropic")
            assert.is_true(ok, "Anthropic fixture parsing should not crash on line: " .. line)
        end
    end)

    it("processes googleai_stream.txt fixture without error", function()
        local fixture_path = "tests/fixtures/googleai_stream.txt"
        local exists = vim.fn.filereadable(fixture_path) == 1
        assert.is_true(exists, "googleai_stream.txt fixture should exist")

        local lines = vim.fn.readfile(fixture_path)
        -- Even if it's an error response, _extract_sse_content should not crash
        for _, line in ipairs(lines) do
            local ok = pcall(dispatcher._extract_sse_content, line, "googleai")
            assert.is_true(ok, "Google AI fixture parsing should not crash on line: " .. line)
        end
    end)

    it("processes anthropic_error.txt fixture without error", function()
        local fixture_path = "tests/fixtures/anthropic_error.txt"
        local exists = vim.fn.filereadable(fixture_path) == 1
        assert.is_true(exists, "anthropic_error.txt fixture should exist")

        local lines = vim.fn.readfile(fixture_path)
        for _, line in ipairs(lines) do
            local ok, result = pcall(dispatcher._extract_sse_content, line, "anthropic")
            assert.is_true(ok, "Error fixture parsing should not crash")
            -- Error responses should return empty content
            assert.equals("", result)
        end
    end)
end)
