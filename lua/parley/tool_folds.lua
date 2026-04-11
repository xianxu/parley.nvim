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
    tool_use = true,
    tool_result = true,
}

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

    -- Clear existing folds
    vim.cmd("normal! zE")

    -- Create a fold for each foldable block
    for k, ex in ipairs(model.exchanges) do
        for b, blk in ipairs(ex.blocks) do
            if FOLDABLE[blk.kind] and blk.size > 0 then
                local start_0 = model:block_start(k, b)
                local end_0 = model:block_end(k, b)
                -- Convert 0-indexed to 1-indexed for vim commands
                local start_1 = start_0 + 1
                local end_1 = end_0 + 1
                if start_1 <= #lines and end_1 <= #lines and start_1 <= end_1 then
                    pcall(vim.cmd, start_1 .. "," .. end_1 .. "fold")
                end
            end
        end
    end

    -- Close all folds
    pcall(vim.cmd, "normal! zM")
    -- Keep cursor visible
    pcall(vim.cmd, "normal! zv")
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
    -- Apply folds from the model
    vim.schedule(function()
        M.apply_folds(buf)
    end)
end

--- Reapply folds after tool_loop writes blocks.
function M.close_tool_folds(buf)
    vim.schedule(function()
        M.apply_folds(buf)
    end)
end

return M
