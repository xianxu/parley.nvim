-- First-run coordination over the existing proxy login and agent-picker owners.
local M = {}
local started = setmetatable({}, {__mode = 'k'})
local connecting = setmetatable({}, {__mode = 'k'})
local labels = {'Claude', 'Codex', 'Gemini'}
local logins = {'claude', 'codex', 'google'}

local function selected(parley)
    local name = (parley._state or {}).agent
    local agent = (parley.agents or {})[name]
    if agent and agent.placeholder then return false end
    local model = agent and agent.model
    if type(model) == 'table' then model = model.model end
    return type(model) == 'string' and model ~= '' and model ~= 'choose-a-model'
end

local function notify(message)
    vim.schedule(function() vim.notify(tostring(message), vim.log.levels.ERROR) end)
end

local function picker(parley, provider, on_ready, on_cancel)
    vim.schedule(function()
        parley.agent_picker.agent_picker(parley, {
            provider = provider, on_select = on_ready, on_cancel = on_cancel,
        })
    end)
end

--- Explicit Connect remains usable headlessly for scripted login and tests.
--- Startup alone is guarded against opening UI without an attached client.
function M.connect(parley, on_ready, on_cancel)
    parley = parley or require('parley')
    if connecting[parley] then
        if on_cancel then on_cancel('Account connection is already open') end
        return
    end
    connecting[parley] = true
    local proxy = require('parley.cliproxy')
    local function fail(message)
        connecting[parley] = nil
        notify(message)
        if on_cancel then on_cancel(message) end
    end
    local items = {}
    for index, login in ipairs(logins) do
        items[#items + 1] = { value = login, display = labels[index], search_text = labels[index] }
    end
    return require('parley.float_picker').open({
        title = 'Connect your account',
        anchor = 'top',
        items = items,
        recall_key = 'parley.provider_picker',
        on_cancel = function()
            connecting[parley] = nil
            if on_cancel then on_cancel('Account selection cancelled') end
        end,
        on_select = function(item)
            local login = item and item.value
            if not login then connecting[parley] = nil; return end
            proxy.ensure_running(function()
                vim.schedule(function()
                    local argv, err = proxy.login_argv(login)
                    if not argv then return fail(err) end
                    local blocked = proxy.callback_port_blocked(login)
                    if blocked then return fail(blocked) end
                    proxy.run_login(login, argv, function(ok)
                        connecting[parley] = nil
                        if ok then
                            picker(parley, login, on_ready, on_cancel)
                        elseif on_cancel then
                            on_cancel('Account login did not complete')
                        end
                    end)
                end)
            end, fail)
        end,
    })
end

--- Resolve account and model setup before a pending LLM action is prepared.
function M.ensure_ready(parley, on_ready, on_cancel)
    local proxy = require('parley.cliproxy')
    local function connect()
        return M.connect(parley, on_ready, on_cancel)
    end
    if not proxy.discover_binary() then return M.connect(parley, on_ready, on_cancel) end
    proxy.ensure_running(function()
        local available
        local agent = (parley.agents or {})[(parley._state or {}).agent]
        local model = agent and agent.model
        if type(model) == 'table' then model = model.model end
        local function check(index)
            local login = logins[index]
            if not login then
                if available then return picker(parley, available, on_ready, on_cancel) end
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
                        available = available or login
                        if not selected(parley) then
                            return picker(parley, login, on_ready, on_cancel)
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
