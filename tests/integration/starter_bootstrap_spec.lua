local uv = vim.uv or vim.loop
local entry = vim.fn.getcwd() .. '/packaging/starter-config/init.lua'
local fixture = vim.fn.getcwd() .. '/tests/packaging/bootstrap_lazy.lua'
local root, env, repo
local function run(app, extra)
    local args = { 'nvim', '--headless', '-u', entry, '+qa!' }
    local e = vim.tbl_extend('force', env, { NVIM_APPNAME = app or 'parley' }, extra or {})
    return vim.system(args, { env = e, text = true }):wait(15000)
end
local function git(args)
    local result = vim.system(vim.list_extend({ 'git' }, args), { text = true }):wait()
    assert.equals(0, result.code, result.stderr)
    return vim.trim(result.stdout)
end

describe('starter bootstrap', function()
    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root .. '/bin', 'p')
        repo = root .. '/repo'
        vim.fn.mkdir(repo .. '/lua/lazy', 'p')
        vim.fn.writefile(vim.fn.readfile(fixture), repo .. '/lua/lazy/init.lua')
        git({ 'init', '-q', repo })
        git({ '-C', repo, 'add', '.' })
        git({ '-C', repo, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
            '-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixture' })
        local commit = git({ '-C', repo, 'rev-parse', 'HEAD' })
        local real_git = vim.fn.exepath('git')
        vim.fn.writefile({ '#!/bin/sh',
            'if [ "$1" = "-C" ] && [ "$3" = "checkout" ]; then',
            '  printf "%s\\n" "$5" >> "$BOOTSTRAP_CALLS"',
            '  exec "' .. real_git .. '" -C "$2" checkout --detach ' .. commit,
            'fi',
            'exec "' .. real_git .. '" "$@"',
        }, root .. '/bin/git')
        uv.fs_chmod(root .. '/bin/git', 493)
        env = { HOME = root .. '/home', XDG_CONFIG_HOME = root .. '/config',
            XDG_DATA_HOME = root .. '/data', XDG_CACHE_HOME = root .. '/cache',
            XDG_STATE_HOME = root .. '/state', PATH = root .. '/bin:' .. vim.env.PATH,
            GIT_CONFIG_COUNT = '1', GIT_CONFIG_KEY_0 = 'url.file://' .. repo .. '.insteadOf',
            GIT_CONFIG_VALUE_0 = 'https://github.com/folke/lazy.nvim.git',
            BOOTSTRAP_CALLS = root .. '/calls', BOOTSTRAP_RESULT = root .. '/result',
            PARLEY_RUNTIME = root .. '/runtime', }
        vim.fn.mkdir(env.PARLEY_RUNTIME, 'p')
    end)
    after_each(function() vim.fn.delete(root, 'rf') end)

    it('refuses another app name before creating profile files', function()
        local result = run('nvim')
        assert.matches('NVIM_APPNAME=parley', result.stderr)
        assert.equals(0, vim.fn.isdirectory(root .. '/data/parley'))
        assert.equals(0, vim.fn.filereadable(root .. '/calls'))
    end)

    it('publishes a pinned checkout, starts the runtime, and reuses its cache', function()
        local result = run()
        assert.equals(0, result.code, result.stderr)
        assert.equals(1, vim.fn.filereadable(root .. '/result'))
        assert.same({ '85c7ff3711b730b4030d03144f6db6375044ae82' }, vim.fn.readfile(root .. '/calls'))
        local spec = vim.json.decode(table.concat(vim.fn.readfile(root .. '/result'), '\n'))
        assert.equals(env.PARLEY_RUNTIME, spec.runtime)
        assert.equals(root .. '/config/parley/lazy-lock.json', spec.lockfile)
        assert.equals(0, vim.fn.isdirectory(root .. '/data/parley/initializer.lock'))
        assert.equals(0, run().code)
        assert.equals(1, #vim.fn.readfile(root .. '/calls'))
    end)

    it('cleans its failed checkout and retries', function()
        assert.matches('bootstrap', run(nil, { GIT_CONFIG_KEY_0 = 'url.file:///nonexistent-parley-bootstrap.insteadOf' }).stderr)
        assert.equals(0, vim.fn.isdirectory(root .. '/data/parley/initializer.lock'))
        assert.equals(0, vim.fn.isdirectory(root .. '/data/parley/lazy/lazy.nvim'))
        assert.equals(0, run().code)
        assert.equals(1, vim.fn.filereadable(root .. '/result'))
    end)

    it('starts in the main window after first-install UI and on cached startup', function()
        for _ = 1, 2 do
            local result = run(nil, {BOOTSTRAP_INSTALL_FLOAT = '1'})
            assert.equals(0, result.code, result.stderr)
            local observed = vim.json.decode(table.concat(vim.fn.readfile(root .. '/result'), '\n'))
            assert.equals('', observed.relative, 'starter inherited the installer float')
            assert.equals(1, observed.windows, 'installer window was left over the chat')
        end
    end)

    it('fails closed for a missing or dead owner without touching foreign staging', function()
        local lock = root .. '/data/parley/initializer.lock'
        vim.fn.mkdir(lock .. '/staging', 'p')
        for _, owner in ipairs({ '', 'invalid', '99999999' }) do
            if owner ~= '' then vim.fn.writefile({ owner }, lock .. '/owner') end
            local result = run()
            assert.matches('close all Parley instances', result.stderr)
            assert.is_not_nil(result.stderr:find(lock, 1, true))
            assert.equals(1, vim.fn.isdirectory(lock .. '/staging'))
        end
    end)

    it('waits for the initializer through Lazy setup before starting a second instance', function()
        local hold = root .. '/hold'
        local first = vim.system({ 'nvim', '--headless', '-u', entry, '+qa!' }, {
            env = vim.tbl_extend('force', env, { NVIM_APPNAME = 'parley', BOOTSTRAP_HOLD = hold }),
            text = true,
        })
        assert.is_true(vim.wait(5000, function()
            return vim.fn.filereadable(hold .. '.ready') == 1
        end, 10))
        local second = vim.system({ 'nvim', '--headless', '-u', entry, '+qa!' }, {
            env = vim.tbl_extend('force', env, { NVIM_APPNAME = 'parley' }), text = true,
        })
        vim.wait(200)
        assert.equals(0, vim.fn.filereadable(root .. '/result'))
        assert.equals(1, vim.fn.isdirectory(root .. '/data/parley/initializer.lock'))
        vim.fn.writefile({ 'release' }, hold .. '.release')
        assert.equals(0, first:wait(5000).code)
        local result = second:wait(5000)
        assert.equals(0, result.code, result.stderr)
        assert.equals(1, #vim.fn.readfile(root .. '/calls'))
        assert.equals(0, vim.fn.isdirectory(root .. '/data/parley/initializer.lock'))
    end)

    it('preserves a crashed initializer until explicit operator recovery', function()
        local hold = root .. '/hold'
        local first = vim.system({ 'nvim', '--headless', '-u', entry, '+qa!' }, {
            env = vim.tbl_extend('force', env, { NVIM_APPNAME = 'parley', BOOTSTRAP_HOLD = hold }),
            text = true,
        })
        assert.is_true(vim.wait(5000, function()
            return vim.fn.filereadable(hold .. '.ready') == 1
        end, 10))
        first:kill(9)
        first:wait(5000)
        local lock = root .. '/data/parley/initializer.lock'
        assert.matches('close all Parley instances', run().stderr)
        assert.equals(1, vim.fn.isdirectory(lock))
        assert.equals(0, vim.fn.filereadable(root .. '/result'))
        vim.fn.delete(lock, 'rf') -- explicit operator recovery
        assert.equals(0, run().code)
        assert.equals(1, vim.fn.filereadable(root .. '/result'))
    end)
end)
