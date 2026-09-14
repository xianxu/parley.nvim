describe('starter onboarding', function()
    local onboarding, parley, proxy, state, saved
    before_each(function()
        saved = {proxy = package.loaded['parley.cliproxy'], uis = vim.api.nvim_list_uis,
            float_open = require('parley.float_picker').open, select = vim.ui.select, notify = vim.notify}
        package.loaded['parley.starter_onboarding'] = nil
        state = {prompts = 0, picks = 0, notices = {}, ensure = 0, health = {}, models = {}, binary = true}
        parley = {_state = {agent = 'Choose a model'},
            agents = {['Choose a model'] = {model = {model = 'choose-a-model'}}},
            agent_picker = {agent_picker = function(p, opts) assert.equals(parley, p); state.picks = state.picks + 1; state.model_picker = opts end}}
        proxy = {
            discover_binary = function() return state.binary and '/owned/proxy' or nil end,
            ensure_running = function(ok, fail)
                state.ensure = state.ensure + 1
                if state.ensure_error then fail(state.ensure_error) else ok() end
            end,
            credential_health_for_login = function(login, done)
                done(state.health[login] or {state = 'missing'})
            end,
            list_models = function(login, done) done(state.models[login] or {}, state.model_error) end,
            login_argv = function(login) return {'/owned/proxy', '-' .. login .. '-login'} end,
            callback_port_blocked = function() return state.blocked end,
            run_login = function(login, argv, done)
                state.login, state.argv, state.login_done = login, argv, done
            end,
        }
        package.loaded['parley.cliproxy'] = proxy
        vim.api.nvim_list_uis = function() return {{}} end
        require('parley.float_picker').open = function(opts)
            state.prompts = state.prompts + 1
            state.provider_picker = opts
            state.select_done = function(_, index)
                if index then opts.on_select(opts.items[index]) else opts.on_cancel() end
            end
        end
        vim.ui.select = function() error('provider selector must use the shared floating picker') end
        vim.notify = function(message) state.notices[#state.notices + 1] = message end
        onboarding = require('parley.starter_onboarding')
    end)
    after_each(function()
        package.loaded['parley.cliproxy'] = saved.proxy
        package.loaded['parley.starter_onboarding'] = nil
        vim.api.nvim_list_uis, vim.notify, vim.ui.select = saved.uis, saved.notify, saved.select
        require('parley.float_picker').open = saved.float_open
    end)
    local function settle() vim.wait(20, function() return false end, 1) end
    it('uses the shared floating picker with stable provider identities', function()
        onboarding.connect(parley)
        assert.equals('Connect your account', state.provider_picker.title)
        assert.equals('top', state.provider_picker.anchor)
        assert.same({'claude', 'codex', 'google'}, vim.tbl_map(function(row) return row.value end, state.provider_picker.items))
        state.select_done(nil, nil)
        onboarding.connect(parley)
        assert.equals(2, state.prompts)
    end)
    it('resumes only after a model is chosen from the available provider', function()
        state.health.codex, state.models.codex = {state = 'healthy'}, {'gpt-5-codex'}
        local ready = 0
        onboarding.ensure_ready(parley, function() ready = ready + 1 end)
        settle()
        assert.equals('codex', state.model_picker.provider)
        assert.equals(0, ready)
        state.model_picker.on_select()
        assert.equals(1, ready)
    end)
    it('accepts an available saved model without opening a picker', function()
        parley.agents[parley._state.agent].model = 'gpt-5-codex'
        state.health.codex, state.models.codex = {state = 'healthy'}, {'gpt-5-codex'}
        local ready = false
        onboarding.ensure_ready(parley, function() ready = true end)
        settle()
        assert.is_true(ready)
        assert.equals(0, state.picks)
        assert.equals(0, state.prompts)
    end)
    it('prompts to connect when a saved model has no healthy provider', function()
        parley.agents[parley._state.agent].model = 'gpt-5-codex'
        local cancelled
        onboarding.ensure_ready(parley, function() error('unexpected ready') end,
            function(reason) cancelled = reason end)
        settle()
        assert.equals(1, state.prompts)
        state.provider_picker.on_cancel()
        assert.is_string(cancelled)
    end)
    it('does nothing in headless startup', function()
        vim.api.nvim_list_uis = function() return {} end
        onboarding.start(parley)
        settle()
        assert.equals(0, state.ensure)
        assert.equals(0, state.prompts)
        assert.equals(0, state.picks)
    end)
    it('preserves real saved model choices in string and table form', function()
        for _, model in ipairs({'gpt-5-codex', {model = 'claude-sonnet-4-6'}}) do
            parley.agents[parley._state.agent].model = model
            onboarding.start(parley)
        end
        settle()
        assert.equals(0, state.ensure)
        assert.equals(0, state.picks)
    end)
    it('treats a flagged starter placeholder as unselected', function()
        parley.agents[parley._state.agent] = {model = 'onboarding', placeholder = true}
        state.binary = false
        onboarding.start(parley)
        settle()
        assert.equals(1, state.prompts)
    end)
    it('opens the existing picker once when a connected provider has models', function()
        state.health.codex, state.models.codex = {state = 'healthy'}, {'gpt-5-codex'}
        onboarding.start(parley)
        onboarding.start(parley)
        settle()
        assert.equals(1, state.picks)
        assert.equals(0, state.prompts)
    end)
    it('offers Connect without downloading when no managed binary exists and stops on cancel', function()
        state.binary = false
        onboarding.start(parley)
        settle()
        assert.equals(1, state.prompts)
        assert.equals(0, state.ensure)
        state.select_done(nil, nil)
        onboarding.start(parley)
        settle()
        assert.equals(1, state.prompts)
    end)
    it('offers Connect when no connected provider or usable models exist', function()
        state.health.codex = {state = 'healthy'}
        onboarding.start(parley)
        settle()
        assert.equals(1, state.prompts)
        assert.equals(0, state.picks)
    end)
    it('selects a model only after the existing login owner reports success', function()
        onboarding.connect(parley)
        state.select_done('Codex', 2)
        settle()
        assert.equals('codex', state.login)
        assert.same({'/owned/proxy', '-codex-login'}, state.argv)
        assert.equals(0, state.picks)
        state.login_done(true)
        settle()
        assert.equals(1, state.picks)
    end)
    it('does not reopen a cancelled or unsuccessful login', function()
        onboarding.connect(parley)
        onboarding.connect(parley)
        assert.equals(1, state.prompts)
        state.select_done('Claude', 1)
        settle()
        state.login_done(false)
        settle()
        assert.equals(0, state.picks)
        assert.equals(1, state.prompts)
    end)
    it('preserves the existing callback-port preflight', function()
        state.blocked = 'callback port is occupied'
        onboarding.connect(parley)
        state.select_done('Claude', 1)
        settle()
        assert.is_nil(state.login)
        assert.equals(1, #state.notices)
    end)
    it('opens provider selection when the model catalog cannot be checked', function()
        state.health.codex, state.models.codex = {state = 'healthy'}, {'gpt-5-codex'}
        state.model_error = 'network unavailable'
        onboarding.start(parley)
        settle()
        assert.equals(1, state.prompts)
        assert.equals(0, state.picks)
        assert.equals(0, #state.notices)
    end)
    it('opens provider selection when credential health cannot be checked', function()
        state.health.claude = {state = 'unknown', message = 'management unavailable'}
        onboarding.start(parley)
        settle()
        assert.equals(1, state.prompts)
        assert.equals(0, state.picks)
        assert.equals(0, #state.notices)
    end)
    it('opens provider selection when the initial proxy check fails', function()
        state.ensure_error = 'managed proxy failed to start'
        onboarding.start(parley)
        settle()
        assert.equals(1, state.prompts)
        assert.equals(0, state.picks)
        assert.same({}, state.notices)
    end)
    it('does not mislabel unknown credential health and can still use another healthy provider', function()
        state.health.claude = {state = 'unknown', message = 'management unavailable'}
        state.health.codex, state.models.codex = {state = 'healthy'}, {'gpt-5-codex'}
        onboarding.start(parley)
        settle()
        assert.equals(1, state.picks)
        assert.equals(0, state.prompts)
    end)
    it('uses available models even when account health is unknown', function()
        state.health.claude = {state = 'unknown'}
        state.models.claude = {'claude-sonnet-4-6'}
        local ready, cancelled = 0, 0
        onboarding.ensure_ready(parley, function() ready = ready + 1 end,
            function() cancelled = cancelled + 1 end)
        settle()
        assert.equals(1, state.picks)
        assert.equals('claude', state.model_picker.provider)
        assert.equals(0, state.prompts)
        assert.same({}, state.notices)
        assert.equals(0, ready)
        state.model_picker.on_cancel()
        assert.equals(1, cancelled)
    end)

end)
