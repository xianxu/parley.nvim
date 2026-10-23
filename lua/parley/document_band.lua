-- One window surface for edit turns, admission and submission feedback.
-- Owners retain state selection; temporary views unwind to live underlying
-- views, and a window changing buffers retires its previous ownership.
local M = {}
local windows, cached, pulses = {}, {}, {}
M.PULSE_MS = 150
local options = { "winbar", "winhighlight" }
local composition = require("parley.document_band_model")
local text_ops = require("parley.display_text")

local function trail_for(win)
    local history = package.loaded["parley.file_history"]
    return history and history.display and history.display(win) or nil
end

local function value_for(win, record, depth)
    depth = depth or #record.layers
    local top = record.layers[depth]
    local view = top and top.raw or { state = "plain", hl = "WinBar" }
    if view.overlay then
        local highlight = view.hl
        for i = depth - 1, 1, -1 do
            local underlying = record.layers[i].raw
            if underlying.state and not underlying.overlay then
                local feedback = view.feedback
                view = vim.deepcopy(underlying)
                view.feedback = feedback
                if top.priority then view.hl = highlight end
                break
            end
        end
    end
    return composition.compose(view, trail_for(win), vim.api.nvim_win_get_width(win), text_ops)
end

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

-- A prepared record has no installed proof. Once installed, each option is
-- retained only while the window still contains our last value; an override
-- relinquishes that option for this record's lifetime, including later paints.
local function install(win, record, target, first_paint)
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= record.buf then return end
    local previous, installed = record.installed, {}
    for _, option in ipairs(options) do
        local opts = { win = win, scope = "local" }
        if (not previous and first_paint)
            or (previous and previous[option] ~= nil and vim.api.nvim_get_option_value(option, opts) == previous[option]) then
            vim.api.nvim_set_option_value(option, target[option], opts)
            installed[option] = target[option]
        end
    end
    record.installed = installed
end

local function retire(win, record, remember)
    if remember and vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(record.buf) then
        cached[win] = cached[win] or {}
        cached[win][record.buf] = { buf = record.buf, before = record.before, installed = record.installed }
    end
    install(win, record, record.before)
    for _, owner in ipairs(record.layers) do owner.views[win] = nil end
    windows[win] = nil
end

local function restore_cached(win, buf)
    local saved = cached[win] and cached[win][buf]
    if not saved then return end
    install(win, saved, saved.before)
    cached[win][buf] = nil
    if not next(cached[win]) then cached[win] = nil end
end

