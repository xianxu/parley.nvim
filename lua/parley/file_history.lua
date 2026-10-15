-- File visits belong to windows, independent of the native cursor jumplist.
local M = {}
local model = require("parley.file_history_model")
local helpers = require("parley.helper")
local histories, restoring = {}, {}
local source_window

local function observation(win)
    if not helpers.is_editing_window(win) then return nil end
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype ~= "" or name == "" or name:match("^[%w+.-]+://")
        or vim.fn.isdirectory(name) == 1 then return nil end
    local pos = vim.api.nvim_win_get_cursor(win)
    return { path = vim.fn.resolve(name), cursor = { row = pos[1], col = pos[2] } }
end

local function observe(win, kind)
    local entry = not restoring[win] and observation(win)
    if entry then
        entry.kind = kind
        histories[win] = model.transition(histories[win], entry)
    end
    return entry
end

-- Buffer preparation must not reset mode or drain typeahead during Back.
function M.is_restoring(win)
    return restoring[win] == true
end

-- Repeated setup replaces handlers but preserves each live window's history.
function M.setup()
    local group = vim.api.nvim_create_augroup("ParleyFileHistory", { clear = true })
    vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, { group = group, callback = function()
        observe(vim.api.nvim_get_current_win(), "snapshot")
    end })
    vim.api.nvim_create_autocmd("WinNew", { group = group, callback = function()
        local win = vim.api.nvim_get_current_win()
        if helpers.is_editing_window(win) then
            -- An inactive API split fires WinNew in the child without WinLeave.
            if source_window then observe(source_window, "snapshot") end
            histories[win] = histories[source_window]
        end
    end })
    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, { group = group, callback = function(ev)
        local win = vim.api.nvim_get_current_win()
        observe(win, "visit")
        if ev.event == "WinEnter" and helpers.is_editing_window(win) then source_window = win end
    end })
    vim.api.nvim_create_autocmd("WinClosed", { group = group, callback = function(ev)
        local win = tonumber(ev.match)
        histories[win], restoring[win] = nil, nil
        if source_window == win then source_window = nil end
    end })
    for _, win in ipairs(vim.api.nvim_list_wins()) do observe(win, "visit") end
    local current = vim.api.nvim_get_current_win()
    if helpers.is_editing_window(current) then source_window = current end
end

-- Propose index changes first; commit only after a successful native switch.
function M.back()
    local win = vim.api.nvim_get_current_win()
    local origin = observe(win, "visit")
    if not origin then return false end
    local proposed, target = histories[win]
    while true do
        proposed, target = model.transition(proposed, { kind = "back" })
        if not target then return false end
        local loaded = vim.fn.bufloaded(target.path) == 1
        if target.path ~= origin.path and (loaded or vim.fn.filereadable(target.path) == 1) then
            restoring[win] = true
            local ok, problem = pcall(function()
                if loaded then
                    vim.cmd("buffer " .. vim.fn.bufnr(target.path))
                else
                    vim.cmd("edit " .. vim.fn.fnameescape(target.path))
                end
                local actual = observation(win)
                if not actual or actual.path ~= target.path then error("file target changed during navigation") end
                local buf = vim.api.nvim_win_get_buf(win)
                local row = math.min(target.cursor.row, vim.api.nvim_buf_line_count(buf))
                local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
                vim.api.nvim_win_set_cursor(win, { row, math.min(target.cursor.col, #line) })
            end)
            restoring[win] = nil
            if not ok then
                require("parley.logger").warning("File Back: " .. tostring(problem))
                return false
            end
            histories[win] = proposed
            observe(win, "snapshot")
            return true
        end
    end
end

return M
