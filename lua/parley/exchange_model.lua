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
-- only sizes.
--
-- See #90 design: size-based architecture.
--
-- Rules:
--   1. Everything is a block (question, agent_header, text, tool_use,
--      tool_result, spinner, thinking, note, ...).
--   2. 1 blank margin line between adjacent non-empty blocks.
--   3. Empty block (size 0) cancels one margin — effectively invisible.
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
function Model:add_exchange(question_size)
    table.insert(self.exchanges, {
        blocks = {
            { kind = "question", size = question_size },
        },
    })
end

--- Add a block to exchange K. Returns the 0-indexed buffer line where
--- the block content should be inserted.
--- @param k integer  exchange index (1-based)
--- @param kind string  block kind (agent_header/text/tool_use/tool_result/spinner/...)
--- @param size integer  number of lines the block occupies
--- @return integer  0-indexed insert position
function Model:add_block(k, kind, size)
    local pos = self:append_pos(k)
    table.insert(self.exchanges[k].blocks, {
        kind = kind,
        size = size,
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
            if has_prev then
                size = size + MARGIN
            end
            size = size + blk.size
            has_prev = true
        end
    end
    return size
end

--- 0-indexed buffer line where exchange K starts (= where its first
--- non-empty block starts).
function Model:exchange_start(k)
    local line = self.header_lines + MARGIN  -- after header + 1 margin
    for i = 1, k - 1 do
        line = line + self:exchange_total_size(i)
        line = line + MARGIN  -- margin between exchanges
    end
    return line
end

--- 0-indexed buffer line where block B of exchange K starts.
--- Skips empty blocks (they're invisible per rule 3).
function Model:block_start(k, b)
    local line = self:exchange_start(k)
    local has_prev = false
    for i = 1, b do
        local blk = self.exchanges[k].blocks[i]
        if i == b then
            -- Margin before this block if there's preceding content
            if has_prev and blk.size > 0 then
                line = line + MARGIN
            elseif has_prev then
                -- Block is empty — position it where it would be
                -- (after the margin), but it occupies 0 lines.
                line = line + MARGIN
            end
            return line
        end
        if blk.size > 0 then
            if has_prev then
                line = line + MARGIN
            end
            line = line + blk.size
            has_prev = true
        end
    end
    return line
end

--- 0-indexed buffer line of the last line of block B.
function Model:block_end(k, b)
    return self:block_start(k, b) + self.exchanges[k].blocks[b].size - 1
end

--- 0-indexed buffer line where the NEXT block would be inserted
--- (after all existing blocks + margin).
function Model:append_pos(k)
    local n = #self.exchanges[k].blocks
    if n == 0 then
        return self:exchange_start(k)
    end
    -- Find the last non-empty block
    for i = n, 1, -1 do
        if self.exchanges[k].blocks[i].size > 0 then
            return self:block_end(k, i) + 1 + MARGIN
        end
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
    for _, ex in ipairs(parsed_chat.exchanges or {}) do
        local q_size = 1
        if ex.question then
            q_size = ex.question.line_end - ex.question.line_start + 1
        end
        model:add_exchange(q_size)
        if ex.answer then
            local k = #model.exchanges
            -- Agent header is the first answer block (🤖: line, 1 line)
            model:add_block(k, "agent_header", 1)
            for _, sec in ipairs(ex.answer.sections or {}) do
                local sec_size = 1
                if sec.line_start and sec.line_end then
                    sec_size = sec.line_end - sec.line_start + 1
                end
                model:add_block(k, sec.kind or sec.type or "text", sec_size)
            end
        end
    end
    return model
end

return M
