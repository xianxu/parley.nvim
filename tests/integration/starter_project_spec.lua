local runtime = vim.fn.getcwd()

describe('starter project discovery', function()
    local scratch
    before_each(function()
        scratch = vim.fn.tempname()
        vim.fn.mkdir(scratch .. '/project/nested', 'p')
        scratch = vim.uv.fs_realpath(scratch)
    end)
    after_each(function() vim.fn.delete(scratch, 'rf') end)

    local function run(cwd, marker, plugin_override)
        if marker then vim.fn.writefile({}, scratch .. '/project/.parley') end
        local probe = [[
            local notifications = {}
            local notify = vim.notify
            vim.notify = function(message, ...)
                notifications[#notifications + 1] = tostring(message)
                return notify(message, ...)
            end
            local p = require('parley')
            if vim.env.PLUGIN_OVERRIDE then
                local opts = {chat_dir = vim.env.GLOBAL_CHAT, state_dir = vim.fn.stdpath('state')}
                if vim.env.OPT_OUT then opts.repo_root = false end
                p.setup(opts)
            else
                require('parley.starter').start()
                assert(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t') == 'welcome.md',
                    'no-argument startup did not open welcome.md')
                for _, message in ipairs(notifications) do
                    assert(not message:find('Welcome to Parley!', 1, true),
                        'duplicate welcome notification: ' .. message)
                end
            end
            assert(vim.fs.normalize(p.config.chat_dir) == vim.fs.normalize(vim.env.EXPECTED_CHAT),
                'wrong primary chat dir: ' .. p.config.chat_dir)
            if vim.env.EXPECTED_PROJECT then
                assert(p.config.repo_root == vim.env.EXPECTED_PROJECT)
                if vim.env.DETECT_PROJECT then
                    local path = p.config.chat_dir .. '/2026-09-13.22-17-01.392_test.md'
                    vim.fn.mkdir(p.config.chat_dir, 'p')
                    vim.fn.writefile({'---', 'topic: test', 'file: test.md', 'tags:', '---', '', '💬: hello'}, path)
                    p.open_buf(path)
                    assert(p.not_chat(vim.api.nvim_get_current_buf(), path) == nil,
                        'repository transcript treated as ordinary Markdown')
                    local binding = vim.fn.maparg('<C-g>a', 'n', false, true)
                    assert(binding.desc == 'Parley prompt Next Agent',
                        'Ctrl+g a selected Markdown chat-reference behavior: ' .. tostring(binding.desc))
                end
                local policy = require('parley.neighborhood').policy_for_path(
                    p.config.chat_dir .. '/example.md', p.config, p.get_chat_roots())
                assert(policy.write_root == vim.env.EXPECTED_PROJECT)
                assert(vim.deep_equal(policy.read_roots, {vim.env.EXPECTED_PROJECT}))
            else assert(type(p.config.repo_root) ~= 'string' or p.config.repo_root == '') end
        ]]
        local expected = plugin_override == 'opt_out' and scratch .. '/custom-chats'
            or marker and scratch .. '/project/workshop/parley' or scratch .. '/data/parley/chats'
        local command = {vim.v.progpath, '--headless', '-n', '-i', 'NONE', '-u', 'NONE',
            '-c', 'lua vim.opt.runtimepath:prepend(' .. string.format('%q', runtime) .. ')',
            '-c', 'lua local ok, err = pcall(function() ' .. probe .. ' end); if not ok then io.stderr:write(tostring(err)); vim.cmd("cquit 1") end',
            '-c', 'qa!'}
        local result = vim.system(command, {cwd = cwd, text = true, clear_env = true, env = {
            PATH = vim.env.PATH, HOME = scratch, NVIM_APPNAME = 'parley',
            XDG_CONFIG_HOME = scratch .. '/config', XDG_DATA_HOME = scratch .. '/data',
            XDG_STATE_HOME = scratch .. '/state', XDG_CACHE_HOME = scratch .. '/cache',
            EXPECTED_CHAT = expected,
            EXPECTED_PROJECT = marker and plugin_override ~= 'opt_out' and scratch .. '/project' or nil,
            GLOBAL_CHAT = scratch .. '/custom-chats',
            DETECT_PROJECT = plugin_override == 'detected' and '1' or nil,
            OPT_OUT = plugin_override == 'opt_out' and '1' or nil,
            PLUGIN_OVERRIDE = plugin_override and '1' or nil,
        }}):wait(10000)
        assert.equals(0, result.code, result.stderr)
    end

    it('uses a marker-only project without Git', function() run(scratch .. '/project', true) end)
    it('finds the marked project above a nested working directory', function() run(scratch .. '/project/nested', true) end)
    it('keeps the global app profile without a marker', function() run(scratch .. '/project/nested', false) end)
    it('detects the marked project in plugin setup with an explicit global chat_dir', function()
        run(scratch .. '/project/nested', true, 'detected')
    end)
    it('keeps the explicit plugin chat directory when repo_root = false', function()
        run(scratch .. '/project', true, 'opt_out')
    end)
end)
