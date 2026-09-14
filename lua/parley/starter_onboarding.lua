-- First-run coordination over the existing proxy login and agent-picker owners.
local M = {}
local started = setmetatable({}, {__mode = 'k'})
local connecting = setmetatable({}, {__mode = 'k'})

local function selected(parley)
    local name = (parley._state or {}).agent
    local agent = (parley.agents or {})[name]
    if agent and agent.placeholder then return false end
    local model = agent and agent.model
    if type(model) == 'table' then model = model.model end
    return type(model) == 'string' and model ~= '' and model ~= 'choose-a-model'
end

--- All connection and model choices use the ordinary ParleyAgent picker.
function M.connect(parley, on_ready, on_cancel)
    parley = parley or require('parley')
    if connecting[parley] then
        if on_cancel then on_cancel('Account connection is already open') end
        return
    end
    connecting[parley] = true
    vim.schedule(function()
        local ok, err = pcall(parley.agent_picker.agent_picker, parley, {
            on_select = function(...)
                connecting[parley] = nil
                if on_ready then on_ready(...) end
            end,
            on_cancel = function(reason)
                connecting[parley] = nil
                if on_cancel then on_cancel(reason or 'Agent selection cancelled') end
            end,
        })
        if not ok then
            connecting[parley] = nil
            if on_cancel then on_cancel(tostring(err)) end
        end
    end)
end

--- Resolve account and model setup before a pending LLM action is prepared.
function M.ensure_ready(parley, on_ready, on_cancel)
    local agent = (parley.agents or {})[(parley._state or {}).agent]
    if not selected(parley) then return M.connect(parley, on_ready, on_cancel) end
    if agent.provider ~= 'cliproxyapi' then
        if on_ready then on_ready() end
        return
    end
    local proxy = require('parley.cliproxy')
    local logins = proxy.login_providers()
    local function connect()
        return M.connect(parley, on_ready, on_cancel)
    end
    if not proxy.discover_binary() then return M.connect(parley, on_ready, on_cancel) end
    proxy.ensure_running(function()
        local model = agent and agent.model
        if type(model) == 'table' then model = model.model end
        local function check(index)
            local login = logins[index]
            if not login then
                return M.connect(parley, on_ready, on_cancel)
            end
            proxy.credential_health_for_login(login, function(health)
                -- An unavailable management check does not prove there are no
                -- usable models. Try the catalog before offering connection.
                if health and health.state ~= 'healthy' and health.state ~= 'unknown' then
                    return check(index + 1)
                end
                proxy.list_models(login, function(models, err)
                    if not err and models and #models > 0 then
                        if selected(parley) and vim.tbl_contains(models, model) then
                            if on_ready then on_ready() end
                            return
                        end
                    end
                    check(index + 1)
                end)
            end)
        end
        check(1)
    end, connect)
end

--- Called once after interactive starter boot. Never retries cancellation.
function M.start(parley)
    if #vim.api.nvim_list_uis() == 0 or selected(parley) or started[parley] then return end
    started[parley] = true
    vim.schedule(function() M.ensure_ready(parley) end)
end

return M
