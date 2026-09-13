local root = vim.fn.getcwd()
local uv = vim.uv or vim.loop

describe('isolated starter runtime', function()
    local scratch
    before_each(function()
        scratch = vim.fn.tempname()
        vim.fn.mkdir(scratch .. '/home', 'p')
        vim.fn.mkdir(scratch .. '/config/nvim', 'p')
        vim.fn.writefile({ "error('separate nvim config was sourced')" }, scratch .. '/config/nvim/init.lua')
    end)
    after_each(function() vim.fn.delete(scratch, 'rf') end)

    local function run(args, extra, async)
        local command = { vim.v.progpath, '--headless', '-n', '-i', 'NONE', '-u', 'NONE',
            '-c', 'lua vim.opt.runtimepath:prepend(' .. string.format('%q', root) .. ')',
            '-c', 'lua dofile(' .. string.format('%q', root .. '/tests/packaging/starter_launch.lua') .. ')',
            '-c', 'lua dofile(' .. string.format('%q', root .. '/tests/packaging/starter_probe.lua') .. ')' }
        vim.list_extend(command, args or {})
        local process = vim.system(command, { text = true, cwd = scratch, clear_env = true, env = vim.tbl_extend('force', {
            PATH = vim.env.PATH, HOME = scratch .. '/home', NVIM_APPNAME = 'parley',
            XDG_CONFIG_HOME = scratch .. '/config', XDG_DATA_HOME = scratch .. '/data',
            XDG_STATE_HOME = scratch .. '/state', XDG_CACHE_HOME = scratch .. '/cache',
            TMPDIR = scratch, STARTER_REPO = root,
        }, extra or {}) })
        return async and process or process:wait(10000)
    end

    it('reopens one durable welcome across independent launches', function()
        local first = run()
        assert.equals(0, first.code, first.stderr)
        local chats = vim.fn.glob(scratch .. '/data/parley/chats/welcome/*.md', false, true)
        assert.equals(1, #chats)
        local before = vim.fn.readfile(chats[1])
        local second = run()
        assert.equals(0, second.code, second.stderr)
        assert.same(chats, vim.fn.glob(scratch .. '/data/parley/chats/welcome/*.md', false, true))
        assert.same(before, vim.fn.readfile(chats[1]))
        assert.same({ "error('separate nvim config was sourced')" }, vim.fn.readfile(scratch .. '/config/nvim/init.lua'))
        assert.is_nil(uv.fs_stat(scratch .. '/home/.cli-proxy-api'))
    end)

    it('preserves an explicit file without creating a welcome', function()
        local file = scratch .. '/requested notes.md'
        vim.fn.writefile({ 'My notes' }, file)
        local result = run({ file })
        assert.equals(0, result.code, result.stderr)
        assert.same({}, vim.fn.glob(scratch .. '/data/parley/chats/welcome/*.md', false, true))
        assert.same({ 'My notes' }, vim.fn.readfile(file))
    end)

    it('rejects an incomplete welcome without overwriting it', function()
        local dir = scratch .. '/data/parley/chats/welcome'
        vim.fn.mkdir(dir, 'p')
        local file = dir .. '/unfinished.md'
        vim.fn.writefile({ '# topic: partial' }, file)
        local result = run(nil, { STARTER_EXPECT_ERROR = 'Incomplete welcome chat' })
        assert.equals(0, result.code, result.stderr)
        assert.same({ '# topic: partial' }, vim.fn.readfile(file))
    end)

    it('rejects symlinks and multiple welcome files without replacing them', function()
        assert.equals(0, run().code)
        local files = vim.fn.glob(scratch .. '/data/parley/chats/welcome/*.md', false, true)
        local target = scratch .. '/saved.md'
        assert(uv.fs_rename(files[1], target))
        assert(uv.fs_symlink(target, files[1]))
        assert.equals(0, run(nil, { STARTER_EXPECT_ERROR = 'Incomplete welcome chat' }).code)
        assert.equals('link', uv.fs_lstat(files[1]).type)
        vim.fn.delete(files[1])
        assert(uv.fs_rename(target, files[1]))
        vim.fn.writefile({ 'other' }, vim.fn.fnamemodify(files[1], ':h') .. '/other.md')
        assert.equals(0, run(nil, { STARTER_EXPECT_ERROR = 'Multiple welcome chats' }).code)
    end)

    it('waits for another welcome creator and reopens its sole chat', function()
        local hold = scratch .. '/hold'
        local first = run(nil, { STARTER_HOLD = hold }, true)
        assert.is_true(vim.wait(5000, function() return vim.fn.filereadable(hold .. '.ready') == 1 end, 10))
        local second = run(nil, nil, true)
        vim.wait(200)
        vim.fn.writefile({ 'release' }, hold .. '.release')
        assert.equals(0, first:wait(5000).code)
        local result = second:wait(5000)
        assert.equals(0, result.code, result.stderr)
        assert.equals(1, #vim.fn.glob(scratch .. '/data/parley/chats/welcome/*.md', false, true))
    end)

    it('recovers the chat created before owner death only after explicit lock repair', function()
        local hold = scratch .. '/hold'
        local first = run(nil, { STARTER_HOLD = hold }, true)
        assert.is_true(vim.wait(5000, function() return vim.fn.filereadable(hold .. '.ready') == 1 end, 10))
        first:kill(9)
        first:wait(5000)
        local files = vim.fn.glob(scratch .. '/data/parley/chats/welcome/*.md', false, true)
        local before = vim.fn.readfile(files[1])
        local lock = scratch .. '/state/parley/welcome-initializer'
        assert.equals(0, run(nil, { STARTER_EXPECT_ERROR = 'Close all Parley instances' }).code)
        assert.equals(1, vim.fn.isdirectory(lock))
        vim.fn.delete(lock, 'rf') -- explicit operator repair
        assert.equals(0, run().code)
        assert.same(files, vim.fn.glob(scratch .. '/data/parley/chats/welcome/*.md', false, true))
        assert.same(before, vim.fn.readfile(files[1]))
    end)

    it('preserves locks with missing or malformed owner records for explicit repair', function()
        local lock = scratch .. '/state/parley/welcome-initializer'
        vim.fn.mkdir(lock .. '/foreign-staging', 'p')
        for _, owner in ipairs({ '', 'not-a-pid' }) do
            if owner ~= '' then vim.fn.writefile({ owner }, lock .. '/owner') end
            local result = run(nil, { STARTER_EXPECT_ERROR = 'Close all Parley instances' })
            assert.equals(0, result.code, result.stderr)
            assert.equals(1, vim.fn.isdirectory(lock .. '/foreign-staging'))
        end
    end)

    it('downloads a missing proxy and completes the existing login flow', function()
        local result = run(nil, { STARTER_CONNECT_MODE = 'success' })
        assert.equals(0, result.code, result.stderr)
    end)

    it('reports a download failure without entering login', function()
        local result = run(nil, { STARTER_CONNECT_MODE = 'failure' })
        assert.equals(0, result.code, result.stderr)
    end)
end)
