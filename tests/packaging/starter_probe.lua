local ok, why = pcall(function()
    local p = require('parley')
    if vim.env.STARTER_PICK_MODEL then
        p.register_live_agent({ id = vim.env.STARTER_PICK_MODEL, owner = 'anthropic' })
    end
    if vim.env.STARTER_EXPECT_MODEL then
        assert(p._state.agent == vim.env.STARTER_EXPECT_MODEL, 'saved model was replaced: ' .. tostring(p._state.agent))
    end
    assert(p.config.default_keymaps == false)
    assert(p.config.web_search == true)
    assert(p.config.chat_memory.enable == false)
    assert(p.config.memory_prefs.enable == false)
    assert(vim.tbl_count(p.dispatcher.providers) == 1)
    assert(p.dispatcher.providers.cliproxyapi)
    assert(p.agents['ToolOpus*'] == nil)
    for _, a in pairs(p.agents) do assert(vim.deep_equal(a.tools, {'@all'})) end
    local data, state = vim.fn.resolve(vim.fn.stdpath('data')), vim.fn.resolve(vim.fn.stdpath('state'))
    for _, name in ipairs({ 'chat_dir', 'notes_dir', 'export_html_dir', 'export_markdown_dir' }) do
        assert(vim.fn.resolve(p.config[name]):sub(1, #data + 1) == data .. '/', name .. ' escaped profile')
    end
    assert(vim.fn.resolve(p.config.state_dir):sub(1, #state + 1) == state .. '/')
    assert(vim.fn.resolve(vim.fn.expand(p.config.cliproxy.auth_dir)) == vim.fn.resolve(vim.env.HOME .. '/.cli-proxy-api'))
    assert(not vim.uv.fs_stat(vim.env.HOME .. '/Library/Mobile Documents'))
    assert(not vim.uv.fs_stat(vim.env.HOME .. '/blogs'))
    local key = p.vault.get_secret(require('parley.providers').get_secret_name('cliproxyapi'))
    assert(key == 'parley-local')
    assert(p.dispatcher.providers.cliproxyapi.endpoint == 'http://127.0.0.1:8317/v1/chat/completions')
    assert(vim.uv.fs_stat(data).mode % 512 == 448, 'profile data must stay private')
    if not vim.env.STARTER_LEGACY_KEY then
        assert(not vim.uv.fs_lstat(data .. '/client-key'), 'starter created a client key file')
    end
    local log = table.concat(vim.fn.readfile(p.config.log_file), '\n')
    assert(not log:find(key, 1, true), 'client key leaked into profile log')
    assert(vim.fn.exists(':ParleyProxy') == 2)
    assert(vim.fn.exists(':ParleyConnect') == 0, 'standalone Connect alias must not be registered')
    for _, lhs in ipairs({ '<C-g>f', '<C-g>c', '<C-g>?' }) do
        assert(next(vim.fn.maparg(lhs, 'n', false, true)) ~= nil, 'missing starter shortcut: ' .. lhs)
    end
    assert(next(vim.fn.maparg('<C-y>f', 'n', false, true)) == nil, 'issue shortcut enabled')
    assert(next(vim.fn.maparg('<C-n>f', 'n', false, true)) == nil, 'note shortcut enabled')
    if vim.fn.argc() > 0 then
        assert(vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0)) == vim.uv.fs_realpath(vim.fn.argv(0)), vim.inspect({actual=vim.api.nvim_buf_get_name(0),expected=vim.fn.argv(0)}))
    else
        assert(vim.api.nvim_buf_get_name(0):find('/chats/welcome.md', 1, true))
        local finder = require('parley.chat_finder')
        local welcome_path = vim.fn.resolve(vim.api.nvim_buf_get_name(0))
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local parser = require('parley.chat_parser')
        local parsed = parser.parse_chat(lines, parser.find_header_end(lines), p.config)
        assert(parsed.exchanges[1].question.content:lower():find('hello! what is parley, and how do i use it?', 1, true))
        assert(not parsed.exchanges[1].question.content:find('Connect an account', 1, true),
            'setup instructions became part of the question')
        local ordinary_path = data .. '/chats/2026-09-14.00-00-00.000_finder-test.md'
        vim.fn.writefile({ '# topic: Finder test', '- file: ' .. ordinary_path, '---', '', 'Hello' }, ordinary_path)
        local basics_path = data .. '/chats/basics.md'
        local advanced_path = data .. '/chats/advanced.md'
        for _, path in ipairs({ basics_path, advanced_path }) do
            assert(vim.fn.filereadable(path) == 1, 'bundled tutorial was not seeded: ' .. path)
            local tutorial = vim.fn.readfile(path)
            local lesson = parser.parse_chat(tutorial, parser.find_header_end(tutorial), p.config)
            assert(#lesson.exchanges == 1, 'tutorial must contain one practice question')
        end
        assert(parser.is_chat_filename('advanced.md'))
        local basics_buf = vim.fn.bufadd(basics_path)
        vim.fn.bufload(basics_buf)
        assert(p.not_chat(basics_buf, basics_path) == nil, 'named tutorial must be recognized as a chat')
        local renamed, why = p._slug_rename_chat(basics_buf)
        assert(renamed == nil and why == 'not a timestamp chat file', 'tutorial filename must stay stable')
        finder.clear_cache()
        finder.prewarm()
        assert(vim.wait(3000, function() return finder.get_cache()[welcome_path] ~= nil end, 10),
            'chat finder did not discover the welcome chat')
        assert(vim.wait(3000, function() return finder.get_cache()[ordinary_path] ~= nil end, 10),
            'chat finder did not discover the ordinary chat')
        assert(vim.wait(3000, function() return finder.get_cache()[basics_path] ~= nil end, 10),
            'chat finder did not discover basics.md')
        assert(vim.wait(3000, function() return finder.get_cache()[advanced_path] ~= nil end, 10),
            'chat finder did not discover advanced.md')
        assert(vim.wo.conceallevel == 0)
        local map = vim.fn.maparg('<M-CR>', 'n', false, true)
        assert(next(map) ~= nil)
        for _, lhs in ipairs({ '<C-g><C-g>', '<C-g>t', '<M-t>', '<M-v>' }) do
            assert(next(vim.fn.maparg(lhs, 'i', false, true)) ~= nil, 'missing chat shortcut: ' .. lhs)
        end
    end
    if vim.env.STARTER_READINESS_TEST then
        local ready, request
        local onboarding = require('parley.starter_onboarding')
        local saved_ready, saved_uis, saved_query = onboarding.ensure_ready, vim.api.nvim_list_uis, p.dispatcher.query
        onboarding.ensure_ready = function(_, callback) ready = callback end
        vim.api.nvim_list_uis = function() return { {} } end
        p.dispatcher.query = function(_, provider, payload, _, _, _, _, abort)
            request = { provider = provider, model = payload.model }
            if abort then abort('fixture completed') end
        end
        local parser = require('parley.chat_parser')
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local parsed = parser.parse_chat(lines, parser.find_header_end(lines), p.config)
        vim.api.nvim_win_set_cursor(0, { parsed.exchanges[1].question.line_start, 0 })
        p.cmd.ChatRespond({ args = '' })
        assert(vim.wait(3000, function() return type(ready) == 'function' end, 10),
            'chat request did not enter model setup after target admission')
        assert(request == nil, 'chat dispatched before model setup')
        p.register_live_agent({ id = 'claude-opus-5', owner = 'anthropic' })
        ready()
        assert(vim.wait(3000, function() return request ~= nil end, 10), 'chat did not resume')
        assert(request.provider == 'cliproxyapi' and request.model == 'claude-opus-5',
            'resumed request retained the placeholder model')
        onboarding.ensure_ready, vim.api.nvim_list_uis, p.dispatcher.query = saved_ready, saved_uis, saved_query
    end
    if vim.env.STARTER_CONNECT_MODE then
        dofile(vim.env.STARTER_REPO .. '/tests/packaging/starter_connect_probe.lua')
    end
end)
if not ok then
    io.stderr:write(tostring(why) .. '\n')
    vim.cmd('cquit 1')
else
    vim.cmd('qa!')
end
