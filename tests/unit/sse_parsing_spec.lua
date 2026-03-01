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
        -- The fixture should produce "Hello, world!" based on the deltas
        assert.is_truthy(#accumulated > 0, "openai fixture should extract non-empty content")
        assert.is_truthy(accumulated:match("Hello"), "openai fixture should contain 'Hello'")
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
