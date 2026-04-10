-- Pure positional model for chat buffer layout.
--
-- Tracks exchange/section sizes and computes absolute 0-indexed buffer
-- line positions. No nvim API — this module is fully testable without
-- a running Neovim instance.
--
-- The model is the single source of truth for "where does section K
-- of exchange J live in the buffer?" Callers mutate the model (add
-- sections, grow sections) and the model recomputes positions on demand
-- from accumulated sizes. No absolute line numbers are ever stored —
-- only sizes.
--
-- See #90 design: size-based architecture.
--
-- Layout convention:
--   HEADER (header_lines lines)
--   MARGIN (1 blank)
--   EXCHANGE 1:
--     QUESTION (question_size lines)
--     MARGIN (1 blank)
--     ANSWER HEADER (🤖: line, 1 line)
--     SECTION 1 (size lines)
--     MARGIN (1 blank) — only between sections, not before first
--     SECTION 2 (size lines)
--     ...
--   MARGIN (1 blank) — between exchanges
--   EXCHANGE 2:
--     ...

local MARGIN = 1  -- blank line between components

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

--- Add an exchange (question only, no answer yet).
--- @param question_size integer  number of lines the question occupies
function Model:add_exchange(question_size)
    table.insert(self.exchanges, {
        question_size = question_size,
        answer = nil,
    })
end

--- Create an answer stub for exchange K.
--- @param k integer  exchange index (1-based)
function Model:create_answer(k)
    self.exchanges[k].answer = {
        agent_header_size = 1,  -- the 🤖: line
        sections = {},
    }
end

--- Add a section to exchange K's answer. Returns the 0-indexed buffer
--- line where the section content should be inserted.
--- @param k integer  exchange index
--- @param kind string  section kind (text/tool_use/tool_result)
--- @param size integer  number of lines the section occupies
--- @return integer  0-indexed insert position
function Model:add_section(k, kind, size)
    local pos = self:answer_append_pos(k)
    table.insert(self.exchanges[k].answer.sections, {
        kind = kind,
        size = size,
    })
    return pos
end

--- Grow a section's size by delta lines (e.g. streaming added content).
--- @param k integer  exchange index
--- @param s integer  section index within exchange K's answer
--- @param delta integer  number of lines to add
function Model:grow_section(k, s, delta)
    self.exchanges[k].answer.sections[s].size = self.exchanges[k].answer.sections[s].size + delta
end

--- Update a section's size to an exact value.
function Model:set_section_size(k, s, new_size)
    self.exchanges[k].answer.sections[s].size = new_size
end

-- ============================================================================
-- Position queries (all return 0-indexed buffer line)
-- ============================================================================

--- Total size of an answer (header + sections + margins between sections).
function Model:answer_total_size(k)
    local answer = self.exchanges[k].answer
    if not answer then return 0 end
    local size = answer.agent_header_size
    for i, sec in ipairs(answer.sections) do
        if i > 1 then
            size = size + MARGIN  -- margin between sections
        end
        size = size + sec.size
    end
    return size
end

--- Total size of exchange K (question + margin + answer).
function Model:exchange_total_size(k)
    local ex = self.exchanges[k]
    local size = ex.question_size
    if ex.answer then
        size = size + MARGIN  -- margin between question and answer
        size = size + self:answer_total_size(k)
    end
    return size
end

--- 0-indexed buffer line where exchange K's question starts.
function Model:exchange_start(k)
    local line = self.header_lines + MARGIN  -- after header + 1 margin
    for i = 1, k - 1 do
        line = line + self:exchange_total_size(i)
        line = line + MARGIN  -- margin between exchanges
    end
    return line
end

--- 0-indexed buffer line where exchange K's 🤖: header is.
function Model:answer_start(k)
    local ex = self.exchanges[k]
    return self:exchange_start(k) + ex.question_size + MARGIN
end

--- 0-indexed buffer line where section S of exchange K starts.
function Model:section_start(k, s)
    local line = self:answer_start(k) + self.exchanges[k].answer.agent_header_size
    for i = 1, s - 1 do
        line = line + self.exchanges[k].answer.sections[i].size
        line = line + MARGIN  -- margin between sections
    end
    return line
end

--- 0-indexed buffer line of the last line of section S.
function Model:section_end(k, s)
    return self:section_start(k, s) + self.exchanges[k].answer.sections[s].size - 1
end

--- 0-indexed buffer line where the NEXT section would be inserted.
--- If there are existing sections, this is after the last section + margin.
--- If no sections, this is right after the agent header.
function Model:answer_append_pos(k)
    local answer = self.exchanges[k].answer
    if not answer then return nil end
    local n = #answer.sections
    if n == 0 then
        return self:answer_start(k) + answer.agent_header_size
    end
    -- After last section + margin
    return self:section_end(k, n) + 1 + MARGIN
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
            model:create_answer(k)
            for _, sec in ipairs(ex.answer.sections or {}) do
                local sec_size = 1
                if sec.line_start and sec.line_end then
                    sec_size = sec.line_end - sec.line_start + 1
                end
                model:add_section(k, sec.kind or sec.type or "text", sec_size)
            end
        end
    end
    return model
end

return M
