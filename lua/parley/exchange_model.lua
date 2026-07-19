-- Pure positional model for chat buffer layout.
--
-- Tracks exchange/block sizes and computes absolute 0-indexed buffer
-- line positions. No nvim API — this module is fully testable without
-- a running Neovim instance.
--
-- The model is the single source of truth for "where does block S
-- of exchange K live in the buffer?" Callers mutate the model (add
-- blocks, grow blocks) and the model recomputes positions on demand
-- from accumulated sizes. No absolute line numbers are ever stored —
-- sizes and the gaps recorded before visible items.
--
-- See #90 design: size-based architecture.
--
-- Rules:
--   1. Everything is a block (question, agent_header, text, tool_use,
--      tool_result, spinner, thinking, note, ...).
--   2. Parsed blocks preserve their actual preceding gaps; new blocks default
--      to one blank line.
--   3. Empty blocks contribute neither content nor gap.
--
-- Layout convention:
--   HEADER (header_lines lines)
--   MARGIN (1 blank)
--   EXCHANGE 1:
--     block 1: question (size lines)
--     MARGIN (1 blank)
--     block 2: agent_header (1 line)
--     MARGIN (1 blank)
--     block 3: text (size lines)
--     MARGIN (1 blank) — only between non-empty blocks
--     block 4: tool_use (size lines)
--     ...
--   MARGIN (1 blank) — between exchanges
--   EXCHANGE 2:
--     ...

local MARGIN = 1  -- blank line between non-empty blocks

local Model = {}
Model.__index = Model

local M = {}

local function last_nonempty_block_index(exchange)
    for i = #exchange.blocks, 1, -1 do
        if exchange.blocks[i].size > 0 then
            return i
        end
    end
    return nil
end

--- Create a new empty model.
--- @param header_lines integer  number of header lines (e.g. 4 for ---/topic/file/---)
--- @return Model
function M.new(header_lines)
    return setmetatable({
        header_lines = header_lines,
        exchanges = {},
    }, Model)
end

--- Add an exchange. The question is block 1 (always present).
--- @param question_size integer  number of lines the question occupies
function Model:add_exchange(question_size, gap_before)
    table.insert(self.exchanges, {
        gap_before = gap_before == nil and MARGIN or gap_before,
        blocks = {
            { kind = "question", size = question_size, gap_before = 0 },
        },
    })
end

--- Add a block to exchange K. Returns the 0-indexed buffer line where
--- the block content should be inserted.
--- @param k integer  exchange index (1-based)
--- @param kind string  block kind (agent_header/text/tool_use/tool_result/spinner/...)
--- @param size integer  number of lines the block occupies
--- @return integer  0-indexed insert position
function Model:add_block(k, kind, size, gap_before)
    local pos = self:append_pos(k)
    table.insert(self.exchanges[k].blocks, {
        kind = kind,
        size = size,
        gap_before = gap_before == nil and MARGIN or gap_before,
    })
    return pos
end

--- Grow a block's size by delta lines (e.g. streaming added content).
--- @param k integer  exchange index
--- @param b integer  block index within exchange K
--- @param delta integer  number of lines to add
function Model:grow_block(k, b, delta)
    self.exchanges[k].blocks[b].size = self.exchanges[k].blocks[b].size + delta
end

--- Update a block's size to an exact value.
function Model:set_block_size(k, b, new_size)
    self.exchanges[k].blocks[b].size = new_size
end

--- Remove a block from exchange K. All subsequent block positions
--- shift automatically since they're computed from sizes.
--- @param k integer  exchange index
--- @param b integer  block index to remove
function Model:remove_block(k, b)
    table.remove(self.exchanges[k].blocks, b)
end

