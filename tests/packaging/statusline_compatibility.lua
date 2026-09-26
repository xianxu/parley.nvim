-- Run with isolated XDG roots, NVIM_APPNAME=parley, PARLEY_RUNTIME=$PWD,
-- PARLEY_THEME_ROOT pointing at pinned themes and PARLEY_LUALINE_RUNTIME at Lualine.
local ok, err = pcall(function()
    vim.opt.runtimepath:prepend(assert(vim.env.PARLEY_RUNTIME))
    vim.opt.runtimepath:append(assert(vim.env.PARLEY_LUALINE_RUNTIME))
    local theme = require('parley.theme')
    for _, plugin in ipairs(theme.packaged_plugins()) do
        vim.opt.runtimepath:append(assert(vim.env.PARLEY_THEME_ROOT) .. '/' .. plugin.name)
    end
    -- Fake only the installer boundary; execute the production starter options
    -- with the real pinned Lualine, themes, Parley setup and rendering code.
    local lazy = vim.fn.stdpath('data') .. '/lazy/lazy.nvim/lua/lazy'
    vim.fn.mkdir(lazy, 'p')
    vim.fn.writefile({ '-- installer fixture' }, lazy .. '/init.lua')
    local lualine = require('lualine')
    package.loaded.lazy = { setup = function(plugins)
        plugins[1].config()
        local found = false
        for _, plugin in ipairs(plugins) do
            if plugin[1] == 'nvim-lualine/lualine.nvim' then
                lualine.setup(plugin.opts)
                found = true
            end
        end
        assert(found, 'App must configure Lualine')
    end }
    local parley = require('parley')
    package.loaded['parley.starter'] = { start = function()
        parley.setup({ chat_dir = vim.fn.stdpath('data') .. '/chats',
            state_dir = vim.fn.stdpath('state') .. '/persisted',
            repo_root = false, providers = {}, api_keys = {}, cliproxy = { manage = false } })
    end }
    dofile(vim.env.PARLEY_RUNTIME .. '/packaging/starter-config/init.lua')
    package.loaded.lazy = nil
    vim.opt.runtimepath:remove(vim.fn.stdpath('data') .. '/lazy/lazy.nvim')
    vim.cmd.edit(vim.fn.stdpath('data') .. '/chats/welcome.md')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn.readfile(vim.env.PARLEY_RUNTIME .. '/packaging/tutorials/welcome.md'))
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    assert(vim.wait(1000, function() return #lualine.get_config().sections.lualine_x > 0 end, 10),
        'Parley model/activity component was not installed')
    local agent = assert(parley._state.agent, 'missing selected agent')
    local get_mode = vim.api.nvim_get_mode
    local function render(mode)
        -- Control the mode input to the real upstream renderer, without needing
        -- an attached UI to keep Neovim in insert mode during a headless script.
        vim.api.nvim_get_mode = function() return { mode = mode, blocking = false } end
        local rendered = vim.api.nvim_eval_statusline(lualine.statusline(true), { maxwidth = 180 }).str
        vim.api.nvim_get_mode = get_mode
        return rendered
    end
    for _, item in ipairs(theme.items()) do
        assert(theme.apply(item.id, { on_applied = parley.setup_highlight }))
        vim.wait(30)
        for mode, label in pairs({ n = 'NORMAL', i = 'INSERT', v = 'VISUAL' }) do
            local rendered = render(mode)
            assert(rendered:find(label, 1, true), item.id .. ': missing ' .. label)
            assert(rendered:find('welcome.md', 1, true), item.id .. ': missing chat name')
            assert(rendered:find(agent, 1, true), item.id .. ': missing selected model')
            assert(rendered:find('3:1', 1, true), item.id .. ': missing cursor position')
            assert(not rendered:find('utf%-8') and not rendered:find('unix'), 'technical clutter')
            local group = 'lualine_a_' .. ({ n = 'normal', i = 'insert', v = 'visual' })[mode]
            local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
            assert(hl.fg and hl.bg and hl.fg ~= hl.bg, item.id .. ': invisible mode block')
        end
        print('PASS statusline ' .. item.id)
    end
end)
if not ok then io.stderr:write(tostring(err) .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
