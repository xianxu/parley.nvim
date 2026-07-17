-- Chat buffer folding for parley.
--
-- Uses the exchange_model to compute fold regions. Each answer block
-- (🧠:, text, 🔧:, 📎:, 📝:) gets its own fold. Questions and
-- agent headers are never folded.
--
-- foldmethod=manual — folds are created explicitly from model positions.
-- No foldexpr evaluation, no backward scanning.

local M = {}

-- Block kinds that should be folded
local FOLDABLE = {
    thinking = true,
    summary = true,
    tool_use = true,
    tool_result = true,
}

--- Recreate one manual fold for a semantic model block after its range changes.
--- Returns false without touching Neovim fold state for non-foldable blocks.
function M._apply_block_fold(buf, win, model, exchange_index, block_index)
    if not vim.api.nvim_buf_is_valid(buf) then return false end
    if not win then
        win = (vim.fn.win_findbuf(buf) or {})[1]
    end
    if not win or not vim.api.nvim_win_is_valid(win) then return false end
    local block = model.exchanges[exchange_index] and model.exchanges[exchange_index].blocks[block_index]
    if not block or not FOLDABLE[block.kind] or block.size <= 0 then return false end

    local start_0 = model:block_start(exchange_index, block_index)
    local end_exclusive = model:block_end(exchange_index, block_index) + 1
    vim.api.nvim_win_call(win, function()
        vim.api.nvim_set_option_value("foldminlines", 0, { win = win })
        pcall(vim.cmd, string.format("%d,%dfold", start_0 + 1, end_exclusive))
    end)
    return true
end

function M._is_foldable(kind)
    return FOLDABLE[kind] == true
end

--- Compute and apply folds from the exchange model.
--- @param buf integer
function M.apply_folds(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return end

    local chat_parser = require("parley.chat_parser")
    local exchange_model = require("parley.exchange_model")
    local cfg = require("parley.config")
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local header_end = chat_parser.find_header_end(lines)
    if not header_end then return end
    local parsed = chat_parser.parse_chat(lines, header_end, cfg)
    local model = exchange_model.from_parsed_chat(parsed)

    local windows = vim.fn.win_findbuf(buf)
    for k, ex in ipairs(model.exchanges) do
        for b in ipairs(ex.blocks) do
            for _, target_win in ipairs(windows) do
                M._apply_block_fold(buf, target_win, model, k, b)
            end
        end
    end
end

--- Custom fold text.
function M.foldtext()
    local start_line = vim.fn.getline(vim.v.foldstart)
    local line_count = vim.v.foldend - vim.v.foldstart + 1

    if start_line:match("^🔧:") then
        local name = start_line:match("^🔧:%s*(%S+)") or "tool"
        return string.format("🔧 %s (%d lines) ", name, line_count)
    elseif start_line:match("^📎:") then
        local name = start_line:match("^📎:%s*(%S+)") or "result"
        local is_error = start_line:match("error=true") and " error" or ""
        return string.format("📎 %s%s (%d lines) ", name, is_error, line_count)
    elseif start_line:match("^🧠:") then
        return "🧠 thinking (" .. line_count .. " lines) "
    elseif start_line:match("^📝:") then
        return "📝 summary (" .. line_count .. " lines) "
    else
        local preview = start_line:sub(1, 60)
        if #start_line > 60 then preview = preview .. "..." end
        return preview .. " (" .. line_count .. " lines) "
    end
end

--- Set up folding on a chat buffer.
function M.setup(buf)
    vim.api.nvim_set_option_value("foldmethod", "manual", { win = 0 })
    vim.api.nvim_set_option_value("foldtext", "v:lua.require('parley.tool_folds').foldtext()", { win = 0 })
    vim.api.nvim_set_option_value("foldcolumn", "1", { win = 0 })
    vim.api.nvim_set_option_value("foldminlines", 0, { win = 0 })
    -- Apply folds from the model
    vim.schedule(function()
        M.apply_folds(buf)
    end)
end

return M
