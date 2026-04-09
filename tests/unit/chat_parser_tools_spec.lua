-- Unit tests for chat_parser.lua recognition of `🔧:` (tool_use) and
-- `📎:` (tool_result) components inside a `🤖:` assistant answer.
--
-- M2 Task 2.5 of issue #81. The parser walks the chat buffer line
-- by line (see chat_parser.lua:261). Before this task, an answer
-- had a single flat `content` string. After this task, an answer
-- ALSO has a `content_blocks` list preserving the buffer order of
-- interleaved text / tool_use / tool_result components.
--
-- Backward compatibility invariant: `answer.content` still holds
-- the full concatenated text of the answer region (same behavior
-- as before this task). Existing callers that only read .content
-- are unaffected.
--
-- The parser delegates tool block body parsing to
-- lua/parley/tools/serialize.lua (landed in Task 2.1), so changes
-- to the 🔧:/📎: serialization schema automatically propagate into
-- the parser without re-writing any regex here.

local parser = require("parley.chat_parser")
local serialize = require("parley.tools.serialize")

-- Minimal config table the parser needs. Pulled from config.lua
-- defaults but inlined so this test doesn't depend on parley.setup().
local function test_config()
    return {
        chat_user_prefix = "💬:",
        chat_local_prefix = "🔒:",
        chat_branch_prefix = "🌿:",
        chat_assistant_prefix = { "🤖:", "[{{agent}}]" },
        chat_tool_use_prefix = "🔧:",
        chat_tool_result_prefix = "📎:",
        chat_memory = { enable = false },
    }
end

-- Helper to build a chat buffer: skips the YAML front matter by
-- returning (lines, header_end=0).
local function buf(line_list)
    return line_list, 0
end

-- Finds the first exchange's answer block list. Returns nil if
-- the exchange or answer is missing.
local function first_answer_blocks(parsed)
    local ex = parsed.exchanges[1]
    if not ex or not ex.answer then return nil end
    return ex.answer.content_blocks
end

--------------------------------------------------------------------------------
-- Shape
--------------------------------------------------------------------------------

