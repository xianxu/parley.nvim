describe('bundled Parley help', function()
    it('lists and reads bundled topics through the real dispatcher outside the chat root', function()
        local registry = require('parley.tools')
        registry.register_builtins()
        local dispatch = require('parley.tools.dispatcher')
        local index = dispatch.execute_call({id = 'help', name = 'parley_help', input = {}}, registry, {cwd = '/tmp'})
        assert.is_not_true(index.is_error)
        assert.truthy(index.content:find('README', 1, true))
        for topic in index.content:gmatch('[^\n]+') do
            local result = dispatch.execute_call({id = 'help', name = 'parley_help', input = {topic = topic}}, registry, {cwd = '/tmp'})
            assert.is_not_true(result.is_error)
            assert.is_string(result.content)
        end
        for _, name in ipairs({'welcome', 'basics', 'advanced'}) do
            local result = dispatch.execute_call({id = 'tutorial', name = 'parley_help',
                input = {topic = 'tutorials/' .. name}}, registry, {cwd = '/tmp'})
            assert.is_not_true(result.is_error)
            assert.truthy(result.content:find('topic:', 1, true))
        end
        local tool = registry.get('parley_help')
        for _, input in ipairs({{topic = '../auth'}, {topic = '/etc/passwd'}, {path = '/etc/passwd'}, {topic = {}}}) do
            assert.is_true(tool.handler(input).is_error)
        end
    end)
    it('degrades gracefully for missing or malformed bundled guides in an isolated runtime', function()
        local root = vim.fn.tempname()
        vim.fn.mkdir(root .. '/lua/parley', 'p')
        vim.fn.mkdir(root .. '/atlas', 'p')
        vim.fn.writefile({'# Atlas'}, root .. '/atlas/index.md')
        local module = vim.fn.getcwd() .. '/lua/parley/help.lua'
        vim.fn.writefile(vim.fn.readfile(module), root .. '/lua/parley/help.lua')
        for _, content in ipairs({false, {'## wrong', 'No overview'}}) do
            if content then vim.fn.writefile(content, root .. '/README.md') end
            local help = dofile(root .. '/lua/parley/help.lua')
            local text, err = help.read('README')
            assert.is_nil(text)
            assert.is_string(err)
            assert.equals('', help.context('app'))
        end
        vim.fn.delete(root, 'rf')
    end)
    it('rejects symlinked docs and safely renders quoted chat delimiters', function()
        local root = vim.fn.tempname()
        vim.fn.mkdir(root .. '/lua/parley', 'p')
        vim.fn.mkdir(root .. '/atlas', 'p')
        vim.fn.writefile(vim.fn.readfile('lua/parley/help.lua'), root .. '/lua/parley/help.lua')
        vim.fn.writefile({'<!-- parley:introduction:start -->Hi<!-- parley:introduction:end -->'}, root .. '/README.md')
        vim.fn.writefile({'[Secret](secret.md)'}, root .. '/atlas/index.md')
        assert(vim.uv.fs_symlink(root .. '/README.md', root .. '/atlas/secret.md'))
        local help = dofile(root .. '/lua/parley/help.lua')
        assert.is_nil(help.read('atlas/secret'))
        local original = package.loaded['parley.help']
        vim.fn.writefile({'💬: quoted example', '🤖: quoted answer'}, root .. '/README.md')
        package.loaded['parley.help'] = help
        local result = require('parley.tools.builtin.parley_help').handler({topic = 'README'})
        package.loaded['parley.help'] = original
        assert.equals('    💬: quoted example\n    🤖: quoted answer\n    ', result.content)
        vim.fn.delete(root, 'rf')
    end)
    it('refuses missing or redirected tutorials within the fixed catalog', function()
        local root = vim.fn.tempname()
        vim.fn.mkdir(root .. '/lua/parley', 'p')
        vim.fn.mkdir(root .. '/atlas', 'p')
        vim.fn.mkdir(root .. '/packaging/tutorials', 'p')
        vim.fn.writefile(vim.fn.readfile('lua/parley/help.lua'), root .. '/lua/parley/help.lua')
        vim.fn.writefile({'<!-- parley:introduction:start -->Hi<!-- parley:introduction:end -->'}, root .. '/README.md')
        vim.fn.writefile({'# Atlas'}, root .. '/atlas/index.md')
        local help = dofile(root .. '/lua/parley/help.lua')
        assert.is_nil(help.read('tutorials/welcome'))
        assert(vim.uv.fs_symlink(root .. '/README.md', root .. '/packaging/tutorials/welcome.md'))
        assert.is_nil(help.read('tutorials/welcome'))
        assert.is_nil(help.read('workshop/parley/welcome'))
        vim.fn.delete(root, 'rf')
    end)
    it('composes after prompt resolution without mutating the agent or duplicating context', function()
        local parley = require('parley')
        local state = vim.fn.tempname()
        parley.setup({state_dir = state, parley_help = true})
        local agent = parley.get_agent()
        local original = agent.system_prompt
        local env = vim.env.NVIM_APPNAME
        for _, mode in ipairs({'parley', 'nvim'}) do
            vim.env.NVIM_APPNAME = mode
            local info = parley.get_agent_info({system_prompt = 'Custom prompt'}, agent)
            assert.truthy(info.system_prompt:find('Custom prompt', 1, true))
            assert.truthy(info.system_prompt:find(mode == 'parley' and 'standalone Parley app' or 'Neovim plugin', 1, true))
            assert.equals(info.system_prompt, parley.get_agent_info({system_prompt = 'Custom prompt'}, agent).system_prompt)
        end
        vim.env.NVIM_APPNAME = env
        assert.equals(original, agent.system_prompt)
        parley.config.parley_help = false
        local info = parley.get_agent_info({system_prompt = 'Custom prompt'}, agent)
        assert.is_nil(info.system_prompt:find('Parley product context', 1, true))
        vim.fn.delete(state, 'rf')
    end)

end)
