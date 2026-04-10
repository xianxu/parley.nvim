-- Unit tests for chat_parser line spans on answer sections.
--
-- Each section in answer.sections (alias content_blocks) gains
-- line_start and line_end tracking the buffer span the section
-- occupies. See Task 1.1 of #90.

local chat_parser = require("parley.chat_parser")
local cfg = require("parley.config")

local function parse(lines)
    return chat_parser.parse_chat(lines, chat_parser.find_header_end(lines), cfg)
end

describe("chat_parser: section line spans", function()
    it("text-only answer has one text section spanning the answer body", function()
        local lines = {
            "---",          -- 1
            "topic: t",     -- 2
            "file: f.md",   -- 3
            "---",          -- 4
            "",             -- 5
            "💬: q",        -- 6
            "",             -- 7
            "🤖: [A]",       -- 8
            "the answer",   -- 9
        }
        local p = parse(lines)
        local secs = p.exchanges[1].answer.sections
        assert.equals(1, #secs)
        assert.equals("text", secs[1].kind)
        assert.equals(9, secs[1].line_start)
        assert.equals(9, secs[1].line_end)
    end)

    it("tool_use + tool_result get exact line spans", function()
        local lines = {
            "---",                   -- 1
            "topic: t",              -- 2
            "file: f.md",            -- 3
            "---",                   -- 4
            "",                      -- 5
            "💬: q",                 -- 6
            "",                      -- 7
            "🤖: [A]",                -- 8
            "🔧: read_file id=X",     -- 9
            "```json",               -- 10
            '{"p":"x"}',              -- 11
            "```",                   -- 12
            "📎: read_file id=X",     -- 13
            "````",                  -- 14
            "body",                  -- 15
            "````",                  -- 16
        }
        local p = parse(lines)
        local secs = p.exchanges[1].answer.sections
        assert.equals(2, #secs)
        assert.equals("tool_use", secs[1].kind)
        assert.equals(9, secs[1].line_start)
        assert.equals(12, secs[1].line_end)
        assert.equals("tool_result", secs[2].kind)
        assert.equals(13, secs[2].line_start)
        assert.equals(16, secs[2].line_end)
    end)

    it("text + tool_use + tool_result + text yields 4 sections in order", function()
        local lines = {
            "---", "topic: t", "file: f.md", "---", "", -- 1-5
            "💬: q",                                    -- 6
            "",                                         -- 7
            "🤖: [A]",                                  -- 8
            "Let me check.",                            -- 9
            "🔧: read_file id=X",                       -- 10
            "```json",                                  -- 11
            '{"p":"x"}',                                 -- 12
            "```",                                      -- 13
            "📎: read_file id=X",                       -- 14
            "````",                                     -- 15
            "body",                                     -- 16
            "````",                                     -- 17
            "Done.",                                    -- 18
        }
        local p = parse(lines)
        local secs = p.exchanges[1].answer.sections
        assert.equals(4, #secs)
        assert.equals("text",        secs[1].kind); assert.equals("Let me check.", secs[1].text)
        assert.equals("tool_use",    secs[2].kind)
        assert.equals("tool_result", secs[3].kind)
        assert.equals("text",        secs[4].kind); assert.equals("Done.", secs[4].text)
        assert.equals(9,  secs[1].line_start); assert.equals(9,  secs[1].line_end)
        assert.equals(10, secs[2].line_start); assert.equals(13, secs[2].line_end)
        assert.equals(14, secs[3].line_start); assert.equals(17, secs[3].line_end)
        assert.equals(18, secs[4].line_start); assert.equals(18, secs[4].line_end)
    end)

    describe("section helper functions (#90 Task 1.2)", function()
        local function fixture()
            return parse({
                "---", "topic: t", "file: f.md", "---", "",  -- 1-5
                "💬: q1",                                    -- 6
                "",                                          -- 7
                "🤖: [A]",                                   -- 8
                "hi",                                        -- 9
                "💬: q2",                                    -- 10
                "",                                          -- 11
                "🤖: [B]",                                   -- 12
                "🔧: read_file id=X",                        -- 13
                "```json",                                   -- 14
                '{"p":"x"}',                                  -- 15
                "```",                                       -- 16
                "📎: read_file id=X",                        -- 17
                "````",                                      -- 18
                "body",                                      -- 19
                "````",                                      -- 20
            })
        end

        it("find_exchange_at_line", function()
            local p = fixture()
            assert.equals(1, chat_parser.find_exchange_at_line(p, 6))
            assert.equals(1, chat_parser.find_exchange_at_line(p, 9))
            assert.equals(2, chat_parser.find_exchange_at_line(p, 10))
            assert.equals(2, chat_parser.find_exchange_at_line(p, 19))
            assert.is_nil(chat_parser.find_exchange_at_line(p, 1))
        end)

        it("find_section_at_line", function()
            local p = fixture()
            local ex_idx, sec_idx = chat_parser.find_section_at_line(p, 14)
            assert.equals(2, ex_idx)
            assert.equals(1, sec_idx)  -- inside the tool_use section
            local ex2, sec2 = chat_parser.find_section_at_line(p, 19)
            assert.equals(2, ex2)
            assert.equals(2, sec2)  -- inside the tool_result section
        end)

        it("last_section_in_answer", function()
            local p = fixture()
            local s = chat_parser.last_section_in_answer(p, 2)
            assert.is_not_nil(s)
            assert.equals("tool_result", s.kind)

            local s1 = chat_parser.last_section_in_answer(p, 1)
            assert.equals("text", s1.kind)
            assert.equals("hi", s1.text)
        end)
    end)

    it("answer.content_blocks alias still works", function()
        local lines = {
            "---", "topic: t", "file: f.md", "---", "",
            "💬: q", "", "🤖: [A]", "hi",
        }
        local p = parse(lines)
        assert.equals(p.exchanges[1].answer.sections, p.exchanges[1].answer.content_blocks)
    end)
end)
