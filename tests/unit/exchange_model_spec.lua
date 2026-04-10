-- Unit tests for lua/parley/exchange_model.lua
--
-- Pure positional model for chat buffer layout. Tracks exchange/section
-- sizes and computes absolute buffer line positions. No nvim API.
-- See #90 design: size-based architecture.

local em = require("parley.exchange_model")

describe("exchange_model: basic construction", function()
    it("creates an empty model with header_lines", function()
        local m = em.new(4)  -- 4 header lines (---/topic/file/---)
        assert.equals(4, m.header_lines)
        assert.equals(0, #m.exchanges)
    end)
end)

describe("exchange_model: single exchange, no answer", function()
    it("exchange_start is header_lines + 1 (margin after header)", function()
        local m = em.new(4)
        m:add_exchange(1)  -- question_size = 1
        assert.equals(5, m:exchange_start(1))  -- 0-indexed: 4 header + 1 margin = 5
    end)
end)

describe("exchange_model: single exchange with answer, no sections", function()
    it("answer_start is after question + margin", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:create_answer(1)
        -- Layout: header(4) + margin(1) + q(1) + margin(1) + 🤖:(1)
        -- 0-indexed: 0-3=header, 4=margin, 5=q, 6=margin, 7=🤖:
        assert.equals(7, m:answer_start(1))
    end)

    it("answer_append_pos is right after the agent header", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:create_answer(1)
        -- Next section goes at line 8 (right after 🤖: at 7)
        assert.equals(8, m:answer_append_pos(1))
    end)
end)

describe("exchange_model: single exchange with sections", function()
    it("section_start for the first section is right after agent header", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:create_answer(1)
        local pos = m:add_section(1, "text", 3)
        assert.equals(8, pos)  -- right after 🤖: at 7
        assert.equals(8, m:section_start(1, 1))
    end)

    it("section_start for the second section includes margin", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:create_answer(1)
        m:add_section(1, "text", 3)       -- lines 8-10
        local pos = m:add_section(1, "tool_use", 4)  -- margin at 11, tool_use at 12-15
        assert.equals(12, pos)
        assert.equals(12, m:section_start(1, 2))
    end)

    it("answer_append_pos advances after adding sections", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:create_answer(1)
        m:add_section(1, "text", 3)       -- lines 8-10
        m:add_section(1, "tool_use", 4)   -- margin at 11, lines 12-15
        -- Next section: margin at 16, starts at 17
        assert.equals(17, m:answer_append_pos(1))
    end)

    it("section_end returns the last line of a section", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:create_answer(1)
        m:add_section(1, "text", 3)       -- lines 8-10
        assert.equals(10, m:section_end(1, 1))
    end)

    it("grow_section updates the size and shifts subsequent positions", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:create_answer(1)
        m:add_section(1, "text", 1)       -- line 8 (1 line)
        m:add_section(1, "tool_use", 4)   -- margin at 9, lines 10-13
        assert.equals(10, m:section_start(1, 2))
        -- Grow the text section by 2 lines (streaming added content)
        m:grow_section(1, 1, 2)
        -- text is now 3 lines: 8-10. tool_use shifts: margin at 11, lines 12-15
        assert.equals(12, m:section_start(1, 2))
    end)
end)

describe("exchange_model: two exchanges", function()
    it("second exchange starts after first exchange + margin", function()
        local m = em.new(4)
        m:add_exchange(1)   -- exchange 1: q(1)
        m:create_answer(1)
        m:add_section(1, "text", 2)  -- 2-line text
        m:add_exchange(1)   -- exchange 2: q(1)
        -- Layout:
        --   header(4) + margin(1) = 5
        --   exchange 1: q(1) + margin(1) + 🤖:(1) + text(2) = 5
        --   margin(1) between exchanges
        --   exchange 2 start: 5 + 5 + 1 = 11
        assert.equals(11, m:exchange_start(2))
    end)

    it("tool blocks in exchange 1 don't affect exchange 2 question start", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:create_answer(1)
        m:add_section(1, "text", 1)
        m:add_section(1, "tool_use", 4)
        m:add_section(1, "tool_result", 5)
        m:add_exchange(1)  -- placeholder 💬:
        -- exchange 1 total: q(1) + margin(1) + 🤖:(1) + text(1) + margin(1) + tu(4) + margin(1) + tr(5) = 15
        -- exchange 2 start: 5 + 15 + 1 = 21
        assert.equals(21, m:exchange_start(2))
        -- Growing text section shifts exchange 2
        m:grow_section(1, 1, 3)
        assert.equals(24, m:exchange_start(2))
    end)

    it("add_section in exchange 1 returns position BEFORE exchange 2", function()
        local m = em.new(4)
        m:add_exchange(1)  -- q at line 5
        m:create_answer(1)  -- 🤖: at line 7
        m:add_exchange(1)  -- placeholder 💬: at line 9
        -- answer_append_pos for exchange 1 should be 8 (right after 🤖:)
        assert.equals(8, m:answer_append_pos(1))
        -- exchange 2 is at line 9
        assert.equals(9, m:exchange_start(2))
        -- Add a 4-line section to exchange 1
        local pos = m:add_section(1, "tool_use", 4)
        assert.equals(8, pos)  -- inserted at line 8
        -- exchange 2 should now be at 8 + 4 + 1(margin) = 13
        assert.equals(13, m:exchange_start(2))
    end)
end)

describe("exchange_model: from_parsed_chat", function()
    it("loads exchange structure from parser output", function()
        -- Simulate a parsed_chat with one exchange, answer with 2 sections
        local parsed = {
            header_end = 4,
            exchanges = {
                {
                    question = { line_start = 6, line_end = 6 },
                    answer = {
                        line_start = 8, line_end = 16,
                        sections = {
                            { kind = "tool_use", line_start = 9, line_end = 12 },
                            { kind = "tool_result", line_start = 14, line_end = 16 },
                        },
                    },
                },
                {
                    question = { line_start = 18, line_end = 18 },
                    answer = nil,
                },
            },
        }
        local m = em.from_parsed_chat(parsed)
        assert.equals(2, #m.exchanges)
        assert.equals(2, #m.exchanges[1].answer.sections)
        assert.equals(4, m.exchanges[1].answer.sections[1].size)  -- 12-9+1
        assert.equals(3, m.exchanges[1].answer.sections[2].size)  -- 16-14+1
    end)
end)
