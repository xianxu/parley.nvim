-- Thin first-use UI over Parley's existing chat and managed-login owners.
local uv = vim.uv or vim.loop
local M = {}

function M.connect()
    require('parley.starter_onboarding').connect(require('parley'))
end

local function migrate_welcome(parley, chat_dir)
    local legacy = chat_dir .. '/welcome'
    local stat = uv.fs_lstat(legacy)
    if not stat then return end
    assert(stat.type == 'directory', 'Legacy welcome path is not a directory: ' .. legacy)
    local previous = vim.deepcopy(parley.get_chat_roots())
    -- Root lookup uses first match: the nested source must precede its parent.
    parley.set_chat_dirs({ legacy, chat_dir }, false)
    local ok, why = pcall(function()
        local entries = assert(uv.fs_scandir(legacy))
        local files = {}
        while true do
            local name, kind = uv.fs_scandir_next(entries)
            if not name then break end
            if name:match('%.md$') then
                assert(kind == 'file', 'Legacy welcome chat is not a regular file: ' .. name)
                files[#files + 1] = legacy .. '/' .. name
            end
        end
        for _, path in ipairs(files) do
            if uv.fs_lstat(path) then
                local moved, err = parley.move_chat_tree(path, chat_dir)
                assert(moved, err)
            end
        end
        -- Remove only empty containers; unrelated files are never deleted.
        uv.fs_rmdir(legacy .. '/assets')
        uv.fs_rmdir(legacy)
    end)
    parley.set_chat_roots(previous, false)
    assert(ok, why)
end

local function welcome(parley, roots)
    local lock = roots.state .. '/welcome-initializer'
    local deadline = uv.hrtime() + 300 * 1e9
    while not uv.fs_mkdir(lock, 448) do
        local stat = uv.fs_lstat(lock)
        local owner_stat = uv.fs_lstat(lock .. '/owner')
        local fd = owner_stat and owner_stat.type == 'file' and io.open(lock .. '/owner', 'r')
        local owner = fd and fd:read(32)
        if fd then fd:close() end
        local pid = owner and tonumber(owner:match('^(%d+)%s*$'))
        if not stat or stat.type ~= 'directory' or not pid or pid < 1 or not uv.kill(pid, 0) then
            error('Welcome initialization requires repair. Close all Parley instances, remove ' .. lock .. ', and retry.')
        end
        if uv.hrtime() >= deadline then
            error('Welcome initializer is still active: ' .. lock .. '; retry after it finishes.')
        end
        vim.wait(100)
    end
    local owned = true
    local staging_dir
    local function cleanup()
        if staging_dir then
            assert(vim.fn.delete(staging_dir, 'rf') == 0, 'Cannot remove tutorial staging: ' .. staging_dir)
            staging_dir = nil
        end
        if owned then
            local removed = vim.fn.delete(lock, 'rf')
            assert(removed == 0, 'Cannot remove welcome initializer: ' .. lock)
            owned = false
        end
    end
    local leave = vim.api.nvim_create_autocmd('VimLeavePre', { once = true, callback = cleanup })
    local chat_dir = parley.config.chat_dir
    local ok, result = xpcall(function()
        vim.fn.writefile({ tostring(uv.os_getpid()) }, lock .. '/owner')
        migrate_welcome(parley, chat_dir)
        local source = debug.getinfo(1, 'S').source:sub(2)
        local runtime = assert(source:match('^(.*)/lua/parley/starter%.lua$'), 'Cannot locate bundled tutorials')
        for _, name in ipairs({ 'welcome.md', 'basics.md', 'advanced.md' }) do
            local path = chat_dir .. '/' .. name
            local stat = uv.fs_lstat(path)
            if not stat then
                local lines = vim.fn.readfile(runtime .. '/packaging/tutorials/' .. name)
                if not staging_dir then
                    staging_dir = assert(uv.fs_mkdtemp(chat_dir .. '/.parley-tutorial-XXXXXX'))
                    assert(uv.fs_chmod(staging_dir, 448))
                end
                local staging = staging_dir .. '/' .. name
                assert(vim.fn.writefile(lines, staging) == 0, 'Cannot write tutorial: ' .. name)
                local linked, why = uv.fs_link(staging, path)
                assert(linked, 'Cannot publish tutorial: ' .. tostring(why))
            elseif name == 'welcome.md' then
                assert(stat.type == 'file' and stat.size > 0,
                    'Incomplete welcome chat; repair or remove: ' .. path)
                local lines = vim.fn.readfile(path)
                local parser = require('parley.chat_parser')
                local header_end = parser.find_header_end(lines)
                local parsed = header_end and parser.parse_chat(lines, header_end, parley.config)
                assert(parsed and #parsed.exchanges > 0,
                    'Incomplete welcome chat; repair or remove: ' .. path)
            end
        end
        return parley.open_buf(chat_dir .. '/welcome.md')
    end, debug.traceback)
    parley.config.chat_dir = chat_dir
    cleanup()
    vim.api.nvim_del_autocmd(leave)
    assert(ok, result)
    return result
end

function M.start()
    assert(vim.env.NVIM_APPNAME == 'parley', 'Start with NVIM_APPNAME=parley to use this profile.')
    local roots = { data = vim.fn.stdpath('data'), state = vim.fn.stdpath('state') }
    require('parley.fs').ensure_dir(roots.state, 448)
    require('parley.fs').ensure_dir(roots.data, 448)
    local data_stat = uv.fs_lstat(roots.data)
    assert(data_stat and data_stat.type == 'directory', 'Invalid profile directory: ' .. roots.data)
    assert(uv.fs_chmod(roots.data, 448))
    local parley = require('parley')
    local options = require('parley.starter_config').options(roots)
    options.repo_root = require('parley.repo_mode').detect_root(vim.fn.getcwd(), require('parley.config').repo_marker)
    parley.setup(options)
    -- Attachment labels remain ordinary visible Markdown in the starter.
    local group = vim.api.nvim_create_augroup('ParleyStarter', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, { group = group, callback = function()
        vim.wo.conceallevel = 0
    end })
    if vim.fn.argc() == 0 then
        welcome(parley, roots)
        vim.wo.conceallevel = 0
        vim.notify('Welcome to Parley!\n:ParleyProxy connect — log in, then :ParleyAgent to choose a model\n'
            .. 'i — type   Esc — finish typing   Alt+Enter — send\n'
            .. 'Ctrl+g f — find chats   Ctrl+g c — new chat   Ctrl+g ? — shortcuts\n'
            .. 'Alt+v — paste image   Alt+t — outline   :wq — save and quit', vim.log.levels.INFO)
        require('parley.starter_onboarding').start(parley)
    end
end

return M
