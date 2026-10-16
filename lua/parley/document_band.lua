-- One window surface for edit turns, admission and submission feedback.
-- Owners retain state selection; temporary views unwind to live underlying
-- views, and a window changing buffers retires its previous ownership.
local M = {}
local windows = {}
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
    if not vim.api.nvim_win_is_valid(win) then return end
    for _, option in ipairs(options) do
        local opts = { win = win, scope = "local" }
        if vim.api.nvim_get_option_value(option, opts) == record.installed[option] then
            vim.api.nvim_set_option_value(option, target[option], opts)
        end
    end
end

local function retire(win, record)
    restore(win, record, record.before)
    for _, owner in ipairs(record.layers) do owner.views[win] = nil end
    windows[win] = nil
end

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
            local record = windows[win]
            if record and record.buf ~= buf then retire(win, record); record = nil end
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
