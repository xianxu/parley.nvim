-- Kernel ownership for document migrations. Lock files are permanent identities:
-- releasing a lease closes its descriptor, and never unlinks its inode.
local M = {}
local uv = vim.uv or vim.loop
local LIMIT = 4096
local RETRIES = 3
local native_backend

local function failure(kind, message)
    return nil, { kind = kind, message = tostring(message) }
end

local function native()
    if native_backend then return native_backend end
    local ok, backend = pcall(function()
        local ffi = require('ffi')
        if ffi.os ~= 'OSX' and ffi.os ~= 'Linux' then error('unsupported lease platform') end
        ffi.cdef([[int flock(int fd, int operation); int fcntl(int fd, int cmd, ...);]])
        local flock, fcntl = ffi.C.flock, ffi.C.fcntl
        return {
            cloexec = function(fd)
                local flags = fcntl(fd, 1) -- F_GETFD
                if flags < 0 or fcntl(fd, 2, ffi.cast('int', bit.bor(flags, 1))) < 0 then
                    return failure('unavailable', 'cannot set FD_CLOEXEC')
                end
                return true
            end,
            lock = function(fd)
                if flock(fd, 6) == 0 then return true end -- LOCK_EX | LOCK_NB
                local errno = ffi.errno()
                if errno == 11 or errno == 35 then return failure('busy', 'document lease is held') end
                return failure('unavailable', 'flock failed: errno ' .. errno)
            end,
        }
    end)
    if not ok then return nil, backend end
    native_backend = backend
    return backend
end

local function mkdir(fs, path)
    local stat = fs.fs_stat(path)
    if stat then return stat.type == 'directory' end
    local parent = vim.fn.fnamemodify(path, ':h')
    if parent == path or not mkdir(fs, parent) then return false end
    local created = fs.fs_mkdir(path, 448) -- 0700
    if created then return true end
    stat = fs.fs_stat(path)
    return stat and stat.type == 'directory'
end

-- Acquisition must validate the name *after* flock: a contender may have opened
-- the old inode just before a retirement/replacement. No caller gets that lease.
local function open_locked(fs, backend, path)
    for _ = 1, RETRIES do
        local fd, err = fs.fs_open(path, 'a+', 384) -- 0600; no truncation
        if not fd then return failure('unavailable', err) end
        local function close_error(reason)
            fs.fs_close(fd)
            return nil, reason
        end
        local set, set_err = backend.cloexec(fd)
        if not set then return close_error(set_err) end
        local locked, lock_err = backend.lock(fd)
        if not locked then return close_error(lock_err) end
        local opened = fs.fs_fstat(fd)
        local named = fs.fs_stat(path)
        local entry = fs.fs_lstat(path)
        if opened and named and entry and entry.type == 'file'
            and opened.type == 'file' and opened.dev == named.dev and opened.ino == named.ino
            and opened.dev == entry.dev and opened.ino == entry.ino then
            local released = false
            return {
                path = path,
                fd = fd,
                release = function()
                    if released then return true end
                    released = true
                    return fs.fs_close(fd)
                end,
            }
        end
        fs.fs_close(fd)
    end
    return failure('unavailable', 'document lease inode changed during acquisition')
end

-- namespace/key are opaque identities, never path components. root defaults to
-- configured state_dir. fs is a synchronous libuv-compatible adapter; native is
-- {cloexec(fd),lock(fd)}, returning true or nil,{kind,message} (false disables).
-- The caller owns release across asynchronous work, including unload/errors.
function M.acquire(namespace, key, options)
    if type(namespace) ~= 'string' or namespace == '' or type(key) ~= 'string' or key == '' then
        return failure('invalid', 'namespace and key must be nonempty strings')
    end
    options = options or {}
    local configured = package.loaded.parley and package.loaded.parley.config
    local root = options.root or (configured and configured.state_dir) or require('parley.config').state_dir
    if type(root) ~= 'string' or root == '' then return failure('invalid', 'state directory is missing') end
    local backend, backend_err
    if options.native == false then return failure('unavailable', 'native lease backend disabled') end
    backend = options.native
    if not backend then backend, backend_err = native() end
    if not backend then return failure('unavailable', backend_err) end
    local fs = options.fs or uv
    local directory = root:gsub('/$', '') .. '/document-leases/' .. vim.fn.sha256(namespace)
    if not mkdir(fs, directory) then return failure('unavailable', 'cannot create document lease directory') end

    -- This stable guard serializes namespace count/create across editors. A
    -- bounded scan outside the guard would allow concurrent overflow.
    local allocation, allocation_err = open_locked(fs, backend, directory .. '/.allocation')
    if not allocation then return nil, allocation_err end
    local path = directory .. '/' .. vim.fn.sha256(key) .. '.lock'
    local exists = fs.fs_stat(path)
    if not exists then
        local scan, scan_err = fs.fs_scandir(directory)
        if not scan then allocation.release(); return failure('unavailable', scan_err) end
        local count = 0
        while true do
            local name = fs.fs_scandir_next(scan)
            if not name then break end
            if name:match('%.lock$') then count = count + 1 end
            if count >= LIMIT then
                allocation.release()
                return failure('limit', 'namespace document lease limit reached (4096)')
            end
        end
    end
    local handle, err = open_locked(fs, backend, path)
    allocation.release()
    return handle, err
end

return M
