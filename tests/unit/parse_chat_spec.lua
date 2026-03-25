-- Unit tests for chat_parser.parse_chat in lua/parley/chat_parser.lua
--
-- parse_chat(lines, header_end, config) is a pure function: no Neovim APIs,
-- no setup() required. We pass a minimal config stub directly.

local chat_parser = require("parley.chat_parser")

-- Minimal config stub — covers every field that parse_chat reads from config.
local test_config = {
    chat_user_prefix      = "💬:",
    chat_local_prefix     = "🔒:",
    chat_assistant_prefix = { "🤖:", "[{{agent}}]" },
    chat_memory = {
        enable            = true,
        summary_prefix    = "📝:",
        reasoning_prefix  = "🧠:",
    },
}

-- Shortcut: call parse_chat with the shared test_config.
local function parse_chat(lines, header_end)
    return chat_parser.parse_chat(lines, header_end, test_config)
end

-- Convenience: build a minimal valid chat header block ending at the --- line.
-- Returns lines table and header_end index.
local function make_chat(header_lines, body_lines)
    local lines = {}
    for _, l in ipairs(header_lines) do
        table.insert(lines, l)
    end
    table.insert(lines, "---")
    local header_end = #lines
    table.insert(lines, "")  -- blank line after separator
    for _, l in ipairs(body_lines) do
        table.insert(lines, l)
    end
    return lines, header_end
end

-- Standard header used in most tests.
local std_header = {
    "# topic: Test Topic",
    "- file: 2026-02-28.test.md",
    "- model: claude-haiku",
    "- provider: anthropic",
}

