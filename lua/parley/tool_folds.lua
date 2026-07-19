-- Chat buffer folding for parley.
--
-- Uses a pure exchange-model projection to compute fold regions. Thinking,
-- summary, tool-use, and tool-result blocks fold; questions, ordinary answer
-- text, and agent headers do not.
--
-- foldmethod=manual — folds are created explicitly from model positions.
-- No foldexpr evaluation, no backward scanning.

local M = {}
local projection = require("parley.fold_projection")
local initialized = {}

local function valid_target(buf, win)
    return vim.api.nvim_buf_is_valid(buf)
        and vim.api.nvim_win_is_valid(win)
        and vim.api.nvim_win_get_buf(win) == buf
end

local function notify(event)
    if M._observer then M._observer(event) end
end

local function delete_projected_folds(buf, win, ranges)
    if not valid_target(buf, win) then return end
    vim.api.nvim_win_call(win, function()
        local cursor = vim.api.nvim_win_get_cursor(win)
        for index = #ranges, 1, -1 do
            local row = ranges[index].start_0 + 1
            vim.api.nvim_win_set_cursor(win, { row, 0 })
            while vim.fn.foldlevel(row) > 0 do
                vim.cmd("normal! zd")
            end
        end
        local line_count = vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_win_set_cursor(win, { math.min(cursor[1], line_count), cursor[2] })
    end)
end

function M.reconcile_exchange(buf, win, model, exchange_index)
    if not valid_target(buf, win) or not model.exchanges[exchange_index] then return false end
    local ranges = projection.desired_folds(model, exchange_index)
    vim.api.nvim_win_call(win, function()
        vim.api.nvim_set_option_value("foldminlines", 0, { win = win })
        for _, range in ipairs(ranges) do
            vim.cmd(string.format("%d,%dfold", range.start_0 + 1, range.end_0 + 1))
        end
    end)
    notify({ phase = "reconcile", win = win, exchange_index = exchange_index, ranges = ranges })
    return true
end

function M.prepare_exchange_update(buf, model, exchange_index)
    if not vim.api.nvim_buf_is_valid(buf) or not model.exchanges[exchange_index] then return {} end
    local ranges = projection.desired_folds(model, exchange_index)
    local windows = vim.fn.win_findbuf(buf) or {}
    for _, win in ipairs(windows) do
        if valid_target(buf, win) then
            delete_projected_folds(buf, win, ranges)
            notify({ phase = "prepare", win = win, exchange_index = exchange_index, ranges = ranges })
        end
    end
    return windows
end

function M.finalize_exchange_update(buf, windows, model, exchange_index)
    for _, win in ipairs(windows or {}) do
        M.reconcile_exchange(buf, win, model, exchange_index)
    end
end

local function default_model_provider(buf)
    local chat_parser = require("parley.chat_parser")
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local header_end = chat_parser.find_header_end(lines)
    if not header_end then return nil end
    local parsed = chat_parser.parse_chat(lines, header_end, require("parley.config"))
    return require("parley.exchange_model").from_parsed_chat(parsed)
end

function M.with_exchange_update(buf, model, exchange_index, mutate)
    local windows = M.prepare_exchange_update(buf, model, exchange_index)
    local result
    local ok, err = xpcall(function() result = mutate() end, debug.traceback)
    local final_model = model
    if not ok then
        local recovered, parsed = pcall(M._model_provider or default_model_provider, buf)
        final_model = recovered and parsed or nil
    end
    if ok then
        M.finalize_exchange_update(buf, windows, final_model, exchange_index)
    else
        if final_model then
            for _, win in ipairs(windows) do
                pcall(M.reconcile_exchange, buf, win, final_model, exchange_index)
            end
        end
        error(err, 0)
    end
    return result
end

--- Compute and apply folds from the exchange model.
--- @param buf integer
function M.apply_folds(buf, win, model_provider)
    if not vim.api.nvim_buf_is_valid(buf) then return false end
    local model = (model_provider or M._model_provider or default_model_provider)(buf)
    if not model then return false end
    local windows = win and { win } or vim.fn.win_findbuf(buf)
    for k in ipairs(model.exchanges) do
        for _, target_win in ipairs(windows) do
            M.reconcile_exchange(buf, target_win, model, k)
        end
    end
    return true
end

function M.hydrate_window(buf, win, model_provider)
    if not valid_target(buf, win) then return false end
    initialized[buf] = initialized[buf] or {}
    if initialized[buf][win] then return false end
    vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
    vim.api.nvim_set_option_value("foldtext", "v:lua.require('parley.tool_folds').foldtext()", { win = win })
    vim.api.nvim_set_option_value("foldcolumn", "1", { win = win })
    vim.api.nvim_set_option_value("foldminlines", 0, { win = win })
    local provider = model_provider or M._model_provider or default_model_provider
    local model = provider(buf)
    if not model then return false end
    vim.api.nvim_win_call(win, function()
        vim.cmd("normal! zE")
    end)
    for exchange_index in ipairs(model.exchanges) do
        M.reconcile_exchange(buf, win, model, exchange_index)
    end
    initialized[buf][win] = true
    return true
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
    local group = vim.api.nvim_create_augroup("ParleyToolFolds" .. buf, { clear = true })
    vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
        group = group,
        callback = function(args)
            if args.buf ~= buf then return end
            local target = vim.api.nvim_get_current_win()
            vim.schedule(function() M.hydrate_window(buf, target) end)
        end,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function(args)
            local closed = tonumber(args.match)
            if initialized[buf] then initialized[buf][closed] = nil end
        end,
    })
    vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
        group = group, buffer = buf,
        callback = function() initialized[buf] = nil end,
    })
    local win = vim.api.nvim_get_current_win()
    vim.schedule(function()
        M.hydrate_window(buf, win)
    end)
end

return M
