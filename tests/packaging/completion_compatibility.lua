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
local first_candidate
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
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'marshmallow marmalade', '' })
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
    end },
    { keys = 'im', check = function()
        assert(not cmp.is_menu_visible(), 'one character opened a menu')
    end },
    { keys = 'a', check = function()
        assert(cmp.is_menu_visible() and has('marshmallow') and has('marmalade'), 'current-buffer words missing')
        first_candidate = labels()[1]
        assert(not has('marzipan'), 'another buffer contributed words')
        assert(list.selected_item_idx == nil, 'item was preselected')
        assert(vim.api.nvim_get_current_line() == 'ma', 'typing was replaced')
        for _, map in ipairs(vim.api.nvim_get_keymap('c')) do
            assert(map.lhs ~= '<Left>' and map.lhs ~= '<Right>', 'cmdline arrows claimed')
        end
    end },
    { keys = '<Tab>', check = function()
        assert(list.selected_item_idx == 1, 'Tab did not select first candidate')
        assert(vim.api.nvim_get_current_line() == 'ma', 'selection inserted text')
    end },
    { keys = '<Down>', check = function()
        assert(list.selected_item_idx == 2, 'Down did not advance to second candidate')
        assert(list.get_selected_item().label ~= first_candidate, 'candidates must differ')
    end },
    { keys = '<Up>', check = function()
        assert(list.selected_item_idx == 1, 'Up did not move to first candidate')
        assert(list.get_selected_item().label == first_candidate)
        assert(vim.api.nvim_get_current_line() == 'ma', 'selection inserted text')
    end },
    { keys = '<CR>', check = function()
        assert(vim.api.nvim_get_current_line() == first_candidate, 'Enter did not accept selected item')
    end },
    { keys = '<CR>ma', check = function()
        assert(cmp.is_menu_visible(), 'menu did not reopen')
    end },
    { keys = '<Esc>', check = function()
        assert(not cmp.is_menu_visible(), 'Esc did not dismiss')
        assert(vim.fn.mode() == 'i', 'Esc dismissal left Insert mode')
        assert(vim.api.nvim_get_current_line() == 'ma', 'dismiss changed the text')
    end },
    { keys = '<C-u>ma', check = function() assert(cmp.is_menu_visible()) end },
    { keys = '<CR>', check = function()
        assert(vim.api.nvim_get_current_line() == first_candidate, 'Enter did not accept unselected first item')
    end },
    { keys = '<CR>', check = function()
        assert(vim.api.nvim_get_current_line() == '', 'Enter without menu did not insert newline')
    end },
    { keys = '<Tab>', check = function()
        assert(vim.api.nvim_get_current_line():match('^%s+$'), 'Tab without menu did not insert indentation')
    end },
    { keys = '<Up>', check = function()
        assert(vim.api.nvim_win_get_cursor(0)[1] == 3, 'Up without menu did not move up')
    end },
    { keys = '<Down>', check = function()
        assert(vim.api.nvim_win_get_cursor(0)[1] == 4, 'Down without menu did not move down')
    end },
    { keys = '<Esc>', check = function()
        assert(vim.fn.mode() == 'n', 'Esc without menu did not leave Insert mode')
        -- Exercise the app policy and production chat mapping together with Blink.
        local parley = require('parley')
        local roots = { data = vim.fn.stdpath('data') .. '/pairing', state = vim.fn.stdpath('state') }
        local options = require('parley.starter_config').options(roots)
        options.providers, options.api_keys = {}, {}
        parley.setup(options)
        vim.fn.mkdir(parley.config.chat_dir, 'p')
        local path = parley.config.chat_dir .. '/2026-09-29-completion.md'
        vim.fn.writefile({ '# topic: pairing', '- file: completion.md', '---', '',
            'marshmallow marmalade', '' }, path)
        vim.cmd('edit ' .. vim.fn.fnameescape(path))
        local buf = vim.api.nvim_get_current_buf()
        parley.prep_chat(buf, path)
        assert(parley._prepared_bufs[buf], 'chat was not prepared')
        assert(parley.config.default_keymaps == false, 'test must use the app shortcut policy')
        vim.api.nvim_win_set_cursor(0, { 6, 0 })
    end },
    { keys = 'i@@one@@@@two', check = function()
        assert(vim.api.nvim_get_current_line() == '@@one@@@@two@@', 'adjacent pairing with Blink failed')
    end },
    { keys = '@@<CR>ma', check = function()
        assert(vim.api.nvim_buf_get_lines(0, 5, 6, false)[1] == '@@one@@@@two@@', 'closers duplicated')
        assert(cmp.is_menu_visible() and has('marshmallow') and has('marmalade'),
            'chat buffer completion candidates missing')
    end },
    { keys = '<Tab>', check = function()
        assert(list.selected_item_idx == 1, 'chat Tab selection failed')
        first_candidate = list.get_selected_item().label
    end },
    { keys = '<Down>', check = function()
        assert(list.selected_item_idx == 2, 'chat Down selection failed')
    end },
    { keys = '<Up>', check = function()
        assert(list.get_selected_item().label == first_candidate, 'chat Up selection failed')
    end },
    { keys = '<CR>', check = function()
        assert(vim.api.nvim_get_current_line() == first_candidate, 'chat Enter acceptance failed')
    end },
    { keys = '<CR>ma', check = function() assert(cmp.is_menu_visible()) end },
    { keys = '<Esc>', check = function()
        assert(not cmp.is_menu_visible() and vim.fn.mode() == 'i', 'chat Esc dismissal failed')
        assert(vim.api.nvim_get_current_line() == 'ma', 'chat dismissal changed text')
    end },
    { keys = '<C-u>ma', check = function() assert(cmp.is_menu_visible()) end },
    { keys = '<C-n>', check = function()
        first_candidate = list.get_selected_item().label
    end },
    { keys = '<C-n><C-p>', check = function()
        assert(list.get_selected_item().label == first_candidate, 'Ctrl-n/p navigation changed')
    end },
    { keys = '<C-y>', check = function()
        assert(vim.api.nvim_get_current_line() == first_candidate, 'chat completion acceptance failed')
    end },
    { keys = '<CR>ma', check = function() assert(cmp.is_menu_visible()) end },
    { keys = '<C-e>', check = function()
        assert(not cmp.is_menu_visible(), 'Ctrl-e dismissal changed')
        first_candidate = 'ma'
    end },
    { keys = ' @@after', check = function()
        assert(vim.api.nvim_get_current_line() == first_candidate .. ' @@after@@',
            'pairing after completion acceptance failed')
    end },
    { keys = '@@!<Esc>', check = function()
        assert(vim.api.nvim_get_current_line() == first_candidate .. ' @@after@@!',
            'closer skipping after completion acceptance failed')
    end },
}
local function next_case()
    step = step + 1
    local case = cases[step]
    if not case then
        for _, line in ipairs(results) do print(line) end
        print('PASS command-line, current-buffer completion, and app chat pairing keyboard behavior')
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
