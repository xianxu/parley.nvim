-- #307: what `require("parley").setup({})` gives a stranger. Each case boots a
-- separate Neovim with a cleared environment (no *_API_KEY) and its own XDG
-- tree, so vault state and repo detection start from nothing.
local runtime = vim.fn.getcwd()

describe('zero-config setup', function()
    local scratch
    before_each(function()
        scratch = vim.fn.tempname()
        vim.fn.mkdir(scratch .. '/work', 'p')
        scratch = vim.uv.fs_realpath(scratch)
    end)
    after_each(function() vim.fn.delete(scratch, 'rf') end)

    local function run(probe, cwd, extra_env)
        local command = {vim.v.progpath, '--headless', '-n', '-i', 'NONE', '-u', 'NONE',
            '-c', 'lua vim.opt.runtimepath:prepend(' .. string.format('%q', runtime) .. ')',
            '-c', 'lua local ok, err = pcall(function() ' .. probe .. ' end); if not ok then io.stderr:write(tostring(err)); vim.cmd("cquit 1") end',
            '-c', 'qa!'}
        local result = vim.system(command, {cwd = cwd or scratch .. '/work', text = true, clear_env = true, env = {
            PATH = vim.env.PATH, HOME = scratch, NVIM_APPNAME = 'parley-clean',
            XDG_CONFIG_HOME = scratch .. '/config', XDG_DATA_HOME = scratch .. '/data',
            XDG_STATE_HOME = scratch .. '/state', XDG_CACHE_HOME = scratch .. '/cache',
            PARLEY_CLIPROXY_RELEASES_URL = vim.env.PARLEY_CLIPROXY_RELEASES_URL,
            PARLEY_REPO_MODE = (extra_env or {}).PARLEY_REPO_MODE,
            OPT_OUT_ENV = (extra_env or {}).OPT_OUT_ENV,
        }}):wait(10000)
        assert.equals(0, result.code, result.stderr)
    end

    it('boots with setup({}) and no keys, without warnings, and creates a chat', function()
        run([[
            local notes = {}
            vim.notify = function(message, level)
                if (level or 0) >= vim.log.levels.WARN then notes[#notes + 1] = tostring(message) end
            end
            local p = require('parley')
            p.setup({})
            vim.cmd('ParleyChatNew')
            local name = vim.api.nvim_buf_get_name(0)
            local chats = vim.fn.stdpath('data') .. '/parley/chats/'
            assert(name:sub(1, #chats) == chats, 'chat outside default dir: ' .. name)
            assert(p.not_chat(vim.api.nvim_get_current_buf(), name) == nil, 'new buffer is not a chat')
            assert(#notes == 0, 'warnings: ' .. table.concat(notes, ' | '))
            local log = vim.fn.stdpath('state') .. '/parley.nvim.log'
            for _, line in ipairs(vim.fn.filereadable(log) == 1 and vim.fn.readfile(log) or {}) do
                assert(not line:find('WARNING') and not line:find('ERROR'), 'log: ' .. line)
            end
        ]])
    end)

    it('keeps keyless provider defaults when the user supplies other keys', function()
        run([[
            local p = require('parley')
            p.setup({ api_keys = { openai = 'sk-test' } })
            assert(p.vault.get_secret('openai') == 'sk-test')
            assert(p.vault.get_secret('ollama') == 'dummy_secret')
            assert(p.vault.get_secret('cliproxyapi') == 'parley-local')
        ]])
    end)

    it('drops a default key set to false', function()
        run([[
            local p = require('parley')
            p.setup({ api_keys = { cliproxyapi = false } })
            assert(p.vault.get_secret('cliproxyapi') == nil)
            assert(p.vault.get_secret('ollama') == 'dummy_secret')
        ]])
    end)

    it('keeps a provider disabled by an empty table even when a default key exists', function()
        run([[
            local p = require('parley')
            p.setup({ providers = { ollama = {}, openai = {} }, api_keys = { openai = 'sk-test' } })
            assert(p.dispatcher.providers.ollama == nil, 'ollama re-enabled by its default key')
            assert(p.dispatcher.providers.openai == nil, 'openai re-enabled by its key')
        ]])
    end)

    it('reports a missing key when it is first used, not at startup', function()
        run([[
            local p = require('parley')
            p.setup({})
            local ran, err = false, nil
            p.vault.run_with_secret('anthropic', function() ran = true end, function(m) err = m end)
            assert(not ran, 'callback ran without a key')
            assert(err and err:find('anthropic') and err:find('not found'), tostring(err))
        ]])
    end)

    it('detects the nearest marked project when chat_dir is set', function()
        vim.fn.mkdir(scratch .. '/work/project/nested', 'p')
        vim.fn.writefile({}, scratch .. '/work/project/.parley')
        run([[
            local p = require('parley')
            local global = vim.fn.stdpath('data') .. '/my-chats'
            p.setup({ chat_dir = global })
            local root = vim.env.HOME .. '/work/project'
            assert(p.config.repo_root == root, tostring(p.config.repo_root))
            assert(p.config.chat_dir == root .. '/workshop/parley', p.config.chat_dir)
            local roots = p.config.chat_roots
            assert(roots[1].label == 'repo' and roots[2].label == 'global' and roots[2].dir == global,
                vim.inspect(roots))
            -- Every repo-relative reader resolves against the same marked root,
            -- which here has no Git at all (#307 close review BR-1).
            assert(p.project_root() == root, p.project_root())
            local issues = require('parley.issues').get_issues_dir()
            assert(issues == root .. '/' .. p.config.issues_dir, issues)
            assert(require('parley.issues').get_issues_repo_root() == root)
            local vision = require('parley.vision').get_vision_dir()
            assert(vision == root .. '/' .. p.config.vision_dir, vision)
            vim.cmd('edit ' .. vim.fn.fnameescape(root .. '/nested/notes.txt'))
            assert(p._detect_buffer_context(0) == 'repo', p._detect_buffer_context(0))
        ]], scratch .. '/work/project/nested')
    end)

    local opt_out = [[
            local p = require('parley')
            local global = vim.fn.stdpath('data') .. '/my-chats'
            local opts = { chat_dir = global }
            if not vim.env.OPT_OUT_ENV then opts.repo_root = false end
            p.setup(opts)
            assert(type(p.config.repo_root) ~= 'string', tostring(p.config.repo_root))
            assert(p.config.chat_dir == global, p.config.chat_dir)
            vim.cmd('edit ' .. vim.fn.fnameescape(vim.env.HOME .. '/work/notes.txt'))
            assert(p._detect_buffer_context(0) == 'other', p._detect_buffer_context(0))
        ]]

    it('stays out of repo mode with repo_root = false', function()
        vim.fn.writefile({}, scratch .. '/work/.parley')
        run(opt_out)
    end)

    it('stays out of repo mode with PARLEY_REPO_MODE=0', function()
        vim.fn.writefile({}, scratch .. '/work/.parley')
        run(opt_out, nil, { PARLEY_REPO_MODE = '0', OPT_OUT_ENV = '1' })
    end)

    it('lets an explicit repo_root win over PARLEY_REPO_MODE=0', function()
        vim.fn.mkdir(scratch .. '/work/project', 'p')
        vim.fn.writefile({}, scratch .. '/work/project/.parley')
        run([[
            local p = require('parley')
            local root = vim.env.HOME .. '/work/project'
            p.setup({ repo_root = root })
            assert(p.config.repo_root == root, tostring(p.config.repo_root))
        ]], nil, { PARLEY_REPO_MODE = '0' })
    end)
end)
