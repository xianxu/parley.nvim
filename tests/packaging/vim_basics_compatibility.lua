-- Run via ./parley_app --headless -c 'luafile <absolute path to this file>'.
-- Use an isolated PARLEY_DEMO_DIR. No login or generation is needed.
vim.schedule(function()
    local ok, err = pcall(function()
        local p = require('parley')
        local path = p.config.chat_dir .. '/vim-basics.md'
        vim.cmd.edit(vim.fn.fnameescape(path))
        assert(p.not_chat(0, path) == nil)
        assert(vim.o.ignorecase and vim.o.smartcase)
        assert(vim.o.clipboard == 'unnamedplus')
        for _, key in ipairs({ '<C-i>', '<Tab>', '<C-o>', 'u', '<C-r>', 'v', 'V', 'y', 'd', 'p' }) do
            assert(vim.fn.maparg(key, 'n') == '', 'unexpected mapping: ' .. key)
        end
        -- Stateful clipboard at Neovim's provider seam; never touch the host clipboard.
        local copied = { {}, 'v' }
        vim.g.clipboard = { name = 'tutorial test', cache_enabled = 0,
            copy = { ['+'] = function(lines, kind) copied = { lines, kind } end,
                     ['*'] = function(lines, kind) copied = { lines, kind } end },
            paste = { ['+'] = function() return copied end, ['*'] = function() return copied end } }
        vim.g.loaded_clipboard_provider = nil
        vim.cmd.runtime('autoload/provider/clipboard.vim')
        local function normal(keys)
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'xt', false)
        end
        normal('gg')
        normal('/^practice-rainbow<CR>')
        local row = vim.fn.line('.')
        assert(vim.api.nvim_get_current_line():match('^practice%-rainbow:'))
        normal('<C-o>'); assert(vim.fn.line('.') == 1)
        normal('<C-i>'); assert(vim.fn.line('.') == row)
        normal('<C-o>'); normal('<Tab>'); assert(vim.fn.line('.') == row)
        local original = vim.api.nvim_get_current_line()
        normal('A hello<Esc>')
        assert(vim.api.nvim_get_current_line() == original .. ' hello')
        normal('u'); assert(vim.api.nvim_get_current_line() == original)
        normal('<C-r>'); assert(vim.api.nvim_get_current_line() == original .. ' hello')
        normal('u')
        normal('0Vy'); assert(copied[1][1] == original and copied[2] == 'V')
        normal('p'); assert(vim.fn.getline(row + 1) == original)
        normal('u')
        normal('0v6ly'); assert(copied[1][1] == 'practic')
        normal('0v6ld'); assert(vim.api.nvim_get_current_line() == original:sub(8))
        normal('u')
        normal('0/rainbow<CR>'); local first = vim.fn.col('.')
        normal('n'); local second = vim.fn.col('.')
        assert(second > first)
        normal('N'); assert(vim.fn.col('.') == first)
        normal('0/Rainbow<CR>')
        assert(vim.fn.col('.') == assert(original:find('Rainbow', 1, true)))
        vim.cmd.nohlsearch()
        assert(vim.v.hlsearch == 0)
        vim.cmd.write()
        assert(vim.fn.readfile(path)[row] == original)
        print('VIM Basics: packaged navigation, search, undo/redo, clipboard and save passed')
    end)
    if not ok then io.stderr:write(tostring(err) .. '\n'); vim.cmd('cquit 1')
    else vim.cmd('qa!') end
end)
