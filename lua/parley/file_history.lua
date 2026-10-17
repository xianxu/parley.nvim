-- File visits belong to windows, independent of the native cursor jumplist.
local M = {}
local model = require("parley.file_history_model")
local helpers = require("parley.helper")
local breadcrumb = require("parley.breadcrumb_model")
local histories, restoring, generations, presented = {}, {}, {}, {}
local origins = setmetatable({}, { __mode = "k" })
local departing_window

local function window(win)
    return (not win or win == 0) and vim.api.nvim_get_current_win() or win
end

local function repaint(win)
    local band = require("parley.document_band")
    if band and band.refresh then band.refresh(win) end
end

local function observation(win)
    if not vim.api.nvim_win_is_valid(win) then return nil end
    if not helpers.is_editing_window(win) then return nil end
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype ~= "" or name == "" or name:match("^[%w+.-]+://")
        or vim.fn.isdirectory(name) == 1 then return nil end
    local pos = vim.api.nvim_win_get_cursor(win)
    return { path = vim.fn.resolve(vim.fn.fnamemodify(name, ":p")), cursor = { row = pos[1], col = pos[2] } }
end

local function observe(win, kind)
    if restoring[win] then return nil end
    local entry = observation(win)
    local previous = presented[win]
    presented[win] = entry and { buf = vim.api.nvim_win_get_buf(win),
        name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) } or nil
    if entry then
        local history = histories[win]
        local current = history and history.entries[history.index]
        local changed = not current or current.path ~= entry.path
        entry.kind = kind
        if kind == "visit" and changed then
            entry.trail = breadcrumb.transition(nil, { kind = "root", path = entry.path })
            generations[win] = (generations[win] or 0) + 1
        end
        histories[win] = model.transition(history, entry)
        if kind == "visit" and (changed or not vim.deep_equal(previous, presented[win])) then repaint(win) end
    elseif previous then
        repaint(win)
    end
    return entry
end

-- Painting uses the committed observation proof, never filesystem observation.
-- Retained Back history alone is not evidence about the displayed buffer.
function M.peek(win)
    win = window(win)
    local proof = presented[win]
    if not proof or not helpers.is_editing_window(win)
        or vim.api.nvim_win_get_buf(win) ~= proof.buf or vim.bo[proof.buf].buftype ~= ""
        or vim.api.nvim_buf_get_name(proof.buf) ~= proof.name then
        return nil, "window does not display its observed file"
    end
    local history = histories[win]
    local current = history and history.entries[history.index]
    if not current or not current.trail then return nil, "window has no valid breadcrumb" end
    return breadcrumb.validate(current.trail)
end

-- Snapshots contain values only; observers and callers cannot share mutable paths.
function M.snapshot(win)
    win = window(win)
    local actual = observe(win, "visit")
    if not actual then return nil, "window does not display a file" end
    return M.peek(win)
end

