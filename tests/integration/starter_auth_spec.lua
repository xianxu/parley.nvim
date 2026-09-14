local runtime = vim.fn.getcwd()
local uv = vim.uv or vim.loop

describe('starter shared login upgrade', function()
    local scratch
    before_each(function()
        scratch = vim.fn.tempname()
        vim.fn.mkdir(scratch .. '/data/parley/auth', 'p')
        vim.fn.mkdir(scratch .. '/.cli-proxy-api', 'p')
    end)
    after_each(function() vim.fn.delete(scratch, 'rf') end)

    local function run(custom)
        local probe = [[
            local p = require('parley')
            if vim.env.TEST_CUSTOM_AUTH then
                p.setup({cliproxy={auth_dir=vim.env.TEST_CUSTOM_AUTH}})
                assert(p.config.cliproxy.auth_dir == vim.env.TEST_CUSTOM_AUTH)
                local cfg = require('parley.cliproxy_config').render({
                    host='127.0.0.1', port=8317, auth_dir=p.config.cliproxy.auth_dir})
                assert(cfg['auth-dir'] == vim.env.TEST_CUSTOM_AUTH)
            else
                require('parley.starter').start()
                assert(p.config.cliproxy.auth_dir == vim.fn.expand('~/.cli-proxy-api'))
            end
        ]]
        return vim.system({vim.v.progpath, '--headless', '-n', '-i', 'NONE', '-u', 'NONE',
            '-c', 'lua vim.opt.runtimepath:prepend(' .. string.format('%q', runtime) .. ')',
            '-c', 'lua local ok,e=pcall(function() ' .. probe .. ' end); if not ok then io.stderr:write(tostring(e)); vim.cmd("cquit 1") end',
            '-c', 'qa!'}, {text = true, clear_env = true, env = {
                PATH = vim.env.PATH, HOME = scratch, NVIM_APPNAME = 'parley',
                TEST_CUSTOM_AUTH = custom,
                XDG_CONFIG_HOME = scratch .. '/config', XDG_DATA_HOME = scratch .. '/data',
                XDG_STATE_HOME = scratch .. '/state', XDG_CACHE_HOME = scratch .. '/cache',
            }}):wait(10000)
    end

    it('copies credentials privately without overwriting existing accounts or following file links', function()
        local legacy, shared = scratch .. '/data/parley/auth', scratch .. '/.cli-proxy-api'
        vim.fn.writefile({'{"token":"fixture-new"}'}, legacy .. '/new.json')
        vim.fn.writefile({'{"token":"fixture-old"}'}, legacy .. '/existing.json')
        vim.fn.writefile({'{"token":"keep"}'}, shared .. '/existing.json')
        assert(uv.fs_symlink(legacy .. '/new.json', legacy .. '/linked.json'))
        local result = run()
        assert.equals(0, result.code, result.stderr)
        assert.same({'{"token":"fixture-new"}'}, vim.fn.readfile(shared .. '/new.json'))
        assert.same({'{"token":"keep"}'}, vim.fn.readfile(shared .. '/existing.json'))
        assert.is_nil(uv.fs_lstat(shared .. '/linked.json'))
        assert.equals(384, uv.fs_stat(shared .. '/new.json').mode % 512)
        assert.equals(1, vim.fn.filereadable(legacy .. '/new.json'))
        result = run()
        assert.equals(0, result.code, result.stderr)
        assert.same({'{"token":"keep"}'}, vim.fn.readfile(shared .. '/existing.json'))
        assert.is_nil((result.stdout .. result.stderr):find('fixture-new', 1, true))
    end)

    it('preserves an explicit plugin authentication directory through config rendering', function()
        local result = run(scratch .. '/custom-accounts')
        assert.equals(0, result.code, result.stderr)
    end)

    it('refuses a symlink legacy directory without importing from its target', function()
        vim.fn.delete(scratch .. '/data/parley/auth', 'd')
        vim.fn.mkdir(scratch .. '/elsewhere')
        vim.fn.writefile({'{}'}, scratch .. '/elsewhere/new.json')
        assert(uv.fs_symlink(scratch .. '/elsewhere', scratch .. '/data/parley/auth'))
        local result = run()
        assert.is_true(result.code ~= 0)
        assert.is_truthy(result.stderr:find('Invalid legacy authentication directory', 1, true))
        assert.is_nil(uv.fs_lstat(scratch .. '/.cli-proxy-api/new.json'))
    end)

    it('refuses a symlink shared directory without copying credentials through it', function()
        vim.fn.delete(scratch .. '/.cli-proxy-api', 'd')
        vim.fn.mkdir(scratch .. '/elsewhere')
        assert(uv.fs_symlink(scratch .. '/elsewhere', scratch .. '/.cli-proxy-api'))
        vim.fn.writefile({'{}'}, scratch .. '/data/parley/auth/new.json')
        local result = run()
        assert.is_true(result.code ~= 0)
        assert.is_truthy(result.stderr:find('Invalid shared authentication directory', 1, true))
        assert.is_nil(uv.fs_lstat(scratch .. '/elsewhere/new.json'))
    end)
end)
