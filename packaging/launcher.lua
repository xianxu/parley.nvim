-- Pre-editor filesystem publication. Runs without user config or plugin setup.
local uv = vim.uv or vim.loop
local profile = assert(vim.env.PARLEY_CONFIG, 'Missing profile directory')
local source = assert(vim.env.PARLEY_STARTER, 'Missing starter source')
local lock = profile .. '/.launcher-initializer'
local owned = false

local function read(path, optional)
    local stat = uv.fs_lstat(path)
    if not stat and optional then return nil end
    assert(stat and stat.type == 'file' and stat.size <= 1024 * 1024,
        'Expected a regular configuration file of at most 1 MiB: ' .. path)
    local fd = assert(uv.fs_open(path, 'r', 0))
    local ok, value = pcall(function()
        local opened = assert(uv.fs_fstat(fd))
        assert(opened.dev == stat.dev and opened.ino == stat.ino and opened.size == stat.size,
            'Configuration changed while opening: ' .. path)
        local text = assert(uv.fs_read(fd, stat.size + 1, 0))
        assert(#text == stat.size, 'Configuration changed while reading: ' .. path)
        return text
    end)
    uv.fs_close(fd)
    assert(ok, value)
    return value
end

local function cleanup()
    if owned then
        assert(vim.fn.delete(lock, 'rf') == 0, 'Cannot remove initializer: ' .. lock)
        owned = false
    end
end

local function prepare_profile()
    local before = uv.fs_lstat(profile)
    assert(not before or before.type == 'directory', 'Unsafe profile directory: ' .. profile)
    vim.opt.runtimepath:prepend(assert(vim.env.PARLEY_RUNTIME))
    require('parley.fs').ensure_dir(profile, 448)
    local deadline = uv.hrtime() + 5 * 1e9
    while not uv.fs_mkdir(lock, 448) do
        local stat = uv.fs_lstat(lock)
        local readable, owner = pcall(read, lock .. '/owner', true)
        if not readable or not stat or stat.type ~= 'directory' then owner = nil end
        local pid = owner and tonumber(owner:match('^([1-9]%d*)\n?$'))
        if uv.hrtime() >= deadline then
            assert(pid and uv.kill(pid, 0), 'Initializer requires repair: ' .. lock
                .. '; close all Parley instances, remove that directory and retry')
            error('Another Parley launcher is still preparing: ' .. lock)
        end
        -- The winner may still be publishing its owner, or may have released
        -- the directory since mkdir failed. Retry acquisition in either case.
        vim.wait(50)
    end
    owned = true
    assert(vim.fn.writefile({ tostring(uv.os_getpid()) }, lock .. '/owner') == 0)
    local initial = profile .. '/init.lua'
    local candidate = initial .. '.new'
    local packaged = read(source)
    local existing = read(initial, true)
    local offered = read(candidate, true)
    if existing and (existing == packaged or offered == packaged) then return end
    local staging = lock .. '/starter'
    local fd = assert(uv.fs_open(staging, 'wx', 384))
    local ok, why = pcall(function()
        assert(uv.fs_write(fd, packaged, 0) == #packaged, 'Cannot write starter configuration')
        assert(uv.fs_fsync(fd))
    end)
    uv.fs_close(fd)
    assert(ok, why)
    if not existing then
        local published, _, code = uv.fs_link(staging, initial)
        assert(published or code == 'EEXIST', 'Cannot publish initial configuration: ' .. initial)
        if published then return end
        existing = read(initial)
        if existing == packaged then return end
    end
    assert(uv.fs_rename(staging, candidate), 'Cannot publish upgrade candidate: ' .. candidate)
    io.stderr:write('Parley kept your settings; updated defaults are in ' .. candidate .. '\n')
end

local ok, why = xpcall(prepare_profile, debug.traceback)
local cleaned, cleanup_error = pcall(cleanup)
if not ok or not cleaned then
    io.stderr:write(tostring(not ok and why or cleanup_error) .. '\n')
    vim.cmd('cquit 1')
end
