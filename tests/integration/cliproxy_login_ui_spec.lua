local ui
local data_dir = vim.fn.tempname()
require('parley.cliproxy')._set_data_dir(data_dir)
local function lines()
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
end
local function press(key)
    local mapping = vim.fn.maparg(key, 'n', false, true)
    assert.is_function(mapping.callback)
    mapping.callback()
end

describe('friendly login window', function()
    after_each(function() if ui then ui.close() end end)

    it('keeps raw output behind details and allows manual browser recovery', function()
        local opened
        local saved = vim.ui.open
        vim.ui.open = function(url) opened = url end
        ui = require('parley.cliproxy_login_ui').open('codex', function() end)
        ui.append('CLIProxyAPI Version: noisy build')
        ui.append('Opening browser: https://auth.example/login?code_challenge=secret')
        assert.matches('browser', lines())
        assert.is_nil(lines():find('noisy', 1, true))
        assert.is_nil(lines():find('secret', 1, true))
        press('o')
        assert.equals('https://auth.example/login?code_challenge=secret', opened)
        press('d')
        assert.matches('noisy build', lines())
        vim.ui.open = saved
    end)

    it('shows device instructions without requiring discovery of details', function()
        ui = require('parley.cliproxy_login_ui').open('qwen', function() end)
        ui.append('Visit https://example.com/device')
        ui.append('Enter code: ABCD-1234')
        assert.matches('ABCD%-1234', lines())
        assert.matches('https://example.com/device', lines())
    end)

    it('keeps failure details available and closes before success resumes', function()
        local original = vim.api.nvim_get_current_win()
        ui = require('parley.cliproxy_login_ui').open('codex', function() end)
        ui.append('Process exited 3: diagnostic')
        ui.finish(false)
        assert.matches('Sign%-in did not finish', lines())
        assert.is_nil(lines():find('diagnostic', 1, true))
        press('d')
        assert.matches('diagnostic', lines())
        ui.finish(true)
        assert.equals(original, vim.api.nvim_get_current_win())
    end)

    it('closing hides the window but explicit cancel calls its owner once', function()
        local cancelled = 0
        ui = require('parley.cliproxy_login_ui').open('claude', function() cancelled = cancelled + 1 end)
        press('<Esc>')
        assert.equals(0, cancelled)
        ui = require('parley.cliproxy_login_ui').open('claude', function() cancelled = cancelled + 1 end)
        press('c')
        assert.equals(1, cancelled)
        ui.close()
        assert.equals(1, cancelled)
    end)
end)
