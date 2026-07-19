-- Pure projection of semantic exchange blocks into buffer fold ranges.

local M = {}

local FOLDABLE = {
    thinking = true,
    summary = true,
    tool_use = true,
    tool_result = true,
}

function M.desired_folds(model, exchange_index)
    local exchange = model.exchanges[exchange_index]
    if not exchange then return {} end

    local ranges = {}
    local exchange_start_0 = model:exchange_start(exchange_index)
    local exchange_end_0 = model:last_nonempty_block_end(exchange_index)
    for block_index, block in ipairs(exchange.blocks) do
        if block.size > 0 and FOLDABLE[block.kind] then
            local start_0 = model:block_start(exchange_index, block_index)
            local end_0 = model:block_end(exchange_index, block_index)
            assert(start_0 >= exchange_start_0 and end_0 <= exchange_end_0,
                "fold range outside exchange bounds")
            ranges[#ranges + 1] = {
                block_index = block_index,
                kind = block.kind,
                start_0 = start_0,
                end_0 = end_0,
            }
        end
    end
    return ranges
end

return M
