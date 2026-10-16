-- #233: the text a request takes from the tree's OTHER files (its ancestors
-- and asides), as one string, for specs that assert on what a fork inherits.
local M = {}

--- @param sequence table[] from chat_respond._tree_sequence
--- @return string[] each other-file exchange's question and answer content
function M.other_files(sequence)
    local out = {}
    for _, item in ipairs(sequence) do
        if not item.current then
            out[#out + 1] = tostring(item.exchange.question and item.exchange.question.content or "")
            out[#out + 1] = tostring(item.exchange.answer and item.exchange.answer.content or "")
        end
    end
    return out
end

return M
