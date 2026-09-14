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
            local p = require('parley')
            if vim.env.PLUGIN_OVERRIDE then
                p.setup({chat_dir = vim.env.EXPECTED_CHAT, state_dir = vim.fn.stdpath('state')})
            else require('parley.starter').start() end
            assert(vim.fs.normalize(p.config.chat_dir) == vim.fs.normalize(vim.env.EXPECTED_CHAT),
                'wrong primary chat dir: ' .. p.config.chat_dir)
            if vim.env.EXPECTED_PROJECT then
                assert(p.config.repo_root == vim.env.EXPECTED_PROJECT)
                local policy = require('parley.neighborhood').policy_for_path(
                    p.config.chat_dir .. '/example.md', p.config, p.get_chat_roots())
                assert(policy.write_root == vim.env.EXPECTED_PROJECT)
                assert(vim.deep_equal(policy.read_roots, {vim.env.EXPECTED_PROJECT}))
            else assert(p.config.repo_root == nil or p.config.repo_root == '') end
        ]]
        local expected = plugin_override and scratch .. '/custom-chats'
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
            EXPECTED_PROJECT = marker and not plugin_override and scratch .. '/project' or nil,
            PLUGIN_OVERRIDE = plugin_override and '1' or nil,
        }}):wait(10000)
        assert.equals(0, result.code, result.stderr)
    end

    it('uses a marker-only project without Git', function() run(scratch .. '/project', true) end)
    it('finds the marked project above a nested working directory', function() run(scratch .. '/project/nested', true) end)
    it('keeps the global app profile without a marker', function() run(scratch .. '/project/nested', false) end)
    it('preserves an explicit plugin chat directory without explicit project selection', function()
        run(scratch .. '/project', true, true)
    end)
end)