-- Neovim may cache a rendered value before BufWinLeave. Retain only the
-- restoration proof for that live window/buffer pair until re-entry, wipe or
-- window close. Consume it before any owner captures a new original value.
local group = vim.api.nvim_create_augroup("ParleyDocumentBand", { clear = true })
vim.api.nvim_create_autocmd("BufWinLeave", { group = group, callback = function(event)
    local win = vim.api.nvim_get_current_win()
    if pulses[win] and pulses[win].buf == event.buf then pulses[win].cancel() end
    local record = windows[win]
    if record and record.buf == event.buf then retire(win, record, true) end
end })
vim.api.nvim_create_autocmd("BufWinEnter", { group = group, callback = function(event)
    restore_cached(vim.api.nvim_get_current_win(), event.buf)
    M.refresh(vim.api.nvim_get_current_win())
end })
-- A new split can clone a transient frame; restore only that new copy's proof.
vim.api.nvim_create_autocmd("WinNew", { group = group, callback = function()
    for win, pulse in pairs(pulses) do
        local record = windows[win]
        for _, created in ipairs(vim.api.nvim_list_wins()) do
            if pulse.seen and not pulse.seen[created] then
                pulse.seen[created] = true
                local top = record and record.layers[#record.layers]
                if top and top.priority then
                    local copy = { buf = record.buf, before = record.before,
                        installed = record.installed, layers = {} }
                    -- Buffer-wide state owners also own this native split.
                    -- Install that ownership before history's first repaint;
                    -- the source window's transient pulse remains scoped there.
                    for _, layer in ipairs(record.layers) do
                        if not layer.priority and not layer.only_win then
                            copy.layers[#copy.layers + 1] = layer
                            layer.views[created] = true
                        end
                    end
                    local beneath = value_for(created, copy)
                    install(created, copy, beneath.winbar and beneath or record.before)
                    if #copy.layers > 0 then windows[created] = copy end
                end
            end
        end
    end
end })
vim.api.nvim_create_autocmd("WinClosed", { group = group, callback = function(event)
    local win = tonumber(event.match)
    if pulses[win] then pulses[win].cancel() end
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

local function record_for(win, buf)
    restore_cached(win, buf)
    local record = windows[win]
    if record and record.buf ~= buf then retire(win, record, true); record = nil end
    if not record then
        record = { buf = buf, before = read(win), layers = {} }
        windows[win] = record
    end
    return record
end

function M.refresh(win)
    win = (not win or win == 0) and vim.api.nvim_get_current_win() or win
    if not vim.api.nvim_win_is_valid(win) then return end
    local buf, record = vim.api.nvim_win_get_buf(win), windows[win]
    if not require("parley.helper").is_editing_window(win) then
        if record then retire(win, record) end
        -- API floats can copy a source window's installed pixels. Only undo
        -- options whose exact installation proof still matches that copy.
        for source, original in pairs(windows) do
            if source ~= win and original.buf == buf then
                install(win, { buf = buf, installed = original.installed }, original.before)
            end
        end
        return
    end
    if record and record.buf ~= buf then retire(win, record, true); record = nil end
    local trail = trail_for(win)
    if not record and not require("parley.breadcrumb_model").visible(trail) then return end
    record = record or record_for(win, buf)
    local value = value_for(win, record)
    if not value.winbar then retire(win, record); return end
    install(win, record, value, true)
    for _, owner in ipairs(record.layers) do owner.views[win] = value end
end

vim.api.nvim_create_autocmd("WinResized", { group = group, callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do M.refresh(win) end
end })

function M.new(buf, only_win, priority)
    local owner = { views = {}, priority = priority, only_win = only_win }
    local handle = {}

    function handle.render(view)
        if only_win and (not vim.api.nvim_win_is_valid(only_win) or vim.api.nvim_win_get_buf(only_win) ~= buf) then return end
        owner.raw = vim.deepcopy(view)
        for win in pairs(owner.views) do
            if not vim.api.nvim_win_is_valid(win) and windows[win] then retire(win, windows[win]) end
        end
        for _, win in ipairs(only_win and { only_win } or vim.fn.win_findbuf(buf)) do
            local record = record_for(win, buf)
            remove(record, owner)
            local index = #record.layers + 1
            if not owner.priority then
                for i, layer in ipairs(record.layers) do
                    if layer.priority or (not owner.raw.overlay and layer.raw.overlay) then index = i; break end
                end
            end
            table.insert(record.layers, index, owner)
            owner.views[win] = true
            M.refresh(win)
        end
    end

    function handle.clear()
        for win in pairs(owner.views) do
            local record = windows[win]
            if record then
                remove(record, owner)
                local value = value_for(win, record)
                local target = value.winbar and value or record.before
                install(win, record, target)
                if not value.winbar then windows[win] = nil end
            end
            owner.views[win] = nil
        end
    end

    return handle
end

-- The lease coalesces native events and owns one finite window pulse.
local function start_pulse(win, source, active, label, message, leaving)
    if pulses[win] and pulses[win].source == source then return end
    if pulses[win] then pulses[win].cancel() end
    local pulse = { source = source }
    function pulse.cancel()
        if pulses[win] ~= pulse then return end
        if pulse.timer then pulse.timer:stop(); pulse.timer:close() end
        if pulse.owner then pulse.owner.clear() end
        pulses[win] = nil
    end
    pulses[win] = pulse
    vim.schedule(function()
        if pulses[win] ~= pulse then return end
        if not vim.api.nvim_win_is_valid(win) or not active() then pulse.cancel(); return end
        if leaving and vim.api.nvim_get_current_win() == win and vim.api.nvim_win_get_buf(win) == source then
            pulse.cancel(); return
        end
        pulse.buf, pulse.expected, pulse.seen = vim.api.nvim_win_get_buf(win), read(win), {}
        for _, known in ipairs(vim.api.nvim_list_wins()) do pulse.seen[known] = true end
        pulse.owner = M.new(pulse.buf, win, true)
        if message then vim.notify(message, vim.log.levels.WARN) end
        local step = 0
        pulse.timer = vim.uv.new_timer()
        pulse.timer:start(0, M.PULSE_MS, vim.schedule_wrap(function()
            if pulses[win] ~= pulse then return end
            if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= pulse.buf or not active() then
                pulse.cancel(); return
            end
            local record = windows[win]
            if not vim.deep_equal(read(win), record and record.installed or pulse.expected) then pulse.cancel(); return end
            step = step + 1
            if step % 2 == 1 then
                pulse.owner.render({ overlay = true, state = "plain", hl = "ParleySessionSyncLeave",
                    feedback = { label = label, hl = "ParleySessionSyncLeave" } })
            else pulse.owner.clear() end
            pulse.expected = read(win)
            if step == 6 then pulse.cancel() end
        end))
    end)
end

function M.flash(win, source, active)
    local name = vim.api.nvim_buf_get_name(source)
    start_pulse(win, source, active,
        literal("unsubmitted: Alt+Return to submit — " .. vim.fn.fnamemodify(name, ":t")),
        ("unsubmitted: Alt+Return to submit — " .. name):gsub("%c", " "), true)
end

-- Quiet, window-local feedback also owns a transient bar when none exists.
function M.flash_notice(win, label)
    local buf = vim.api.nvim_win_get_buf(win)
    start_pulse(win, buf, function()
        return vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf
    end, literal(label))
end

return M
