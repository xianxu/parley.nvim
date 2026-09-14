local root = vim.fn.getcwd()
local uv = vim.uv or vim.loop

describe('installed launcher', function()
    local scratch, environment, children
    before_each(function()
        children = {}
        scratch = vim.fn.tempname() .. ' spaced'
        vim.fn.mkdir(scratch, 'p')
        vim.fn.writefile({ '-- packaged starter one' }, scratch .. '/starter.lua')
        vim.fn.writefile({
            '#!/usr/bin/env python3', 'import json,os,subprocess,sys',
            'if "-l" in sys.argv and sys.argv[sys.argv.index("-l")+1].endswith("/packaging/launcher.lua"):',
            '    extra = ["--cmd", "lua dofile(vim.env.TEST_BARRIER_SCRIPT)"] if os.environ.get("TEST_BARRIER_SCRIPT") else []',
            '    sys.exit(subprocess.run([os.environ["TEST_REAL_NVIM"]]+extra+sys.argv[1:]).returncode)',
            'with open(os.environ["TEST_ARGV"],"w") as f:',
            '    json.dump({"argv":sys.argv[1:],"app":os.environ.get("NVIM_APPNAME"),"runtime":os.environ.get("PARLEY_RUNTIME")},f)',
            'sys.exit(int(os.environ.get("TEST_EXIT","0")))',
        }, scratch .. '/nvim')
        assert(uv.fs_chmod(scratch .. '/nvim', 448))
        environment = { PATH = vim.env.PATH, HOME = scratch .. '/home',
            XDG_CONFIG_HOME = scratch .. '/config', XDG_DATA_HOME = scratch .. '/data',
            XDG_STATE_HOME = scratch .. '/state', XDG_CACHE_HOME = scratch .. '/cache',
            TMPDIR = scratch, PARLEY_NVIM = scratch .. '/nvim', PARLEY_RUNTIME = root,
            PARLEY_STARTER = scratch .. '/starter.lua', TEST_REAL_NVIM = vim.v.progpath,
            TEST_ARGV = scratch .. '/argv.json', NVIM_APPNAME = 'nvim' }
    end)
    after_each(function()
        for _, process in ipairs(children) do pcall(process.kill, process, 9) end
        vim.fn.delete(scratch, 'rf')
    end)

    local function start(extra)
        local process = vim.system({ 'sh', root .. '/packaging/parley' }, {
            text = true, clear_env = true, env = vim.tbl_extend('force', environment, extra or {}),
        })
        children[#children + 1] = process
        return process
    end

    -- Pause a real filesystem operation, leaving the publisher and its lock alive.
    local function barrier(operation)
        local path = scratch .. '/barrier.lua'
        vim.fn.writefile({
            'local uv = vim.uv or vim.loop',
            'local function pause()',
            '  vim.fn.writefile({ tostring(uv.os_getpid()) }, vim.env.TEST_READY)',
            '  assert(vim.wait(8000, function() return vim.fn.filereadable(vim.env.TEST_PROCEED) == 1 end, 10), "barrier timed out")',
            'end',
            operation == 'owner' and 'local write = vim.fn.writefile; vim.fn.writefile = function(lines, path, ...)' or
                'local link = uv.fs_link; uv.fs_link = function(...) pause(); return link(...) end',
            operation == 'owner' and '  if path:match("/owner$") then pause() end; return write(lines, path, ...) end' or '',
        }, path)
        return { TEST_BARRIER_SCRIPT = path, TEST_READY = scratch .. '/ready', TEST_PROCEED = scratch .. '/proceed' }
    end

    local function await_ready()
        assert.is_true(vim.wait(3000, function() return vim.fn.filereadable(scratch .. '/ready') == 1 end, 10),
            'publisher did not reach the filesystem barrier')
        return tonumber(vim.fn.readfile(scratch .. '/ready')[1])
    end


    local function launch(args, extra)
        return vim.system(vim.list_extend({ 'sh', root .. '/packaging/parley' }, args or {}), {
            text = true, clear_env = true, env = vim.tbl_extend('force', environment, extra or {}),
        }):wait(10000)
    end

    it('publishes the complete starter and preserves exact arguments and exit status', function()
        local result = launch({ 'notes with spaces.md', 'literal;$(nothing)' }, { TEST_EXIT = '23' })
        assert.equals(23, result.code, result.stderr)
        local init = scratch .. '/config/parley/init.lua'
        assert.same({ '-- packaged starter one' }, vim.fn.readfile(init))
        local recorded = vim.json.decode(table.concat(vim.fn.readfile(scratch .. '/argv.json'), '\n'))
        assert.same({ '-u', init, 'notes with spaces.md', 'literal;$(nothing)' }, recorded.argv)
        assert.equals('parley', recorded.app)
        assert.equals(root, recorded.runtime)
        assert.equals(384, uv.fs_stat(init).mode % 512)
    end)

    it('preserves edited configuration and offers one stable complete upgrade candidate', function()
        assert.equals(0, launch().code)
        local init = scratch .. '/config/parley/init.lua'
        vim.fn.writefile({ '-- my settings' }, init)
        vim.fn.writefile({ '-- packaged starter two' }, scratch .. '/starter.lua')
        local result = launch()
        assert.equals(0, result.code, result.stderr)
        assert.same({ '-- my settings' }, vim.fn.readfile(init))
        assert.same({ '-- packaged starter two' }, vim.fn.readfile(init .. '.new'))
        local before = uv.fs_stat(init .. '.new').mtime
        result = launch()
        assert.equals(0, result.code, result.stderr)
        assert.same(before, uv.fs_stat(init .. '.new').mtime)
        assert.equals('', result.stderr)
    end)

    it('refuses symlink publication targets without changing their referents', function()
        local profile = scratch .. '/config/parley'
        vim.fn.mkdir(profile, 'p')
        vim.fn.writefile({ 'untouched' }, scratch .. '/outside')
        assert(uv.fs_symlink(scratch .. '/outside', profile .. '/init.lua'))
        local result = launch()
        assert.is_not.equals(0, result.code)
        assert.same({ 'untouched' }, vim.fn.readfile(scratch .. '/outside'))
        assert.is_nil(uv.fs_stat(scratch .. '/argv.json'))
    end)
    it('restores a missing init even when the current candidate already exists', function()
        local profile = scratch .. '/config/parley'
        vim.fn.mkdir(profile, 'p')
        vim.fn.writefile({ '-- packaged starter one' }, profile .. '/init.lua.new')
        local result = launch()
        assert.equals(0, result.code, result.stderr)
        assert.same({ '-- packaged starter one' }, vim.fn.readfile(profile .. '/init.lua'))
    end)

    it('serializes competing real publishers without exposing partial init bytes', function()
        local first = start(barrier('publish'))
        await_ready()
        local profile = scratch .. '/config/parley'
        assert.is_nil(uv.fs_lstat(profile .. '/init.lua'))
        local second = start()
        vim.wait(100)
        assert.is_nil(uv.fs_lstat(profile .. '/init.lua'))
        vim.fn.writefile({ 'continue' }, scratch .. '/proceed')
        local one, two = first:wait(10000), second:wait(10000)
        assert.equals(0, one.code, one.stderr)
        assert.equals(0, two.code, two.stderr)
        assert.same({ '-- packaged starter one' }, vim.fn.readfile(profile .. '/init.lua'))
        assert.is_nil(uv.fs_lstat(profile .. '/.launcher-initializer'))
    end)

    it('preserves a complete init published by an external writer during initialization', function()
        local first = start(barrier('publish'))
        await_ready()
        local profile = scratch .. '/config/parley'
        vim.fn.writefile({ '-- another complete configuration' }, profile .. '/init.lua')
        vim.fn.writefile({ 'continue' }, scratch .. '/proceed')
        local result = first:wait(10000)
        assert.equals(0, result.code, result.stderr)
        assert.same({ '-- another complete configuration' }, vim.fn.readfile(profile .. '/init.lua'))
        assert.same({ '-- packaged starter one' }, vim.fn.readfile(profile .. '/init.lua.new'))
        assert.is_nil(uv.fs_lstat(profile .. '/.launcher-initializer'))
    end)

    it('waits for a competing publisher to finish writing its lock owner', function()
        local first = start(barrier('owner'))
        await_ready()
        local second = start()
        vim.wait(100)
        vim.fn.writefile({ 'continue' }, scratch .. '/proceed')
        local one, two = first:wait(10000), second:wait(10000)
        assert.equals(0, one.code, one.stderr)
        assert.equals(0, two.code, two.stderr)
    end)

    it('preserves killed publisher state until explicit recovery', function()
        local first = start(barrier('publish'))
        local pid = await_ready()
        local lock = scratch .. '/config/parley/.launcher-initializer'
        assert(uv.kill(pid, 9))
        assert.is_not.equals(0, first:wait(10000).code)
        assert.same({ '-- packaged starter one' }, vim.fn.readfile(lock .. '/starter'))
        local result = launch()
        assert.is_not.equals(0, result.code)
        assert.is_truthy(result.stderr:find('requires repair', 1, true))
        assert.is_truthy(uv.fs_lstat(lock))
        assert.is_nil(uv.fs_lstat(scratch .. '/config/parley/init.lua'))
        vim.fn.delete(lock, 'rf') -- Operator-approved recovery after all instances are closed.
        result = launch()
        assert.equals(0, result.code, result.stderr)
        assert.same({ '-- packaged starter one' }, vim.fn.readfile(scratch .. '/config/parley/init.lua'))
    end)

    it('refuses candidate and profile symlinks without touching outside files', function()
        local profile = scratch .. '/config/parley'
        vim.fn.mkdir(profile, 'p')
        vim.fn.writefile({ 'outside settings' }, scratch .. '/outside')
        assert(uv.fs_symlink(scratch .. '/outside', profile .. '/init.lua.new'))
        local result = launch()
        assert.is_not.equals(0, result.code)
        assert.same({ 'outside settings' }, vim.fn.readfile(scratch .. '/outside'))
        assert.is_nil(uv.fs_lstat(profile .. '/init.lua'))
        vim.fn.delete(profile, 'rf')
        vim.fn.mkdir(scratch .. '/outside-profile', 'p')
        assert(uv.fs_symlink(scratch .. '/outside-profile', profile))
        result = launch()
        assert.is_not.equals(0, result.code)
        assert.is_nil(uv.fs_lstat(scratch .. '/outside-profile/init.lua'))
    end)

    it('preserves malformed and symlink initializer state for explicit repair', function()
        local lock = scratch .. '/config/parley/.launcher-initializer'
        vim.fn.mkdir(lock, 'p')
        vim.fn.writefile({ 'not a PID' }, lock .. '/owner')
        local result = launch()
        assert.is_not.equals(0, result.code)
        assert.is_truthy(result.stderr:find('requires repair', 1, true))
        assert.same({ 'not a PID' }, vim.fn.readfile(lock .. '/owner'))
        vim.fn.delete(lock, 'rf')
        vim.fn.mkdir(scratch .. '/outside-lock', 'p')
        vim.fn.writefile({ 'preserve me' }, scratch .. '/outside-lock/owner')
        assert(uv.fs_symlink(scratch .. '/outside-lock', lock))
        result = launch()
        assert.is_not.equals(0, result.code)
        assert.equals('link', uv.fs_lstat(lock).type)
        assert.same({ 'preserve me' }, vim.fn.readfile(scratch .. '/outside-lock/owner'))
    end)

end)