describe("parse_chat: headers", function()
    it("parses topic from header", function()
        local lines, header_end = make_chat(std_header, {})
        local result = parse_chat(lines, header_end)
        assert.equals("Test Topic", result.headers["topic"])
    end)

    it("parses file from header", function()
        local lines, header_end = make_chat(std_header, {})
        local result = parse_chat(lines, header_end)
        assert.equals("2026-02-28.test.md", result.headers["file"])
    end)

    it("parses provider from header", function()
        local lines, header_end = make_chat(std_header, {})
        local result = parse_chat(lines, header_end)
        assert.equals("anthropic", result.headers["provider"])
    end)

    it("parses tags header as an array", function()
        local header = {
            "# topic: Tagged",
            "- file: foo.md",
            "- tags: lua neovim test",
        }
        local lines, header_end = make_chat(header, {})
        local result = parse_chat(lines, header_end)
        assert.is_table(result.headers["tags"])
        assert.equals(3, #result.headers["tags"])
        assert.equals("lua", result.headers["tags"][1])
        assert.equals("neovim", result.headers["tags"][2])
        assert.equals("test", result.headers["tags"][3])
    end)

    it("returns empty exchanges for header-only chat", function()
        local lines, header_end = make_chat(std_header, {})
        local result = parse_chat(lines, header_end)
        assert.equals(0, #result.exchanges)
    end)

    it("parses front matter style headers", function()
        local lines = {
            "---",
            "topic: Front Matter Topic",
            "file: 2026-02-28.frontmatter.md",
            "provider: openai",
            "tags: lua, neovim",
            "---",
            "",
            "💬: Hello",
        }
        local header_end = chat_parser.find_header_end(lines)
        local result = parse_chat(lines, header_end)
        assert.equals("Front Matter Topic", result.headers["topic"])
        assert.equals("2026-02-28.frontmatter.md", result.headers["file"])
        assert.equals("openai", result.headers["provider"])
        assert.equals("lua", result.headers["tags"][1])
        assert.equals("neovim", result.headers["tags"][2])
    end)

    it("captures repeated system_prompt+ values in order", function()
        local lines = {
            "---",
            "topic: Append Topic",
            "system_prompt+: First addition",
            "system_prompt+: Second addition",
            "max_full_exchanges+: 2",
            "max_full_exchanges+: 4",
            "---",
            "",
            "💬: Hello",
        }
        local header_end = chat_parser.find_header_end(lines)
        local result = parse_chat(lines, header_end)

        assert.is_table(result.headers._append)
        assert.equals("First addition", result.headers._append.system_prompt[1])
        assert.equals("Second addition", result.headers._append.system_prompt[2])
        assert.equals(2, result.headers._append.config_max_full_exchanges[1])
        assert.equals(4, result.headers._append.config_max_full_exchanges[2])
    end)

    it("keeps system_prompt override and system_prompt+ additions separately", function()
        local lines = {
            "---",
            "system_prompt: Base prompt",
            "system_prompt+: Added prompt",
            "---",
            "",
            "💬: Hello",
        }
        local header_end = chat_parser.find_header_end(lines)
        local result = parse_chat(lines, header_end)

        assert.equals("Base prompt", result.headers.system_prompt)
        assert.equals("Added prompt", result.headers._append.system_prompt[1])
    end)

    it("maps legacy role/role+ headers to system_prompt keys", function()
        local lines = {
            "---",
            "role: Legacy base",
            "role+: Legacy append",
            "---",
            "",
            "💬: Hello",
        }
        local header_end = chat_parser.find_header_end(lines)
        local result = parse_chat(lines, header_end)

        assert.equals("Legacy base", result.headers.system_prompt)
        assert.equals("Legacy append", result.headers._append.system_prompt[1])
        assert.is_nil(result.headers.role)
        assert.is_nil(result.headers._append.role)
    end)
end)

describe("parse_chat: single exchange", function()
    it("parses a question with no answer", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Hello world",
        })
        local result = parse_chat(lines, header_end)
        assert.equals(1, #result.exchanges)
        assert.equals("Hello world", result.exchanges[1].question.content)
        assert.is_nil(result.exchanges[1].answer)
    end)

    it("parses multi-line question content", function()
        local lines, header_end = make_chat(std_header, {
            "💬: First line",
            "second line",
            "third line",
        })
        local result = parse_chat(lines, header_end)
        assert.equals(1, #result.exchanges)
        -- content is trimmed; lines joined by \n
        local content = result.exchanges[1].question.content
        assert.is_truthy(content:match("First line"))
        assert.is_truthy(content:match("second line"))
        assert.is_truthy(content:match("third line"))
    end)

    it("parses a question + answer exchange", function()
        local lines, header_end = make_chat(std_header, {
            "💬: What is 2+2?",
            "🤖:[Claude] It is 4.",
            "The answer is four.",
        })
        local result = parse_chat(lines, header_end)
        assert.equals(1, #result.exchanges)
        assert.equals("What is 2+2?", result.exchanges[1].question.content)
        assert.is_not_nil(result.exchanges[1].answer)
        -- The 🤖: prefix line text is NOT captured; only continuation lines are.
        -- "The answer is four." is the first continuation line.
        assert.is_truthy(result.exchanges[1].answer.content:match("The answer is four"))
    end)

    it("records correct line_start for question (1-indexed)", function()
        local lines, header_end = make_chat(std_header, {
            "",           -- blank after ---
            "💬: Hello",
        })
        local result = parse_chat(lines, header_end)
        -- question line_start should point to the 💬: line
        local q_line = result.exchanges[1].question.line_start
        assert.is_truthy(q_line > header_end)
    end)
end)

describe("parse_chat: multiple exchanges", function()
    it("parses two exchanges in order", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Question one",
            "🤖:[Claude] ",
            "Answer one body",
            "💬: Question two",
            "🤖:[Claude] ",
            "Answer two body",
        })
        local result = parse_chat(lines, header_end)
        assert.equals(2, #result.exchanges)
        assert.equals("Question one", result.exchanges[1].question.content)
        -- answer content = continuation lines only (not the 🤖: prefix line)
        assert.is_truthy(result.exchanges[1].answer.content:match("Answer one body"))
        assert.equals("Question two", result.exchanges[2].question.content)
        assert.is_truthy(result.exchanges[2].answer.content:match("Answer two body"))
    end)

    it("parses three exchanges", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Q1",
            "🤖:[A] R1",
            "💬: Q2",
            "🤖:[A] R2",
            "💬: Q3",
        })
        local result = parse_chat(lines, header_end)
        assert.equals(3, #result.exchanges)
        assert.is_nil(result.exchanges[3].answer)
    end)
end)

describe("parse_chat: summary and reasoning lines", function()
    it("extracts 📝: summary from answer block", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Tell me something",
            "🤖:[Claude] Here is my answer.",
            "📝: you asked about something, I answered with facts",
        })
        local result = parse_chat(lines, header_end)
        assert.is_not_nil(result.exchanges[1].summary)
        assert.equals(
            "you asked about something, I answered with facts",
            result.exchanges[1].summary.content
        )
    end)

    it("extracts 🧠: reasoning from answer block", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Why is sky blue?",
            "🤖:[Claude] Due to Rayleigh scattering.",
            "🧠: the user wants a physics explanation",
        })
        local result = parse_chat(lines, header_end)
        assert.is_not_nil(result.exchanges[1].reasoning)
        assert.equals(
            "the user wants a physics explanation",
            result.exchanges[1].reasoning.content
        )
    end)

    it("does not attach 📝: to question block", function()
        -- summary prefix at question level should just be content, not a summary field
        local lines, header_end = make_chat(std_header, {
            "💬: Question",
            "📝: this is not a summary",
        })
        local result = parse_chat(lines, header_end)
        -- no answer means no summary field should be set on exchange
        assert.is_nil(result.exchanges[1].summary)
    end)
end)

describe("parse_chat: 🔒: local prefix", function()
    it("excludes content after local_prefix from question content", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Visible question",
            "more visible content",
            "🔒: This is local and should be excluded",
            "also excluded",
        })
        local result = parse_chat(lines, header_end)
        local content = result.exchanges[1].question.content
        assert.is_truthy(content:match("Visible question"))
        assert.is_truthy(content:match("more visible content"))
        -- local content should not appear in question content
        assert.is_falsy(content:match("excluded"))
    end)

    it("local prefix resets at next 💬: block", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Q1",
            "🔒: local stuff",
            "💬: Q2 visible",
        })
        local result = parse_chat(lines, header_end)
        assert.equals(2, #result.exchanges)
        assert.equals("Q2 visible", result.exchanges[2].question.content)
    end)
