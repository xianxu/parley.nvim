describe('agent picker continuation options', function()
    local picker, widget, proxy, saved, captured, plugin, rows
    before_each(function()
        picker, widget, proxy = require('parley.agent_picker'), require('parley.float_picker'), require('parley.cliproxy')
        saved = {open = widget.open, cached = proxy.catalog_cached, stale = proxy.catalog_stale}
        rows = {
            {id = 'gpt-5-codex', owner = 'openai', display = 'GPT', series = 'gpt'},
            {id = 'claude-sonnet-4-6', owner = 'anthropic', display = 'Claude', series = 'claude'},
            {id = 'gpt-4.1', owner = 'openai', display = 'GPT 4', series = 'gpt-old'},
        }
        proxy.catalog_cached = function() return rows end
        proxy.catalog_stale = function() return false end
        widget.open = function(opts)
            captured = opts
            return {update = function(items) captured.items = items end, selected = function() end,
                set_title = function() end, is_closed = function() return false end}
        end
        plugin = {_agents = {'Configured GPT', 'Configured Claude', 'Direct GPT'}, agents = {
            ['Configured GPT'] = {provider = 'cliproxyapi', model = 'gpt-5-codex'},
            ['Configured Claude'] = {provider = 'cliproxyapi', model = 'claude-sonnet-4-6'},
            ['Direct GPT'] = {provider = 'openai', model = 'gpt-5-codex'},
        }, _state = {}, logger = {info = function() end}, cmd = {KeyBindings = function() end},
            config = {cliproxy = {live_models = {providers = {'claude', 'codex'}, per_provider = 1}}}}
        plugin.refresh_state = function(state) plugin._state = state end
        plugin.register_live_agent = function(model)
            local agent = require('parley.cliproxy_catalog').build_agent(model)
            plugin.agents[agent.name], plugin._state.agent = agent, agent.name
        end
    end)
    after_each(function()
        widget.open, proxy.catalog_cached, proxy.catalog_stale = saved.open, saved.cached, saved.stale
    end)
    it('calls on_select with the applied configured agent and source row', function()
        local seen
        picker.agent_picker(plugin, {on_select = function(agent, item)
            assert.equals(item.name, plugin._state.agent)
            seen = agent
        end})
        captured.on_select({kind = 'agent', name = 'Configured GPT'})
        assert.equals(plugin.agents['Configured GPT'], seen)
    end)
    it('calls on_select after registering a live model and forwards cancellation', function()
        local selected, cancelled = 0, 0
        picker.agent_picker(plugin, {on_select = function(agent)
            assert.equals(agent, plugin.agents[plugin._state.agent]); selected = selected + 1
        end, on_cancel = function() cancelled = cancelled + 1 end})
        captured.on_select({kind = 'live', name = 'gpt-4.1*', model = rows[3]})
        assert.equals(1, selected)
        captured.on_cancel()
        assert.equals(1, cancelled)
    end)
    it('never treats separator and login rows as a completed model selection', function()
        local selected = 0
        picker.agent_picker(plugin, {on_select = function() selected = selected + 1 end})
        captured.on_select({kind = 'separator'})
        local original = vim.schedule
        vim.schedule = function() end -- login dispatch belongs to the existing command owner
        captured.on_select({kind = 'login', provider = 'codex'})
        vim.schedule = original
        assert.equals(0, selected)
    end)
    it('continues login into the same picker without cancelling the pending action', function()
        local original = {ensure_running = proxy.ensure_running, login_argv = proxy.login_argv,
            callback_port_blocked = proxy.callback_port_blocked, run_login = proxy.run_login}
        local finish, selected, cancelled = nil, 0, 0
        proxy.ensure_running = function(done) done() end
        proxy.login_argv = function() return {'fake'} end
        proxy.callback_port_blocked = function() end
        proxy.run_login = function(_, _, done) finish = done end
        picker.agent_picker(plugin, {on_select = function() selected = selected + 1 end,
            on_cancel = function() cancelled = cancelled + 1 end})
        local initial = captured
        captured.on_select({kind = 'login', provider = 'codex'})
        vim.wait(30, function() return finish ~= nil end, 1)
        local got_finish = finish ~= nil
        if finish then finish(true) end
        vim.wait(30, function() return captured ~= initial end, 1)
        for key, value in pairs(original) do proxy[key] = value end
        assert.is_true(got_finish)
        assert.equals(0, cancelled)
        assert.is_not_equal(initial, captured)
        captured.on_select({kind = 'agent', name = 'Configured GPT'})
        assert.equals(1, selected)
    end)

    it('cancels pending readiness when login fails without reopening', function()
        local original = {ensure_running = proxy.ensure_running, login_argv = proxy.login_argv,
            callback_port_blocked = proxy.callback_port_blocked, run_login = proxy.run_login}
        local cancelled = 0
        proxy.ensure_running = function(done) done() end
        proxy.login_argv = function() return {'fake'} end
        proxy.callback_port_blocked = function() end
        proxy.run_login = function(_, _, done) done(false) end
        picker.agent_picker(plugin, {on_cancel = function() cancelled = cancelled + 1 end})
        local initial = captured
        captured.on_select({kind = 'login', provider = 'codex'})
        vim.wait(30, function() return cancelled > 0 end, 1)
        for key, value in pairs(original) do proxy[key] = value end
        assert.equals(1, cancelled)
        assert.equals(initial, captured)
    end)

    it('scopes configured and live rows to a provider without mutating config, including expansion', function()
        local before = vim.deepcopy(plugin.config)
        picker.agent_picker(plugin, {provider = 'codex'})
        local function check()
            for _, item in ipairs(captured.items) do
                assert.is_not_equal('Configured Claude', item.name)
                assert.is_not_equal('Direct GPT', item.name)
                if item.kind == 'live' then assert.equals('openai', item.model.owner) end
                if item.kind == 'login' then assert.equals('codex', item.provider) end
            end
        end
        check()
        captured.mappings[#captured.mappings].fn()
        check()
        assert.same(before, plugin.config)
        assert.equals(3, #plugin._agents)
    end)
end)
