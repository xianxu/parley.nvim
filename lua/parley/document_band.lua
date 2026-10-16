-- One window surface for edit turns, admission and submission feedback.
-- Owners retain state selection; temporary views unwind to live underlying
-- views, and a window changing buffers retires its previous ownership.
local M = {}
local windows, cached = {}, {}
local options = { "winbar", "winhighlight" }

local function literal(message)
    local label = type(message) == "string" and message or tostring(message or "")
    return vim.fn.strcharpart(label:gsub("[\r\n]+", " "):gsub("%c", " "), 0, 160)
end

function M.feedback_view(message, is_error)
    return { label = literal(message), hl = is_error and "DiagnosticError" or "DiagnosticOk" }
end

local function read(win)
    local result = {}
    for _, option in ipairs(options) do
        result[option] = vim.api.nvim_get_option_value(option, { win = win, scope = "local" })
    end
    return result
end

local function restore(win, record, target)
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= record.buf then return end
    for _, option in ipairs(options) do
        local opts = { win = win, scope = "local" }
        if vim.api.nvim_get_option_value(option, opts) == record.installed[option] then
            vim.api.nvim_set_option_value(option, target[option], opts)
        end
    end
end

local function retire(win, record, remember)
    if remember and vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(record.buf) then
        cached[win] = cached[win] or {}
        cached[win][record.buf] = { buf = record.buf, before = record.before, installed = record.installed }
    end
    restore(win, record, record.before)
    for _, owner in ipairs(record.layers) do owner.views[win] = nil end
    windows[win] = nil
end

local function restore_cached(win, buf)
    local saved = cached[win] and cached[win][buf]
    if not saved then return end
    restore(win, saved, saved.before)
    cached[win][buf] = nil
    if not next(cached[win]) then cached[win] = nil end
end

-- Neovim may cache a rendered value before BufWinLeave. Retain only the
-- restoration proof for that live window/buffer pair until re-entry, wipe or
-- window close. Consume it before any owner captures a new original value.
local group = vim.api.nvim_create_augroup("ParleyDocumentBand", { clear = true })
vim.api.nvim_create_autocmd("BufWinLeave", { group = group, callback = function(event)
    local win = vim.api.nvim_get_current_win()
    local record = windows[win]
    if record and record.buf == event.buf then retire(win, record, true) end
end })
vim.api.nvim_create_autocmd("BufWinEnter", { group = group, callback = function(event)
    restore_cached(vim.api.nvim_get_current_win(), event.buf)
end })
vim.api.nvim_create_autocmd("WinClosed", { group = group, callback = function(event)
    local win = tonumber(event.match)
    if windows[win] then retire(win, windows[win]) end
    cached[win] = nil
end })
vim.api.nvim_create_autocmd("BufWipeout", { group = group, callback = function(event)
    for win, entries in pairs(cached) do
        entries[event.buf] = nil
        if not next(entries) then cached[win] = nil end
    end
end })

local function remove(record, owner)
    for i, layer in ipairs(record.layers) do
        if layer == owner then table.remove(record.layers, i); return end
    end
end

function M.new(buf)
    local owner = { views = {} }
    local handle = {}

    function handle.render(view)
        local value = { winbar = "%#" .. view.hl .. "# " .. view.label:gsub("%%", "%%%%") .. "%=",
            winhighlight = "StatusLine:" .. view.hl }
        for win in pairs(owner.views) do
            if not vim.api.nvim_win_is_valid(win) then retire(win, windows[win]) end
        end
        for _, win in ipairs(vim.fn.win_findbuf(buf)) do
            restore_cached(win, buf)
            local record = windows[win]
            if record and record.buf ~= buf then retire(win, record, true); record = nil end
            if not record then
                record = { buf = buf, before = read(win), layers = {} }
                windows[win] = record
            end
            remove(record, owner)
            record.layers[#record.layers + 1] = owner
            owner.views[win], record.installed = value, value
            for _, option in ipairs(options) do
                vim.api.nvim_set_option_value(option, value[option], { win = win, scope = "local" })
            end
        end
    end

    function handle.clear()
        for win in pairs(owner.views) do
            local record = windows[win]
            if record then
                local top = record.layers[#record.layers] == owner
                remove(record, owner)
                local next_owner = record.layers[#record.layers]
                if top then
                    local target = next_owner and next_owner.views[win] or record.before
                    restore(win, record, target)
                    record.installed = target
                end
                if not next_owner then windows[win] = nil end
            end
            owner.views[win] = nil
        end
    end

    return handle
end

return M