end)

describe("parse_chat: @@ file references", function()
    it("collects @@ref@@ file reference on its own line", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Check this file",
            "@@/path/to/file.lua@@",
        })
        local result = parse_chat(lines, header_end)
        local refs = result.exchanges[1].question.file_references
        assert.equals(1, #refs)
        assert.equals("/path/to/file.lua", refs[1].path)
    end)

    it("collects multiple @@ref@@ references in same question", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Review these",
            "@@/a.lua@@",
            "@@/b.lua@@",
        })
        local result = parse_chat(lines, header_end)
        local refs = result.exchanges[1].question.file_references
        assert.equals(2, #refs)
    end)

    it("collects inline @@ref@@ with local path", function()
        local lines, header_end = make_chat(std_header, {
            "💬: See @@/inline/path.lua@@ here",
        })
        local result = parse_chat(lines, header_end)
        local refs = result.exchanges[1].question.file_references
        assert.equals(1, #refs)
        assert.equals("/inline/path.lua", refs[1].path)
    end)

    it("collects @@url@@ URL reference with full URL including colons", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Review this doc",
            "@@https://docs.google.com/document/d/abc123/edit@@",
        })
        local result = parse_chat(lines, header_end)
        local refs = result.exchanges[1].question.file_references
        assert.equals(1, #refs)
        assert.equals("https://docs.google.com/document/d/abc123/edit", refs[1].path)
    end)

    it("does not collect references from answer blocks", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Question",
            "🤖:[Claude] See @@/some/file.lua@@",
        })
        local result = parse_chat(lines, header_end)
        -- answer block has no file_references field
        assert.is_nil(result.exchanges[1].answer.file_references)
    end)

    it("collects inline @@url@@ on the same line as user prefix", function()
        local lines, header_end = make_chat(std_header, {
            "💬: tell me about this page @@https://docs.google.com/document/d/abc123/edit@@",
        })
        local result = parse_chat(lines, header_end)
        local refs = result.exchanges[1].question.file_references
        assert.equals(1, #refs)
        assert.equals("https://docs.google.com/document/d/abc123/edit", refs[1].path)
    end)

    it("collects inline @@url@@ on a continuation line", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Check these docs",
            "first see @@https://docs.google.com/document/d/abc123/edit@@ then respond",
        })
        local result = parse_chat(lines, header_end)
        local refs = result.exchanges[1].question.file_references
        assert.equals(1, #refs)
        assert.equals("https://docs.google.com/document/d/abc123/edit", refs[1].path)
    end)

    it("collects inline @@ref@@ with local path on continuation line", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Check this code",
            "see @@/inline/path.lua@@ for context",
        })
        local result = parse_chat(lines, header_end)
        local refs = result.exchanges[1].question.file_references
        assert.equals(1, #refs)
        assert.equals("/inline/path.lua", refs[1].path)
    end)

    it("collects inline @@ref@@ with relative path", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Review @@./src/main.lua@@ please",
        })
        local result = parse_chat(lines, header_end)
        local refs = result.exchanges[1].question.file_references
        assert.equals(1, #refs)
        assert.equals("./src/main.lua", refs[1].path)
    end)

    it("collects inline @@ref@@ with home-relative path", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Check @@~/config.lua@@",
        })
        local result = parse_chat(lines, header_end)
        local refs = result.exchanges[1].question.file_references
        assert.equals(1, #refs)
        assert.equals("~/config.lua", refs[1].path)
    end)

    it("does not collect unclosed @@ reference (no closing @@)", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Review @@/path/to/file.lua please",
        })
        local result = parse_chat(lines, header_end)
        local refs = result.exchanges[1].question.file_references
        assert.equals(0, #refs)
    end)

    it("collects two inline @@ref@@ on same line", function()
        local lines, header_end = make_chat(std_header, {
            "💬: Compare @@/file/a.lua@@ and @@/file/b.lua@@",
        })
        local result = parse_chat(lines, header_end)
        local refs = result.exchanges[1].question.file_references
        assert.equals(2, #refs)
    end)
end)


describe("parse_chat: edge cases", function()
    it("handles assistant message with no preceding user message", function()
        local lines, header_end = make_chat(std_header, {
            "🤖:[Claude] Unprompted response",
        })
        -- Should not crash; an exchange is created with empty question
        local ok, result = pcall(chat_parser.parse_chat, lines, header_end, test_config)
        assert.is_true(ok)
        assert.is_not_nil(result)
    end)

    it("returns empty exchanges when body has only blank lines", function()
        local lines, header_end = make_chat(std_header, {
            "",
            "",
            "",
        })
        local result = parse_chat(lines, header_end)
        assert.equals(0, #result.exchanges)
    end)
end)
