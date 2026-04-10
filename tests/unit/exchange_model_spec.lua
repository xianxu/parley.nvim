-- Unit tests for lua/parley/exchange_model.lua
--
-- Pure positional model for chat buffer layout. Everything is a block.
-- 1 margin between non-empty blocks. Empty blocks (size 0) are invisible.

local em = require("parley.exchange_model")

describe("exchange_model: basic construction", function()
    it("creates an empty model with header_lines", function()
        local m = em.new(4)
        assert.equals(4, m.header_lines)
        assert.equals(0, #m.exchanges)
    end)
end)

describe("exchange_model: single exchange, question only", function()
    it("exchange_start is header_lines + margin", function()
        local m = em.new(4)
        m:add_exchange(1)
        assert.equals(5, m:exchange_start(1))  -- 4 header + 1 margin
    end)

    it("append_pos for question-only exchange is after question + margin", function()
        local m = em.new(4)
        m:add_exchange(1)
        -- question at 5, size 1 → next block at 5 + 1 + 1(margin) = 7
        assert.equals(7, m:append_pos(1))
    end)
end)

describe("exchange_model: single exchange with blocks", function()
    it("agent_header block starts after question + margin", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:add_block(1, "agent_header", 1)
        -- question at 5(size 1), margin, agent_header at 7
        assert.equals(7, m:block_start(1, 2))
    end)

    it("text block starts after agent_header + margin", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:add_block(1, "agent_header", 1)
        m:add_block(1, "text", 3)
        -- agent_header at 7(size 1), margin, text at 9
        assert.equals(9, m:block_start(1, 3))
    end)

    it("block_end returns the last line of a block", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:add_block(1, "agent_header", 1)
        m:add_block(1, "text", 3)  -- lines 9-11
        assert.equals(11, m:block_end(1, 3))
    end)

    it("tool_use block after text includes margin", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:add_block(1, "agent_header", 1)
        m:add_block(1, "text", 3)      -- lines 9-11
        m:add_block(1, "tool_use", 4)  -- margin at 12, lines 13-16
        assert.equals(13, m:block_start(1, 4))
    end)

    it("append_pos advances after adding blocks", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:add_block(1, "agent_header", 1)
        m:add_block(1, "text", 3)      -- lines 9-11
        m:add_block(1, "tool_use", 4)  -- lines 13-16
        -- next block: 16 + 1 + 1(margin) = 18
        assert.equals(18, m:append_pos(1))
    end)

    it("grow_block updates the size and shifts subsequent positions", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:add_block(1, "agent_header", 1)
        m:add_block(1, "text", 1)      -- line 9
        m:add_block(1, "tool_use", 4)  -- margin at 10, lines 11-14
        assert.equals(11, m:block_start(1, 4))
        -- Grow text by 2 lines (streaming)
        m:grow_block(1, 3, 2)
        -- text is now 3 lines: 9-11. tool_use shifts: margin at 12, lines 13-16
        assert.equals(13, m:block_start(1, 4))
    end)

    it("grow_question shifts all subsequent positions", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:add_block(1, "agent_header", 1)  -- line 7
        assert.equals(7, m:block_start(1, 2))
        m:grow_question(1, 5)  -- e.g. raw_request_fence
        assert.equals(12, m:block_start(1, 2))  -- shifted by 5
    end)
end)

describe("exchange_model: empty block cancellation", function()
    it("empty block is invisible — doesn't add margins", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:add_block(1, "agent_header", 1)  -- line 7
        m:add_block(1, "spinner", 0)       -- empty, invisible
        m:add_block(1, "text", 3)          -- should be at 9 (same as without spinner)
        assert.equals(9, m:block_start(1, 4))
    end)

    it("setting block size to 0 makes it invisible", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:add_block(1, "agent_header", 1)  -- line 7
        m:add_block(1, "spinner", 1)       -- line 9
        m:add_block(1, "text", 3)          -- line 11
        assert.equals(11, m:block_start(1, 4))
        -- Remove spinner by setting size to 0
        m:set_block_size(1, 3, 0)
        -- text should shift back: line 9
        assert.equals(9, m:block_start(1, 4))
    end)

    it("exchange_total_size skips empty blocks", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:add_block(1, "agent_header", 1)
        m:add_block(1, "spinner", 0)  -- invisible
        m:add_block(1, "text", 3)
        -- question(1) + margin + agent_header(1) + margin + text(3) = 7
        assert.equals(7, m:exchange_total_size(1))
    end)
end)

describe("exchange_model: two exchanges", function()
    it("second exchange starts after first + margin", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:add_block(1, "agent_header", 1)
        m:add_block(1, "text", 2)
        m:add_exchange(1)
        -- exchange 1: q(1) + m + ah(1) + m + text(2) = 6
        -- exchange 2 start: 5 + 6 + 1(margin between exchanges) = 12
        assert.equals(12, m:exchange_start(2))
    end)

    it("tool blocks in exchange 1 shift exchange 2", function()
        local m = em.new(4)
        m:add_exchange(1)
        m:add_block(1, "agent_header", 1)
        m:add_block(1, "text", 1)
        m:add_block(1, "tool_use", 4)
        m:add_block(1, "tool_result", 5)
        m:add_exchange(1)
        -- ex1: q(1)+m+ah(1)+m+text(1)+m+tu(4)+m+tr(5) = 16
        -- ex2 start: 5 + 16 + 1 = 22
        assert.equals(22, m:exchange_start(2))
        -- Growing text by 3 shifts exchange 2 by 3
        m:grow_block(1, 3, 3)
        assert.equals(25, m:exchange_start(2))
    end)
end)

describe("exchange_model: from_parsed_chat", function()
    it("loads exchange structure from parser output", function()
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
        -- Exchange 1: question + agent_header + tool_use + tool_result = 4 blocks
        assert.equals(4, #m.exchanges[1].blocks)
        assert.equals("question", m.exchanges[1].blocks[1].kind)
        assert.equals("agent_header", m.exchanges[1].blocks[2].kind)
        assert.equals(4, m.exchanges[1].blocks[3].size)  -- tool_use: 12-9+1
        assert.equals(3, m.exchanges[1].blocks[4].size)  -- tool_result: 16-14+1
        -- Exchange 2: question only
        assert.equals(1, #m.exchanges[2].blocks)
    end)
end)
