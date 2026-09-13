-- Profile-owned private state. Nothing here reads provider credentials.
local uv = vim.uv or vim.loop
local M = {}

function M.client_key(dir)
    require('parley.fs').ensure_dir(dir, 448)
    local directory = uv.fs_lstat(dir)
    assert(directory and directory.type == 'directory', 'Invalid profile directory: ' .. dir)
    assert(uv.fs_chmod(dir, 448))
    local path = dir .. '/client-key'
    local function read()
        local stat = uv.fs_lstat(path)
        assert(stat and stat.type == 'file' and stat.size == 64,
            'Invalid client key; repair or remove: ' .. path)
        local fd = assert(uv.fs_open(path, 'r', 0))
        local ok, key = pcall(function()
            -- luv does not expose O_NOFOLLOW on every supported platform.
            -- Bind validation to the opened inode before reading/chmod: a
            -- replaced path or symlink target must never become our key.
            local opened = assert(uv.fs_fstat(fd))
            assert(opened.type == 'file' and opened.dev == stat.dev and opened.ino == stat.ino
                and opened.size == 64, 'Client key changed while opening: ' .. path)
            local token = uv.fs_read(fd, 65, 0)
            assert(token and #token == 64 and token:match('^[a-f0-9]+$'),
                'Invalid client key; repair or remove: ' .. path)
            assert(uv.fs_fchmod(fd, 384))
            return token
        end)
        uv.fs_close(fd)
        assert(ok, key)
        return key
    end
    if uv.fs_lstat(path) then return read() end
    local bytes = assert(uv.random(32))
    local key = bytes:gsub('.', function(c) return ('%02x'):format(c:byte()) end)
    -- Publish complete bytes through a no-clobber hard link. A competing reader
    -- can never observe the empty/truncated file of an exclusive-open writer.
    local fd, temporary = uv.fs_mkstemp(dir .. '/.client-key-XXXXXX')
    assert(fd, 'Cannot stage profile client key: ' .. dir)
    local ok, why = pcall(function()
        assert(uv.fs_fchmod(fd, 384))
        assert(uv.fs_write(fd, key, 0) == #key, 'Cannot write profile client key')
        assert(uv.fs_fsync(fd))
        local linked, _, code = uv.fs_link(temporary, path)
        assert(linked or code == 'EEXIST', 'Cannot publish profile client key: ' .. path)
    end)
    uv.fs_close(fd)
    local removed = uv.fs_unlink(temporary)
    assert(ok, why)
    assert(removed, 'Cannot remove key staging: ' .. temporary)
    return read()
end

return M
