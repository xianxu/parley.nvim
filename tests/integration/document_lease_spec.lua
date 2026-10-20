local uv = vim.uv or vim.loop
local Embedded = require('tests.helpers.embedded_nvim')

describe('kernel document migration lease', function()
    local root, children, handles
    local function lease() return require('parley.document_lease') end
    local function acquire(namespace, key, options)
        options = vim.tbl_extend('force', { root = root }, options or {})
        local handle, err = lease().acquire(namespace, key, options)
        if handle then handles[#handles + 1] = handle end
        return handle, err
    end
    local function editor()
        local child = Embedded.start()
        children[#children + 1] = child
        return child
    end
    local function remote(child, code, args)
        return child:exec(code, unpack(args or {}))
    end
    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, 'p')
        children, handles = {}, {}
    end)
    after_each(function()
        for _, handle in ipairs(handles) do handle.release() end
        for _, child in ipairs(children) do child:stop() end
        vim.fn.delete(root, 'rf')
    end)

    it('keeps a live editor exclusive until explicit idempotent release', function()
        local owner = editor()
        assert.is_true(remote(owner, [[local root=...; held=assert(require('parley.document_lease').acquire('ns','id',{root=root})); return true]], { root }))
        local denied, err = acquire('ns', 'id')
        assert.is_nil(denied); assert.equals('busy', err.kind)
        assert.is_true(remote(owner, 'held.release(); held.release(); return true'))
        assert.is_truthy(acquire('ns', 'id'))
    end)

    it('releases ownership after process death without PID or age stealing', function()
        local owner = editor()
        local pid = remote(owner, [[local root=...; held=assert(require('parley.document_lease').acquire('ns','id',{root=root})); return vim.fn.getpid()]], { root })
        assert.equals('busy', select(2, acquire('ns', 'id')).kind)
        assert(uv.kill(pid, 9))
        assert.is_true(vim.fn.jobwait({ owner.channel }, 5000)[1] >= 0)
        assert.is_truthy(acquire('ns', 'id'))
    end)

    it('sets close-on-exec and keeps the persistent inode after release', function()
        local held = assert(acquire('ns', 'id'))
        local ffi = require('ffi')
        ffi.cdef('int fcntl(int fd, int cmd, ...);')
        assert.equals(1, bit.band(ffi.C.fcntl(held.fd, 1), 1))
        local before = assert(uv.fs_stat(held.path))
        held.release(); held.release()
        local again = assert(acquire('ns', 'id'))
        assert.equals(before.ino, uv.fs_fstat(again.fd).ino)
    end)

    it('uses the configured state directory when no root is injected', function()
        local loaded = package.loaded.parley
        package.loaded.parley = { config = { state_dir = root } }
        local held, err = lease().acquire('configured', 'id')
        package.loaded.parley = loaded
        if held then handles[#handles + 1] = held end
        assert.is_nil(err)
        assert.is_truthy(held.path:find(root .. '/document-leases/', 1, true))
    end)

    it('scopes arbitrary namespace and identity text to hashed private names', function()
        local first = assert(acquire('../../outside', '../id'))
        local other = assert(acquire('another namespace', '../id'))
        assert.is_not.equals(first.path, other.path)
        assert.is_truthy(first.path:find(root .. '/document-leases/', 1, true))
        assert.matches('/[a-f0-9]+/[a-f0-9]+%.lock$', first.path)
        assert.equals('busy', select(2, acquire('../../outside', '../id')).kind)
        assert.equals('invalid', select(2, acquire('', 'id')).kind)
    end)

    it('keeps binary namespace and key digests byte-identical on the operator Neovim', function()
        local ok, held, err = pcall(acquire, 'ns\0migration-journal-budget', 'id\0binary')
        assert.is_true(ok, tostring(held))
        assert.is_not_nil(held, vim.inspect(err))
        -- Independent SHA-256 vectors over raw NUL bytes, not escaped text.
        assert.equals(root .. '/document-leases/28f80e66ea6fa0e7fbb37d65983b42b0bc10c98eb03c1974fa99d1a3dc6ec000/'
            .. '6a763704ff81d7905cdc3db50a90a0c4a7932625f3378fb193f66fe56f23a452.lock', held.path)
        assert.equals('busy', select(2, acquire('ns\0migration-journal-budget', 'id\0binary')).kind)
    end)

    it('refuses binary leases before allocation when an older Neovim has no hashing utility', function()
        -- This compatibility branch is exercised by the explicit 0.11 run.
        if pcall(vim.fn.sha256, 'probe\0') then return end
        local path = vim.env.PATH
        vim.env.PATH = root
        local ok, held, err = pcall(acquire, 'ns\0migration-journal-budget', 'id')
        vim.env.PATH = path
        assert.is_true(ok, tostring(held))
        assert.is_nil(held)
        assert.equals('unavailable', err.kind)
        assert.truthy(err.message:find('sha256sum or shasum', 1, true))
        assert.equals(0, vim.fn.isdirectory(root .. '/document-leases'))
    end)

    it('retries a replaced inode before granting effects', function()
        local fs, replacements = setmetatable({}, { __index = uv }), 0
        fs.fs_fstat = function(fd)
            local info = uv.fs_fstat(fd)
            if replacements == 0 then
                local directory = root .. '/document-leases/' .. vim.fn.sha256('ns')
                local path = directory .. '/' .. vim.fn.sha256('id') .. '.lock'
                if uv.fs_stat(path) then
                    replacements = replacements + 1
                    assert(uv.fs_unlink(path))
                    local replacement = assert(uv.fs_open(path, 'wx', 384)); uv.fs_close(replacement)
                end
            end
            return info
        end
        local held = assert(acquire('ns', 'id', { fs = fs }))
        assert.equals(1, replacements)
        assert.equals(uv.fs_stat(held.path).ino, uv.fs_fstat(held.fd).ino)
        assert.equals('busy', select(2, acquire('ns', 'id')).kind)
    end)

    it('revalidates replacement between named stat and lstat', function()
        local fs, replacements = setmetatable({}, { __index = uv }), 0
        fs.fs_lstat = function(path)
            if replacements == 0 and path:match('%.lock$') then
                replacements = replacements + 1
                assert(uv.fs_unlink(path))
                local fd = assert(uv.fs_open(path, 'wx', 384)); uv.fs_close(fd)
            end
            return uv.fs_lstat(path)
        end
        local held = assert(acquire('ns', 'id', { fs = fs }))
        assert.equals(1, replacements)
        assert.equals(uv.fs_lstat(held.path).ino, uv.fs_fstat(held.fd).ino)
    end)

    it('fails closed for repeated inode replacement and unavailable native backend', function()
        local fs = setmetatable({}, { __index = uv })
        fs.fs_stat = function(path)
            local stat = uv.fs_stat(path)
            if stat and path:match('%.lock$') then stat.ino = stat.ino + 1 end
            return stat
        end
        assert.equals('unavailable', select(2, acquire('ns', 'id', { fs = fs })).kind)
        assert.equals('unavailable', select(2, acquire('ns', 'id', { native = false })).kind)
        assert.is_truthy(acquire('ns', 'id'))
    end)

    it('refuses a new identity at the namespace limit but admits existing identities', function()
        local held = assert(acquire('ns', 'id')); held.release()
        local directory = vim.fn.fnamemodify(held.path, ':h')
        for n = 1, 4095 do
            local fd = assert(uv.fs_open(directory .. '/' .. vim.fn.sha256('extra' .. n) .. '.lock', 'wx', 384))
            assert(uv.fs_close(fd))
        end
        assert.equals('limit', select(2, acquire('ns', 'overflow')).kind)
        assert.is_truthy(acquire('ns', 'id'))
        assert.is_truthy(acquire('different', 'overflow'))
    end)
end)
