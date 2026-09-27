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

-- Typing drives blink through vim.on_key and scheduled callbacks, so each case
-- feeds keys, then waits for the event loop to settle before observing.
local cases = { { keys = ':mkpv', want = 'MarkdownPreview' }, { keys = ':thm', want = 'ParleyTheme' } }
local results, step = {}, 0
local function next_case()
    step = step + 1
    local case = cases[step]
    if not case then
        -- Insert mode in a chat-like buffer: no sources, no menu, no blink keys.
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'MarkdownPreview marshmallow markdown' })
        vim.api.nvim_feedkeys('Gomar', 'nt', false)
        vim.defer_fn(function()
            local ok_insert, insert_err = pcall(function()
                assert(vim.api.nvim_get_mode().mode == 'i')
                assert(#list.items == 0, 'insert mode produced completion items')
                assert(not require('blink.cmp').is_menu_visible(), 'insert mode opened a menu')
                -- blink installs insert keys buffer-locally on InsertEnter; with -u NONE
                -- nothing else maps this buffer, so any entry is a claimed key.
                local claimed = vim.api.nvim_buf_get_keymap(0, 'i')
                assert(#claimed == 0, 'blink claimed insert key ' .. (claimed[1] and claimed[1].lhs or ''))
                for _, map in ipairs(vim.api.nvim_get_keymap('c')) do
                    assert(map.lhs ~= '<Left>' and map.lhs ~= '<Right>', 'cmdline arrows claimed')
                end
            end)
            if not ok_insert then return fail(insert_err) end
            for _, line in ipairs(results) do print(line) end
            print('PASS completion insert-mode quiet')
            vim.cmd('qa!')
        end, 800)
        return
    end
    vim.api.nvim_feedkeys(case.keys, 'nt', false)
    vim.defer_fn(function()
        local found = labels()
        local visible = require('blink.cmp').is_menu_visible()
        if not (visible and found[1] == case.want) then
            return fail(case.keys .. ': want ' .. case.want .. ' first in a visible menu, got '
                .. vim.inspect(found) .. ' visible=' .. tostring(visible))
        end
        results[#results + 1] = 'PASS completion ' .. case.keys .. ' -> ' .. case.want
        vim.api.nvim_feedkeys(vim.keycode('<C-u><Esc>'), 'nt', false)
        vim.defer_fn(next_case, 200)
    end, 800)
end
vim.defer_fn(next_case, 100)
