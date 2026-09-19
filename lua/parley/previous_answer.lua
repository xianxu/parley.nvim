-- The previous answer of an exchange being regenerated (#261, #255), and its
-- substitution into a parsed chat for request context. Pure: the document
-- coordinator holds the value and decides whether it is still valid
-- (document/init.lua previous_answers); this module shapes and applies it.
local M = {}

--- What request context reads of an exchange's answer, or nil without one.
---@param exchange table|nil # a parsed exchange
---@return table|nil
function M.capture(exchange)
    if not exchange or not exchange.answer then return nil end
    return { answer = vim.deepcopy(exchange.answer), summary = vim.deepcopy(exchange.summary),
        reasoning = vim.deepcopy(exchange.reasoning) }
end

--- `parsed` with each entry's exchange carrying its previous answer: the same
--- table when there is nothing to substitute, else a copy. `entries` are
--- `{row = <0-based 💬: row>, value = <capture()>}`; `skip_index` is the exchange
--- being answered, whose own answer is never part of its input.
---@param parsed table
---@param entries table[]|nil
---@param skip_index integer|nil
---@return table
function M.substitute(parsed, entries, skip_index)
    if not entries or #entries == 0 then return parsed end
    local by_line = {}
    for _, entry in ipairs(entries) do by_line[entry.row + 1] = entry.value end
    local out = vim.deepcopy(parsed)
    for index, exchange in ipairs(out.exchanges) do
        local value = exchange.question and by_line[exchange.question.line_start]
        if value and index ~= skip_index then
            exchange.answer = vim.deepcopy(value.answer)
            -- build_messages includes an answer only when answer.line_start <=
            -- end_index (chat_respond.lua); the old answer's own line numbers
            -- belong to a transcript that no longer exists.
            exchange.answer.line_start = exchange.question.line_end + 1
            exchange.summary = vim.deepcopy(value.summary)
            exchange.reasoning = vim.deepcopy(value.reasoning)
        end
    end
    return out
end

return M