describe("chat_parser content_blocks shape", function()
    it("answer without tool blocks gets a single-text content_blocks list", function()
        local lines, header_end = buf({
            "💬: hello",
            "🤖: [Claude]",
            "hi there",
            "second line",
        })
        local parsed = parser.parse_chat(lines, header_end, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.is_table(blocks)
        assert.equals(1, #blocks)
        assert.equals("text", blocks[1].type)
        assert.matches("hi there", blocks[1].text)
        assert.matches("second line", blocks[1].text)
    end)

    it("preserves the flat answer.content for backward compat", function()
        local lines, header_end = buf({
            "💬: hello",
            "🤖: [Claude]",
            "flat text",
        })
        local parsed = parser.parse_chat(lines, header_end, test_config())
        assert.equals("flat text", parsed.exchanges[1].answer.content)
    end)

    it("empty answer produces either empty list or a single empty-trimmed text block", function()
        local lines, header_end = buf({
            "💬: hello",
            "🤖: [Claude]",
        })
        local parsed = parser.parse_chat(lines, header_end, test_config())
        local blocks = first_answer_blocks(parsed)
        -- Either zero blocks (empty trimmed text filtered out) OR one
        -- empty-text block. Both are valid; just ensure it's a table
        -- and doesn't crash downstream consumers.
        assert.is_table(blocks)
    end)
end)

--------------------------------------------------------------------------------
-- Tool blocks
--------------------------------------------------------------------------------

describe("chat_parser tool_use / tool_result recognition", function()
    it("recognizes a single tool_use block inside an answer", function()
        -- Build a serialized tool_use block the way tool_loop would
        -- write it, so the parser's body-decoding stays in sync with
        -- the writer (via serialize.parse_call).
        local tool_use_block = serialize.render_call({
            id = "toolu_01",
            name = "read_file",
            input = { path = "foo.txt" },
        })
        local lines = { "💬: question", "🤖: [Claude]", "Let me read that file." }
        for l in tool_use_block:gmatch("[^\n]+") do
            table.insert(lines, l)
        end
        -- Also capture the empty trailing line the serializer produces
        -- (none — render_call has no trailing newline — ok)

        local parsed = parser.parse_chat(lines, 0, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.is_not_nil(blocks)
        -- Expected block order: [text "Let me read that file.", tool_use]
        assert.equals(2, #blocks)

        assert.equals("text", blocks[1].type)
        assert.matches("Let me read that file%.", blocks[1].text)

        assert.equals("tool_use", blocks[2].type)
        assert.equals("toolu_01", blocks[2].id)
        assert.equals("read_file", blocks[2].name)
        assert.equals("foo.txt", blocks[2].input.path)
    end)

    it("recognizes a tool_use followed by a tool_result", function()
        local tool_use_block = serialize.render_call({
            id = "toolu_02",
            name = "read_file",
            input = { path = "bar.txt" },
        })
        local tool_result_block = serialize.render_result({
            id = "toolu_02",
            name = "read_file",
            content = "    1  line one\n    2  line two",
            is_error = false,
        })

        local lines = { "💬: q", "🤖: [Claude]" }
        for l in tool_use_block:gmatch("[^\n]+") do table.insert(lines, l) end
        for l in tool_result_block:gmatch("[^\n]+") do table.insert(lines, l) end
        table.insert(lines, "Based on that file, the first line is 'line one'.")

        local parsed = parser.parse_chat(lines, 0, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.is_not_nil(blocks)
        -- Expected: tool_use, tool_result, text
        assert.equals(3, #blocks)
        assert.equals("tool_use", blocks[1].type)
        assert.equals("toolu_02", blocks[1].id)
        assert.equals("tool_result", blocks[2].type)
        assert.equals("toolu_02", blocks[2].id)
        assert.equals(false, blocks[2].is_error)
        assert.matches("line one", blocks[2].content)
        assert.equals("text", blocks[3].type)
        assert.matches("first line is 'line one'", blocks[3].text)
    end)

    it("handles multiple tool_use/result pairs in one answer", function()
        local lines = { "💬: q", "🤖: [Claude]", "Reading two files." }
        for _, cfg in ipairs({
            { id = "toolu_A", path = "a.txt" },
            { id = "toolu_B", path = "b.txt" },
        }) do
            local tu = serialize.render_call({
                id = cfg.id,
                name = "read_file",
                input = { path = cfg.path },
            })
            local tr = serialize.render_result({
                id = cfg.id,
                name = "read_file",
                content = "body of " .. cfg.path,
                is_error = false,
            })
            for l in tu:gmatch("[^\n]+") do table.insert(lines, l) end
            for l in tr:gmatch("[^\n]+") do table.insert(lines, l) end
        end
        table.insert(lines, "Both files read successfully.")

        local parsed = parser.parse_chat(lines, 0, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.is_not_nil(blocks)

        -- Expected: text, tu_A, tr_A, tu_B, tr_B, text
        local types_in_order = {}
        for _, b in ipairs(blocks) do table.insert(types_in_order, b.type) end
        assert.same({ "text", "tool_use", "tool_result", "tool_use", "tool_result", "text" }, types_in_order)

        -- Verify the tool blocks carry the right ids in the right order
        local tool_block_ids = {}
        for _, b in ipairs(blocks) do
            if b.id then table.insert(tool_block_ids, b.id) end
        end
        assert.same({ "toolu_A", "toolu_A", "toolu_B", "toolu_B" }, tool_block_ids)
    end)

    it("recognizes an error tool_result (is_error=true)", function()
        local tool_use_block = serialize.render_call({
            id = "toolu_err", name = "edit_file",
            input = { path = "x", old_string = "a", new_string = "b" },
        })
        local tool_result_block = serialize.render_result({
            id = "toolu_err", name = "edit_file",
            content = "old_string not found in file",
            is_error = true,
        })
        local lines = { "💬: q", "🤖: [Claude]" }
        for l in tool_use_block:gmatch("[^\n]+") do table.insert(lines, l) end
        for l in tool_result_block:gmatch("[^\n]+") do table.insert(lines, l) end

        local parsed = parser.parse_chat(lines, 0, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.equals(2, #blocks)
        assert.equals("tool_result", blocks[2].type)
        assert.equals(true, blocks[2].is_error)
        assert.matches("not found", blocks[2].content)
    end)
end)

--------------------------------------------------------------------------------
-- Multiple exchanges (state reset)
--------------------------------------------------------------------------------

describe("chat_parser content_blocks across multiple exchanges", function()
    it("each answer's content_blocks is independent", function()
        local tu1 = serialize.render_call({ id = "toolu_E1", name = "read_file", input = { path = "a" } })
        local tr1 = serialize.render_result({ id = "toolu_E1", name = "read_file", content = "body a", is_error = false })

        local lines = { "💬: first", "🤖: [Claude]", "Reading a." }
        for l in tu1:gmatch("[^\n]+") do table.insert(lines, l) end
        for l in tr1:gmatch("[^\n]+") do table.insert(lines, l) end

        table.insert(lines, "💬: second")
        table.insert(lines, "🤖: [Claude]")
        table.insert(lines, "Just text, no tools.")

        local parsed = parser.parse_chat(lines, 0, test_config())
        assert.equals(2, #parsed.exchanges)

        local first_blocks = parsed.exchanges[1].answer.content_blocks
        local second_blocks = parsed.exchanges[2].answer.content_blocks

        -- First exchange has tool blocks
        local first_types = {}
        for _, b in ipairs(first_blocks) do table.insert(first_types, b.type) end
        assert.is_true(#first_blocks >= 2)
        local has_tool_use = false
        for _, t in ipairs(first_types) do if t == "tool_use" then has_tool_use = true end end
        assert.is_true(has_tool_use, "first exchange should contain a tool_use block")

        -- Second exchange has NO tool blocks (pure text)
        assert.equals(1, #second_blocks)
        assert.equals("text", second_blocks[1].type)
        assert.matches("Just text, no tools", second_blocks[1].text)
    end)
end)

--------------------------------------------------------------------------------
-- Interaction with other prefixes
--------------------------------------------------------------------------------

describe("chat_parser content_blocks vs other prefixes", function()
    it("summary and reasoning lines do not split text blocks", function()
        local lines, header_end = buf({
            "💬: hello",
            "🤖: [Claude]",
            "🧠: thinking about it",
            "First part of answer.",
            "📝: one-liner summary",
            "Second part of answer.",
        })
        local parsed = parser.parse_chat(lines, header_end, test_config())
        local blocks = first_answer_blocks(parsed)
        -- summary and reasoning are stored as separate fields on the
        -- exchange, NOT as content blocks. The text block should
        -- contain both "First part" and "Second part".
        assert.equals(1, #blocks)
        assert.equals("text", blocks[1].type)
        assert.matches("First part", blocks[1].text)
        assert.matches("Second part", blocks[1].text)
        -- And the reasoning/summary are still captured as exchange
        -- fields (existing behavior — regression check)
        assert.is_not_nil(parsed.exchanges[1].reasoning)
        assert.is_not_nil(parsed.exchanges[1].summary)
    end)

    it("local 🔒: section inside an answer stops content block accumulation", function()
        -- Existing parser behavior: once 🔒: is seen, content continuation
        -- is skipped until the next 💬:/🤖: prefix. Our content_blocks
        -- should match that behavior — no local-section lines leak in.
        local lines, header_end = buf({
            "💬: hello",
            "🤖: [Claude]",
            "Visible text.",
            "🔒: private scratch notes",
            "still private because line_before_local is set",
            "💬: second turn",
            "🤖: [Claude]",
            "next answer",
        })
        local parsed = parser.parse_chat(lines, header_end, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.equals(1, #blocks)
        assert.equals("text", blocks[1].type)
        assert.matches("Visible text", blocks[1].text)
        assert.not_matches("still private", blocks[1].text)
        assert.not_matches("private scratch notes", blocks[1].text)
    end)
end)

--------------------------------------------------------------------------------
-- Malformed tool blocks
--------------------------------------------------------------------------------

describe("chat_parser tolerates malformed tool blocks", function()
    it("a tool_use prefix without a fenced body still produces a tool_use block with empty input", function()
        -- The user may have hand-typed a 🔧: header and moved on.
        -- Parser must not crash. Empty input is the safest fallback.
        local lines, header_end = buf({
            "💬: hello",
            "🤖: [Claude]",
            "🔧: read_file id=toolu_bare",
        })
        local parsed = parser.parse_chat(lines, header_end, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.is_not_nil(blocks)
        -- At least one tool_use block with the expected id
        local found = nil
        for _, b in ipairs(blocks) do
            if b.type == "tool_use" then found = b end
        end
        assert.is_not_nil(found)
        assert.equals("toolu_bare", found.id)
        assert.equals("read_file", found.name)
        assert.same({}, found.input)
    end)
end)
