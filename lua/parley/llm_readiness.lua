-- Coordinate opt-in first-use setup without losing the semantic action's
-- editor context. State is per parley instance and dies with that instance.
local once = require('parley.tasker').once

local M = {}
local active = setmetatable({}, {__mode = 'k'})
local grants = setmetatable({}, {__mode = 'k'})

local function selected(parley)
    local name = (parley._state or {}).agent
    local agent = (parley.agents or {})[name]
    if not agent or agent.placeholder then return false end
    local model = agent.model
    if type(model) == 'table' then model = model.model end
    return type(model) == 'string' and model ~= '' and model ~= 'choose-a-model'
end

local function cancel(opts, reason)
    if type(opts.on_cancel) == 'function' then
        opts.on_cancel(reason)
        return
    end
    vim.schedule(function()
        vim.notify('Parley: ' .. tostring(reason), vim.log.levels.WARN)
    end)
end

local function source_context(opts)
    local buf = opts.buf
    if buf == nil or buf == 0 then buf = vim.api.nvim_get_current_buf() end
    if not vim.api.nvim_buf_is_valid(buf) then
        return nil, 'the source buffer no longer exists'
    end
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_buf(win) ~= buf then
        win = nil
        for _, candidate in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(candidate) == buf then
                win = candidate
                break
            end
        end
    end
    if not win then
        return nil, 'the source buffer is not visible in a window'
    end
    return {
        buf = buf,
        win = win,
        cursor = vim.api.nvim_win_get_cursor(win),
        changedtick = vim.api.nvim_buf_get_changedtick(buf),
    }
end

local function source_problem(source)
    if not vim.api.nvim_buf_is_valid(source.buf) then
        return 'the source buffer no longer exists'
    end
    if vim.api.nvim_buf_get_changedtick(source.buf) ~= source.changedtick then
        return 'the source buffer changed while LLM setup was open'
    end
    if not vim.api.nvim_win_is_valid(source.win) then
        return 'the source window no longer exists'
    end
    if vim.api.nvim_win_get_buf(source.win) ~= source.buf then
        return 'the source window changed while LLM setup was open'
    end
end

--- Defer an LLM action until optional first-use setup completes.
--- Returns false only when the caller should continue the action immediately.
--- @param parley table
--- @param action function
--- @param opts? table { buf?: integer, on_cancel?: fun(reason: string) }
--- @return boolean deferred
function M.defer(parley, action, opts)
    opts = opts or {}
    if not parley or not parley.config or parley.config.llm_onboarding ~= true then
        return false
    end
    if grants[parley] then
        return false
    end
    if #vim.api.nvim_list_uis() == 0 then
        if selected(parley) then return false end
        cancel(opts, 'LLM setup is unavailable in headless mode')
        return true
    end
    if active[parley] then
        cancel(opts, 'LLM setup is already in progress')
        return true
    end

    local source, source_err = source_context(opts)
    if not source then
        cancel(opts, source_err)
        return true
    end

    active[parley] = true
    local callback_error
    local settle = once(function(kind, reason)
        active[parley] = nil
        if kind == 'cancel' then
            cancel(opts, reason or 'LLM setup was cancelled')
            return
        end
        local problem = source_problem(source)
        if problem then
            cancel(opts, problem)
            return
        end
        vim.api.nvim_set_current_win(source.win)
        vim.api.nvim_win_set_cursor(source.win, source.cursor)
        grants[parley] = true
        local ok, err = xpcall(action, debug.traceback)
        grants[parley] = nil
        if not ok then
            callback_error = err
            error(err, 0)
        end
    end)

    local ok, err = pcall(function()
        require('parley.starter_onboarding').ensure_ready(parley, function()
            settle('ready')
        end, function(reason)
            settle('cancel', reason)
        end)
    end)
    if not ok then
        if callback_error then error(callback_error, 0) end
        settle('cancel', 'could not start LLM setup: ' .. tostring(err))
    end
    return true
end

return M
