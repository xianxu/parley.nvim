describe('starter onboarding uses the agent picker', function()
    local onboarding, parley, state, saved
    before_each(function()
        saved = {proxy = package.loaded['parley.cliproxy'], uis = vim.api.nvim_list_uis}
        package.loaded['parley.starter_onboarding'] = nil
        state = {picks = 0, ensure = 0, models = {}}
        parley = {_state = {agent = 'Choose'}, agents = {Choose = {placeholder = true}},
            agent_picker = {agent_picker = function(_, opts) state.picks = state.picks + 1; state.opts = opts end}}
        package.loaded['parley.cliproxy'] = {
            discover_binary = function() return '/proxy' end,
            login_providers = function() return {'claude', 'codex', 'google'} end,
            ensure_running = function(ok, fail)
                state.ensure = state.ensure + 1
                if state.error then fail(state.error) else ok() end
            end,
            credential_health_for_login = function(_, done) done({state = 'healthy'}) end,
            list_models = function(_, done) done(state.models) end,
        }
        vim.api.nvim_list_uis = function() return {{}} end
        onboarding = require('parley.starter_onboarding')
    end)
    after_each(function()
        package.loaded['parley.cliproxy'] = saved.proxy
        package.loaded['parley.starter_onboarding'] = nil
        vim.api.nvim_list_uis = saved.uis
    end)
    local function flush() vim.wait(20, function() return false end, 1) end
    it('opens all configured agents and providers without proxy startup when unselected', function()
        local ready = 0
        onboarding.ensure_ready(parley, function() ready = ready + 1 end)
        flush()
        assert.equals(1, state.picks)
        assert.is_nil(state.opts.provider)
        assert.equals(0, state.ensure)
        assert.equals(0, ready)
        state.opts.on_select()
        assert.equals(1, ready)
    end)
    it('explicit connect shares the same picker and suppresses duplicate opens', function()
        onboarding.connect(parley)
        onboarding.connect(parley)
        flush()
        assert.equals(1, state.picks)
        state.opts.on_cancel()
        onboarding.connect(parley)
        flush()
        assert.equals(2, state.picks)
    end)
    it('keeps configured non-proxy agents independent of managed proxy availability', function()
        parley.agents.Choose = {provider = 'openai', model = 'custom-model'}
        local ready = false
        onboarding.ensure_ready(parley, function() ready = true end)
        assert.is_true(ready)
        assert.equals(0, state.ensure)
        assert.equals(0, state.picks)
    end)
    it('accepts a saved available proxy model', function()
        parley.agents.Choose = {provider = 'cliproxyapi', model = 'saved'}
        state.models = {'saved'}
        local ready = false
        onboarding.ensure_ready(parley, function() ready = true end)
        flush()
        assert.is_true(ready)
        assert.equals(0, state.picks)
    end)
    it('uses the same unfiltered picker for unavailable proxy models and failures', function()
        parley.agents.Choose = {provider = 'cliproxyapi', model = 'missing'}
        state.error = 'proxy unavailable'
        local cancelled
        onboarding.ensure_ready(parley, nil, function(reason) cancelled = reason end)
        flush()
        assert.equals(1, state.picks)
        assert.is_nil(state.opts.provider)
        state.opts.on_cancel()
        assert.is_string(cancelled)
    end)
    it('startup opens once and remains quiet headlessly', function()
        vim.api.nvim_list_uis = function() return {} end
        onboarding.start(parley)
        flush()
        assert.equals(0, state.picks)
        vim.api.nvim_list_uis = function() return {{}} end
        onboarding.start(parley)
        onboarding.start(parley)
        flush()
        assert.equals(1, state.picks)
    end)
end)
