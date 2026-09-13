-- Thin first-use UI over Parley's existing chat and managed-login owners.
local uv = vim.uv or vim.loop
local M = {}

function M.connect()
    vim.ui.select({ 'Claude', 'Codex', 'Gemini' }, { prompt = 'Connect your account' }, function(_, index)
        if not index then return end
        local provider = ({ 'claude', 'codex', 'gemini' })[index]
        require('parley.cliproxy').ensure_running(function()
            vim.schedule(function() vim.cmd('ParleyProxy login ' .. provider) end)
        end, function(why)
            vim.schedule(function() vim.notify(tostring(why), vim.log.levels.ERROR) end)
        end)
    end)
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
    local function cleanup()
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
        local dir = chat_dir .. '/welcome'
        require('parley.fs').ensure_dir(dir, 448)
        local files = {}
        local entries = assert(uv.fs_scandir(dir))
        while #files < 2 do
            local name = uv.fs_scandir_next(entries)
            if not name then break end
            if name:match('%.md$') then files[#files + 1] = dir .. '/' .. name end
        end
        assert(#files <= 1, 'Multiple welcome chats; keep the desired file in ' .. dir .. ' and retry.')
        if #files == 1 then
            local stat = uv.fs_lstat(files[1])
            assert(stat and stat.type == 'file' and stat.size > 0,
                'Incomplete welcome chat; repair or remove: ' .. files[1])
            local lines = vim.fn.readfile(files[1])
            local parser = require('parley.chat_parser')
            local header_end = parser.find_header_end(lines)
            local parsed = header_end and parser.parse_chat(lines, header_end, parley.config)
            assert(parsed and #parsed.exchanges > 0,
                'Incomplete welcome chat; repair or remove: ' .. files[1])
            return parley.open_buf(files[1])
        end
        parley.config.chat_dir = dir
        return parley.new_chat()
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
    local key = require('parley.starter_profile').client_key(roots.data)
    local parley = require('parley')
    parley.setup(require('parley.starter_config').options(roots, key))
    vim.api.nvim_create_user_command('ParleyConnect', M.connect, { desc = 'Connect a Claude, Codex or Gemini account' })
    -- Attachment labels remain ordinary visible Markdown in the starter.
    local group = vim.api.nvim_create_augroup('ParleyStarter', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, { group = group, callback = function()
        vim.wo.conceallevel = 0
    end })
    if vim.fn.argc() == 0 then
        welcome(parley, roots)
        vim.wo.conceallevel = 0
        vim.notify('Welcome to Parley!\n:ParleyConnect — log in, then :ParleyAgent to choose a model\n'
            .. 'i — type   Esc — finish typing   Alt+Enter — send\n'
            .. 'Alt+v — paste image   Alt+t — outline   :wq — save and quit', vim.log.levels.INFO)
    end
end

return M