function M.origin(win)
    win = window(win)
    local trail, reason = M.snapshot(win)
    if not trail then return nil, reason end
    local actual = observation(win)
    local history, cursors = histories[win], {}
    local before = history.index
    for i = #trail.paths, 1, -1 do
        cursors[i] = { row = 1, col = 0 }
        for j = before, 1, -1 do
            if history.entries[j].path == trail.paths[i] then
                cursors[i] = vim.deepcopy(history.entries[j].cursor)
                before = j - 1
                break
            end
        end
    end
    cursors[#trail.paths] = actual.cursor
    local token = {}
    origins[token] = { win = win, path = actual.path, generation = generations[win],
        trail = trail, cursors = cursors }
    return token
end

-- A permit is private to one successful opener; never leave one for BufEnter.
function M.follow(token, open_fn, expected_path)
    if token == nil then
        open_fn()
        return false, "navigation origin cannot supply a breadcrumb"
    end
    local origin = token and origins[token]
    if not origin then return false, "missing or consumed follow origin" end
    origins[token] = nil
    local actual = observe(origin.win, "visit")
    if not actual or actual.path ~= origin.path or generations[origin.win] ~= origin.generation then
        return false, "navigation origin changed"
    end
    open_fn()
    local destination = vim.api.nvim_get_current_win()
    local landed = observe(destination, "visit")
    if not landed then return false, "opener did not land on a file" end
    if expected_path and landed.path ~= vim.fn.resolve(vim.fn.fnamemodify(expected_path, ":p")) then
        return false, "file target changed during navigation"
    end
    if destination == origin.win and landed.path == origin.path then return true end
    local trail, reason = breadcrumb.transition(origin.trail, { kind = "follow", path = landed.path })
    if not trail then return false, reason end
    local cursors = {}
    -- Transition drops only interior visits; copy their retained positions,
    -- rather than matching path text that can recur with a different cursor.
    local appended = landed.path ~= origin.trail.paths[#origin.trail.paths] and 1 or 0
    local dropped = #origin.trail.paths + appended - #trail.paths
    for i = 1, #trail.paths - 1 do
        cursors[i] = origin.cursors[i == 1 and 1 or i + dropped]
    end
    cursors[#trail.paths] = landed.cursor
    histories[destination] = model.install_trail(histories[destination], trail, cursors)
    generations[destination] = (generations[destination] or 0) + 1
    repaint(destination)
    return true
end

-- Explicit restoration never navigates and only proven absence prunes ancestry.
function M.restore(win, value)
    win = window(win)
    local actual = observation(win)
    if not actual then return false, "window does not display a file" end
    local trail, reason = breadcrumb.validate(value, actual.path)
    if not trail then return false, reason end
    local paths = {}
    for i, path in ipairs(trail.paths) do
        if i == #trail.paths then
            paths[#paths + 1] = path
        else
            local stat, problem, code = (vim.uv or vim.loop).fs_stat(path)
            if stat and stat.type == "file" then
                paths[#paths + 1] = path
            elseif not stat and code ~= "ENOENT" and code ~= "ENOTDIR" then
                return false, "cannot inspect breadcrumb ancestor: " .. tostring(problem)
            elseif stat then
                return false, "breadcrumb ancestor is not a file"
            end
        end
    end
    trail.paths = paths
    if #paths == 1 then trail.omitted = 0 end
    local cursors = {}
    for i = 1, #paths do cursors[i] = { row = 1, col = 0 } end
    cursors[#paths] = actual.cursor
    observe(win, "visit")
    histories[win] = model.install_trail(histories[win], trail, cursors)
    generations[win] = (generations[win] or 0) + 1
    repaint(win)
    return true
end

-- Buffer preparation must not reset mode or drain typeahead during Back.
function M.is_restoring(win)
    return restoring[win] == true
end

-- Repeated setup replaces handlers but preserves each live window's history.
function M.setup()
    local group = vim.api.nvim_create_augroup("ParleyFileHistory", { clear = true })
    vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, { group = group, callback = function(ev)
        local win = vim.api.nvim_get_current_win()
        observe(win, "snapshot")
        if ev.event == "WinLeave" then departing_window = helpers.is_editing_window(win) and win or nil end
    end })
    vim.api.nvim_create_autocmd("WinNew", { group = group, callback = function()
        local win = vim.api.nvim_get_current_win()
        local parent = departing_window
        departing_window = nil
        if helpers.is_editing_window(win) then
            -- Native splits leave their focused source first; API creations do not.
            histories[win] = parent and histories[parent] or nil
        end
    end })
    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, { group = group, callback = function(ev)
        local win = vim.api.nvim_get_current_win()
        -- A fresh API window's WinEnter can still show a temporary clone.
        if ev.event == "BufEnter" or histories[win] then observe(win, "visit") end
        if ev.event == "WinEnter" then departing_window = nil end
    end })
    vim.api.nvim_create_autocmd("WinClosed", { group = group, callback = function(ev)
        local win = tonumber(ev.match)
        histories[win], restoring[win], generations[win], presented[win] = nil, nil, nil, nil
        if departing_window == win then departing_window = nil end
    end })
    for _, win in ipairs(vim.api.nvim_list_wins()) do observe(win, "visit") end
    departing_window = nil
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
        local loaded = helpers.buffer_for(target.path, true)
        if target.path ~= origin.path and (loaded or vim.fn.filereadable(target.path) == 1) then
            restoring[win] = true
            local ok, problem = pcall(function()
                if loaded then
                    vim.cmd("buffer " .. loaded)
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
            generations[win] = (generations[win] or 0) + 1
            repaint(win)
            return true
        end
    end
end

return M
