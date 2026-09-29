-- Run with isolated XDG roots, NVIM_APPNAME=parley, PARLEY_RUNTIME=$PWD and
-- PARLEY_BLINK_RUNTIME at blink.cmp checked out at the starter's pinned commit:
--   nvim --headless -u NONE -i NONE -c 'luafile tests/packaging/completion_compatibility.lua'
-- (not -l: the typed cases run on the event loop after the file returns).
local function fail(err) io.stderr:write(tostring(err) .. '\n'); vim.cmd('cquit 1') end
local blink_dir = assert(vim.env.PARLEY_BLINK_RUNTIME, 'PARLEY_BLINK_RUNTIME')
local ok, err = pcall(function()
    vim.opt.runtimepath:prepend(assert(vim.env.PARLEY_RUNTIME))
    vim.opt.runtimepath:append(blink_dir)
    -- Fake only the installer boundary; run the production starter options
    -- through the real pinned blink.cmp.
    local lazy = vim.fn.stdpath('data') .. '/lazy/lazy.nvim/lua/lazy'
    vim.fn.mkdir(lazy, 'p')
    vim.fn.writefile({ '-- installer fixture' }, lazy .. '/init.lua')
    package.loaded.lazy = { setup = function(plugins)
        local found = false
        for _, plugin in ipairs(plugins) do
            if plugin[1] == 'saghen/blink.cmp' then
                require('blink.cmp').setup(plugin.opts)
                found = true
            end
        end
        assert(found, 'App must configure blink.cmp')
    end }
    package.loaded['parley.theme'] = { packaged_plugins = function() return { {} } end,
        capture_startup = function() end, apply = function() end, load = function() end }
    package.loaded['parley.starter'] = { start = function() end }
    dofile(vim.env.PARLEY_RUNTIME .. '/packaging/starter-config/init.lua')
    package.loaded.lazy = nil
end)
if not ok then return fail(err) end

assert(require('blink.cmp.fuzzy').implementation_type == 'lua')
for _, pattern in ipairs({ '**/*.so', '**/*.dylib', '**/*.dll' }) do
    assert(#vim.fn.globpath(blink_dir, pattern, false, true) == 0, 'blink native library present: ' .. pattern)
end
vim.api.nvim_create_user_command('MarkdownPreview', function() end, {})
vim.api.nvim_create_user_command('ParleyTheme', function() end, {})

local list = require('blink.cmp.completion.list')
local function labels()
    local out = {}
    for i, item in ipairs(list.items) do out[i] = item.label end
    return out
end

-- Exercise actual keys with event-loop turns between actions.
local cmp = require('blink.cmp')
local results, step = {}, 0
local function has(label) return vim.tbl_contains(labels(), label) end
local cases = {
    { keys = ':mkpv', check = function()
        assert(cmp.is_menu_visible() and labels()[1] == 'MarkdownPreview')
    end },
    { keys = '<C-u><Esc>', check = function() end },
    { keys = ':thm', check = function()
        assert(cmp.is_menu_visible() and labels()[1] == 'ParleyTheme')
    end },
    { keys = '<C-u><Esc>', check = function()
        -- A visible second buffer must not contribute its vocabulary.
        vim.cmd('vnew')
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'marzipan' })
        vim.cmd('wincmd p')
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'marshmallow', '' })
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
    end },
    { keys = 'im', check = function()
        assert(not cmp.is_menu_visible(), 'one character opened a menu')
    end },
    { keys = 'a', check = function()
        assert(cmp.is_menu_visible() and has('marshmallow'), 'current-buffer word missing')
        assert(not has('marzipan'), 'another buffer contributed words')
        assert(list.selected_item_idx == nil, 'item was preselected')
        assert(vim.api.nvim_get_current_line() == 'ma', 'typing was replaced')
        for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, 'i')) do
            assert(map.lhs ~= '<CR>', 'blink claimed Enter')
        end
        for _, map in ipairs(vim.api.nvim_get_keymap('c')) do
            assert(map.lhs ~= '<Left>' and map.lhs ~= '<Right>', 'cmdline arrows claimed')
        end
    end },
    { keys = '<C-n>', check = function()
        assert(list.selected_item_idx ~= nil, 'Ctrl-n did not select')
        assert(vim.api.nvim_get_current_line() == 'ma', 'selection inserted text')
    end },
    { keys = '<C-y>', check = function()
        assert(vim.api.nvim_get_current_line() == 'marshmallow', 'Ctrl-y did not accept')
    end },
    { keys = '<CR>ma', check = function()
        assert(cmp.is_menu_visible(), 'menu did not reopen')
    end },
    { keys = '<C-e>', check = function()
        assert(not cmp.is_menu_visible(), 'Ctrl-e did not dismiss')
        assert(vim.api.nvim_get_current_line() == 'ma', 'dismiss changed the text')
    end },
    { keys = '<C-u>ma', check = function() assert(cmp.is_menu_visible()) end },
    { keys = '<CR>', check = function()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        assert(lines[3] == 'ma' and lines[4] == '', 'Enter accepted a suggestion instead of newline')
    end },
}
local function next_case()
    step = step + 1
    local case = cases[step]
    if not case then
        for _, line in ipairs(results) do print(line) end
        print('PASS command-line and current-buffer completion keyboard behavior')
        vim.cmd('qa!')
        return
    end
    vim.api.nvim_feedkeys(vim.keycode(case.keys), 'mt', false)
    vim.defer_fn(function()
        local passed, why = pcall(case.check)
        if not passed then return fail('step ' .. step .. ': ' .. tostring(why)) end
        results[#results + 1] = 'PASS completion step ' .. step .. ' ' .. case.keys
        next_case()
    end, 300)
end
vim.defer_fn(next_case, 100)