--- Replace a contiguous block span with semantic sections.
--- Returns the 1-based indices of every inserted block.
function Model:replace_span(k, first_block, old_count, sections)
    local exchange = assert(self.exchanges[k], "invalid exchange index")
    assert(type(first_block) == "number" and type(old_count) == "number" and old_count >= 0,
        "invalid replacement span")
    assert(first_block >= 1 and first_block <= #exchange.blocks + 1, "invalid replacement start")
    assert(first_block + old_count - 1 <= #exchange.blocks, "replacement exceeds exchange")
    sections = sections or {}
    for _, section in ipairs(sections) do
        assert(type(section.kind) == "string" and type(section.size) == "number" and section.size >= 0,
            "invalid replacement section")
        assert(section.gap_before == nil or (type(section.gap_before) == "number" and section.gap_before >= 0),
            "invalid replacement gap")
    end
    local inherited_gap = exchange.blocks[first_block] and exchange.blocks[first_block].gap_before or MARGIN
    for _ = 1, old_count do table.remove(exchange.blocks, first_block) end
    local changed = {}
    for offset, section in ipairs(sections) do
        local index = first_block + offset - 1
        local gap_before = section.gap_before
        if gap_before == nil then
            gap_before = offset == 1 and inherited_gap or MARGIN
        end
        table.insert(exchange.blocks, index, {
            kind = section.kind,
            size = section.size,
            gap_before = gap_before,
        })
        changed[#changed + 1] = index
    end
    return changed
end

-- ============================================================================
-- Position queries (all return 0-indexed buffer line)
-- ============================================================================

--- Total size of exchange K in buffer lines (all non-empty blocks +
--- margins between them).
function Model:exchange_total_size(k)
    local size = 0
    local has_prev = false
    for _, blk in ipairs(self.exchanges[k].blocks) do
        if blk.size > 0 then
            if has_prev then size = size + (blk.gap_before or MARGIN) end
            size = size + blk.size
            has_prev = true
        end
    end
    return size
end

--- 0-indexed buffer line where exchange K starts (= where its first
--- non-empty block starts).
function Model:exchange_start(k)
    local line = self.header_lines
    for i = 1, k do
        line = line + (self.exchanges[i].gap_before or MARGIN)
        if i == k then return line end
        line = line + self:exchange_total_size(i)
    end
end

--- 0-indexed buffer line where block B of exchange K starts.
--- Skips empty blocks (they're invisible per rule 3).
function Model:block_start(k, b)
    local line = self:exchange_start(k)
    local has_prev = false
    for i = 1, b do
        local blk = self.exchanges[k].blocks[i]
        if blk.size > 0 then
            if has_prev then line = line + (blk.gap_before or MARGIN) end
            if i == b then return line end
            line = line + blk.size
            has_prev = true
        elseif i == b then
            return line
        end
    end
    return line
end

--- 0-indexed buffer line of the last line of block B.
function Model:block_end(k, b)
    return self:block_start(k, b) + self.exchanges[k].blocks[b].size - 1
end

--- 0-indexed last line of the final visible block, or nil if none is visible.
function Model:last_nonempty_block_end(k)
    local block_index = last_nonempty_block_index(self.exchanges[k])
    if not block_index then
        return nil
    end
    return self:block_end(k, block_index)
end

--- 0-indexed buffer line where the NEXT block would be inserted
--- (after all existing blocks + margin).
function Model:append_pos(k)
    if #self.exchanges[k].blocks == 0 then
        return self:exchange_start(k)
    end
    local last_end = self:last_nonempty_block_end(k)
    if last_end then
        return last_end + 1 + MARGIN
    end
    -- All blocks are empty — append at exchange start + margin
    return self:exchange_start(k) + MARGIN
end

-- ============================================================================
-- Convenience aliases (backward compat with callers using old API names)
-- ============================================================================

--- @deprecated Use add_block
function Model:add_section(k, kind, size)
    return self:add_block(k, kind, size)
end

--- @deprecated Use grow_block
function Model:grow_section(k, s, delta)
    return self:grow_block(k, s, delta)
end

--- @deprecated Use remove_block
function Model:remove_section(k, s)
    return self:remove_block(k, s)
end

--- @deprecated Use block_start
function Model:section_start(k, s)
    return self:block_start(k, s)
end

--- @deprecated Use block_end
function Model:section_end(k, s)
    return self:block_end(k, s)
end

--- @deprecated Use append_pos
function Model:answer_append_pos(k)
    return self:append_pos(k)
end

--- Convenience: question_size is blocks[1].size
function Model:question_size(k)
    return self.exchanges[k].blocks[1].size
end

--- Convenience: grow question (block 1) size.
function Model:grow_question(k, delta)
    self:grow_block(k, 1, delta)
end

-- ============================================================================
-- Load from parser output
-- ============================================================================

--- Build a model from a parsed_chat structure. Infers sizes from the
--- parser's recorded line spans.
--- @param parsed_chat table  output of chat_parser.parse_chat
--- @return Model
function M.from_parsed_chat(parsed_chat)
    local header_lines = parsed_chat.header_end or 0
    local model = M.new(header_lines)
    local previous_exchange_end
    for _, ex in ipairs(parsed_chat.exchanges or {}) do
        local q_size = 1
        local question_start = ex.question and ex.question.line_start or (header_lines + MARGIN + 1)
        local question_end = question_start + q_size - 1
        if ex.question then
            q_size = ex.question.line_end - ex.question.line_start + 1
            question_end = ex.question.line_end
        end
        local gap_before
        if previous_exchange_end then
            gap_before = question_start - previous_exchange_end - 1
        else
            gap_before = question_start - header_lines - 1
        end
        assert(gap_before >= 0, "overlapping exchange spans")
        model:add_exchange(q_size, gap_before)
        local previous_block_end = question_end
        if ex.answer then
            local k = #model.exchanges
            -- Agent header is the first answer block (🤖: line, 1 line)
            local answer_start = ex.answer.line_start
            local answer_gap = answer_start - previous_block_end - 1
            assert(answer_gap >= 0, "overlapping answer spans")
            model:add_block(k, "agent_header", 1, answer_gap)
            previous_block_end = answer_start
            for _, sec in ipairs(ex.answer.semantic_sections or ex.answer.sections or {}) do
                local sec_size = 1
                if sec.line_start and sec.line_end then
                    sec_size = sec.line_end - sec.line_start + 1
                end
                local section_start = sec.line_start or (previous_block_end + MARGIN + 1)
                local section_end = sec.line_end or (section_start + sec_size - 1)
                local section_gap = section_start - previous_block_end - 1
                assert(section_gap >= 0, "overlapping answer section spans")
                model:add_block(k, sec.kind or sec.type or "text", sec_size, section_gap)
                previous_block_end = section_end
            end
        end
        previous_exchange_end = previous_block_end
    end
    return model
end

return M
