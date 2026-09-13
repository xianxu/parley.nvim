local profile
local uv = vim.uv or vim.loop
local repository = vim.fn.getcwd()

describe('starter client key', function()
    before_each(function() profile = require('parley.starter_profile') end)
    local root
    before_each(function() root = vim.fn.tempname() end)
    after_each(function() vim.fn.delete(root, 'rf') end)

    local function child(id, body)
        vim.fn.mkdir(root, 'p')
        local script = root .. '/creator-' .. id .. '.lua'
        local lines = {
            'vim.opt.runtimepath:prepend(' .. string.format('%q', repository) .. ')',
            'local root = ' .. string.format('%q', root),
            'local uv = vim.uv or vim.loop',
        }
        vim.list_extend(lines, vim.split(body, '\n', { plain = true }))
        vim.fn.writefile(lines, script)
        return vim.system({ vim.v.progpath, '--headless', '-n', '-i', 'NONE', '-u', 'NONE',
            '-l', script }, { text = true, clear_env = true, env = {
                PATH = vim.env.PATH, HOME = root .. '/home', NVIM_APPNAME = 'parley',
                XDG_CONFIG_HOME = root .. '/config', XDG_DATA_HOME = root .. '/data',
                XDG_STATE_HOME = root .. '/state', XDG_CACHE_HOME = root .. '/cache',
                TMPDIR = root,
            } })
    end

    it('publishes one complete winner across competing independent creators', function()
        local children = {}
        for id = 1, 3 do
            children[id] = child(id, ([=[
                local link = uv.fs_link
                uv.fs_link = function(source, destination)
                    vim.fn.writefile({}, root .. '/ready-%d')
                    assert(vim.wait(5000, function() return uv.fs_stat(root .. '/release') ~= nil end, 10))
                    return link(source, destination)
                end
                local key = require('parley.starter_profile').client_key(root .. '/private')
                vim.fn.writefile({key}, root .. '/result-%d', 'b')
            ]=]):format(id, id))
        end
        local ready = vim.wait(5000, function()
            return #vim.fn.glob(root .. '/ready-*', false, true) == 3
        end, 10)
        -- Always release/join children, even when the barrier assertion fails.
        vim.fn.writefile({}, root .. '/release')
        local results = {}
        for _, process in ipairs(children) do results[#results + 1] = process:wait(7000) end
        assert.is_true(ready)
        for _, result in ipairs(results) do assert.equals(0, result.code, result.stderr) end
        local winner = profile.client_key(root .. '/private')
        assert.equals(64, #winner)
        assert.matches('^[a-f0-9]+$', winner)
        for id = 1, 3 do assert.same({winner}, vim.fn.readfile(root .. '/result-' .. id)) end
        assert.same({}, vim.fn.glob(root .. '/private/.client-key-*', false, true))
    end)

    it('cleans owned staging after a real publication failure and permits retry', function()
        local result = child('failed', [=[
            local link = uv.fs_link
            uv.fs_link = function(source, destination)
                -- Make the real link syscall fail with ENOENT after staging.
                assert(uv.fs_unlink(source))
                local ok, why, code = link(source, destination)
                -- Restore staging so the normal cleanup path still has work.
                local fd = assert(uv.fs_open(source, 'wx', 384))
                uv.fs_close(fd)
                return ok, why, code
            end
            local ok = pcall(require('parley.starter_profile').client_key, root .. '/private')
            assert(not ok, 'publication failure must surface')
        ]=]):wait(7000)
        assert.equals(0, result.code, result.stderr)
        assert.is_nil(uv.fs_stat(root .. '/private/client-key'))
        assert.same({}, vim.fn.glob(root .. '/private/.client-key-*', false, true))
        assert.equals(64, #profile.client_key(root .. '/private'))
    end)

    it('preserves a published winner after abrupt creator death without deleting foreign staging', function()
        local result = child('interrupted', [=[
            local link = uv.fs_link
            uv.fs_link = function(source, destination)
                assert(link(source, destination))
                os.exit(71)
            end
            require('parley.starter_profile').client_key(root .. '/private')
        ]=]):wait(7000)
        assert.equals(71, result.code, result.stderr)
        local path = root .. '/private/client-key'
        local before = vim.fn.readfile(path, 'b')
        local inode = uv.fs_stat(path).ino
        local staging = vim.fn.glob(root .. '/private/.client-key-*', false, true)
        assert.equals(1, #staging)
        assert.equals(before[1], profile.client_key(root .. '/private'))
        assert.equals(inode, uv.fs_stat(path).ino)
        assert.same(before, vim.fn.readfile(path, 'b'))
        assert.same(staging, vim.fn.glob(root .. '/private/.client-key-*', false, true))
    end)

    it('recovers an unpublished creator death without treating staging as the winner', function()
        local result = child('unpublished', [=[
            uv.fs_link = function() os.exit(72) end
            require('parley.starter_profile').client_key(root .. '/private')
        ]=]):wait(7000)
        assert.equals(72, result.code, result.stderr)
        assert.is_nil(uv.fs_stat(root .. '/private/client-key'))
        local staging = vim.fn.glob(root .. '/private/.client-key-*', false, true)
        assert.equals(1, #staging)
        local abandoned = vim.fn.readfile(staging[1], 'b')
        local winner = profile.client_key(root .. '/private')
        assert.equals(64, #winner)
        assert.equals(winner, profile.client_key(root .. '/private'))
        assert.same(abandoned, vim.fn.readfile(staging[1], 'b'))
        assert.same(staging, vim.fn.glob(root .. '/private/.client-key-*', false, true))
    end)

    it('creates a private, stable random key', function()
        local key = profile.client_key(root)
        assert.equals(64, #key)
        assert.matches('^[a-f0-9]+$', key)
        assert.equals(key, profile.client_key(root))
        assert.equals(384, uv.fs_stat(root .. '/client-key').mode % 512)
        assert.equals(448, uv.fs_stat(root).mode % 512)
    end)

    it('refuses malformed existing state without overwriting it', function()
        vim.fn.mkdir(root, 'p')
        vim.fn.writefile({ 'broken' }, root .. '/client-key')
        assert.has_error(function() profile.client_key(root) end)
        assert.same({ 'broken' }, vim.fn.readfile(root .. '/client-key'))
    end)

    it('refuses a symlink instead of reading or replacing its target', function()
        vim.fn.mkdir(root, 'p')
        vim.fn.writefile({ string.rep('a', 64) }, root .. '/other')
        assert(uv.fs_symlink(root .. '/other', root .. '/client-key'))
        assert.has_error(function() profile.client_key(root) end)
        assert.equals('link', uv.fs_lstat(root .. '/client-key').type)
    end)

    it('tightens an existing profile directory', function()
        vim.fn.mkdir(root, 'p')
        assert(uv.fs_chmod(root, 511))
        profile.client_key(root)
        assert.equals(448, uv.fs_stat(root).mode % 512)
    end)

    it('refuses a replacement between path inspection and opening', function()
        local key = profile.client_key(root)
        vim.fn.writefile({ string.rep('b', 64) }, root .. '/other', 'b')
        uv.fs_chmod(root .. '/other', 420)
        local original = uv.fs_open
        uv.fs_open = function(path, flags, mode)
            if path == root .. '/client-key' and flags == 'r' then
                uv.fs_unlink(path)
                uv.fs_symlink(root .. '/other', path)
            end
            return original(path, flags, mode)
        end
        local ok, result = pcall(profile.client_key, root)
        uv.fs_open = original
        assert.is_false(ok, result)
        assert.equals(420, uv.fs_stat(root .. '/other').mode % 512)
        assert.is_not_nil(key)
    end)
end)
