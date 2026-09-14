describe('llm readiness deferral', function()
    local readiness, onboarding, parley, state, saved, source_buf, source_win, created_windows, created_buffers

    local function make_buffer(lines)
        local buf = vim.api.nvim_create_buf(false, true)
        created_buffers[#created_buffers + 1] = buf
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {'one', 'two', 'three'})
        return buf
    end

    local function make_float(buf)
        local win = vim.api.nvim_open_win(buf, true, {
            relative = 'editor', row = 1, col = 1, width = 24, height = 4, style = 'minimal',
        })
        created_windows[#created_windows + 1] = win
        return win
    end

    before_each(function()
        saved = {
            onboarding = package.loaded['parley.starter_onboarding'],
            readiness = package.loaded['parley.llm_readiness'],
            list_uis = vim.api.nvim_list_uis,
            win = vim.api.nvim_get_current_win(),
            buf = vim.api.nvim_get_current_buf(),
        }
        created_windows, created_buffers = {}, {}
        state = {ensure = 0}
        onboarding = {
            ensure_ready = function(p, on_ready, on_cancel)
                assert.equals(parley, p)
                state.ensure = state.ensure + 1
                state.ready, state.cancel = on_ready, on_cancel
            end,
        }
        package.loaded['parley.starter_onboarding'] = onboarding
        package.loaded['parley.llm_readiness'] = nil
        vim.api.nvim_list_uis = function() return {{}} end
        parley = {config = {llm_onboarding = true}}
        readiness = require('parley.llm_readiness')

        source_win = saved.win
        source_buf = make_buffer()
        vim.api.nvim_set_current_win(source_win)
        vim.api.nvim_win_set_buf(source_win, source_buf)
        vim.api.nvim_win_set_cursor(source_win, {2, 1})
    end)

    after_each(function()
        vim.api.nvim_list_uis = saved.list_uis
        package.loaded['parley.starter_onboarding'] = saved.onboarding
        package.loaded['parley.llm_readiness'] = saved.readiness
        for _, win in ipairs(created_windows) do
            if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
        end
        if vim.api.nvim_win_is_valid(saved.win) then
            vim.api.nvim_set_current_win(saved.win)
            if vim.api.nvim_buf_is_valid(saved.buf) then vim.api.nvim_win_set_buf(saved.win, saved.buf) end
        end
        for _, buf in ipairs(created_buffers) do
            if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, {force = true}) end
        end
    end)

    it('does nothing when semantic onboarding is disabled', function()
        parley.config.llm_onboarding = false
        local actions = 0
        assert.is_false(readiness.defer(parley, function() actions = actions + 1 end))
        assert.equals(0, state.ensure)
        assert.equals(0, actions)
    end)

    it('runs once in the captured window, buffer, and cursor', function()
        local observed = {}
        assert.is_true(readiness.defer(parley, function()
            observed[#observed + 1] = {
                win = vim.api.nvim_get_current_win(),
                buf = vim.api.nvim_get_current_buf(),
                cursor = vim.api.nvim_win_get_cursor(0),
            }
        end))
        local other = make_buffer({'elsewhere'})
        make_float(other)
        state.ready()
        state.ready()
        assert.equals(1, #observed)
        assert.equals(source_win, observed[1].win)
        assert.equals(source_buf, observed[1].buf)
        assert.same({2, 1}, observed[1].cursor)
    end)

    it('uses opts.buf to capture a visible non-current source window', function()
        local other = make_buffer({'elsewhere'})
        make_float(other)
        local observed
        readiness.defer(parley, function()
            observed = {vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)}
        end, {buf = source_buf})
        state.ready()
        assert.same({source_win, source_buf, {2, 1}}, observed)
    end)

    it('normalizes opts.buf zero to the concrete current source buffer', function()
        local observed
        readiness.defer(parley, function()
            observed = {vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()}
        end, {buf = 0})
        local other = make_buffer({'elsewhere'})
        make_float(other)
        state.ready()
        assert.same({source_win, source_buf}, observed)
    end)

    it('does not stack a newer attempt and can reopen after cancellation', function()
        local first_cancel, newer_cancel = {}, {}
        readiness.defer(parley, function() error('cancelled action ran') end,
            {on_cancel = function(reason) first_cancel[#first_cancel + 1] = reason end})
        assert.is_true(readiness.defer(parley, function() error('stacked action ran') end,
            {on_cancel = function(reason) newer_cancel[#newer_cancel + 1] = reason end}))
        assert.equals(1, state.ensure)
        assert.equals(1, #newer_cancel)
        assert.matches('already in progress', newer_cancel[1])

        state.cancel('operator cancelled')
        state.cancel('duplicate')
        assert.same({'operator cancelled'}, first_cancel)
        readiness.defer(parley, function() end)
        assert.equals(2, state.ensure)
    end)

    it('cancels exactly once when the source changes before readiness', function()
        local actions, reasons = 0, {}
        readiness.defer(parley, function() actions = actions + 1 end,
            {on_cancel = function(reason) reasons[#reasons + 1] = reason end})
        vim.api.nvim_buf_set_lines(source_buf, 0, 1, false, {'edited'})
        state.ready()
        state.cancel('late cancel')
        assert.equals(0, actions)
        assert.equals(1, #reasons)
        assert.matches('changed', reasons[1])
    end)

    it('cancels when the source buffer is deleted', function()
        local reason
        readiness.defer(parley, function() error('deleted source action ran') end,
            {on_cancel = function(value) reason = value end})
        vim.api.nvim_buf_delete(source_buf, {force = true})
        state.ready()
        assert.matches('no longer exists', reason)
    end)

    it('grants one reentrant action and always clears the grant after an error', function()
        local nested
        readiness.defer(parley, function()
            nested = readiness.defer(parley, function() error('nested action ran') end)
            error('action failure')
        end)
        local ok, err = pcall(state.ready)
        assert.is_false(ok)
        assert.matches('action failure', err)
        assert.is_false(nested)

        readiness.defer(parley, function() end)
        assert.equals(2, state.ensure, 'a leaked grant would bypass the second setup')
    end)

    it('cancels headlessly without opening onboarding UI', function()
        vim.api.nvim_list_uis = function() return {} end
        local reason, actions
        actions = 0
        assert.is_true(readiness.defer(parley, function() actions = actions + 1 end,
            {on_cancel = function(value) reason = value end}))
        assert.equals(0, state.ensure)
        assert.equals(0, actions)
        assert.matches('headless', reason)
    end)

    it('lets a headless caller proceed when a real model is already selected', function()
        vim.api.nvim_list_uis = function() return {} end
        for _, model in ipairs({'gpt-5-codex', {model = 'claude-sonnet-4-6'}}) do
            parley._state = {agent = 'ready'}
            parley.agents = {ready = {model = model}}
            assert.is_false(readiness.defer(parley, function() error('the caller owns immediate execution') end))
        end
        assert.equals(0, state.ensure)
    end)
end)
