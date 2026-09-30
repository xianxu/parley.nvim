-- Runs AFTER the real starter, with real immutable plugin files and no external network.
local cmp = require('blink.cmp')
local function pause(ms) coroutine.yield(ms) end
local function wait_for(predicate, message)
    local deadline = vim.uv.hrtime() + 15000000000
    while not predicate() and vim.uv.hrtime() < deadline do pause(20) end
    assert(predicate(), message)
end
local function keys(value)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), 'm', false)
    pause(40)
end
local step = 'startup'
local run = coroutine.create(function()
    local deps = require('parley.editor_dependencies')
    local plugins = require('lazy.core.config').plugins
    for _, plugin in ipairs(deps.plugins('app')) do
        if plugin.name ~= 'lazy.nvim' then
            local loaded = assert(plugins[plugin.name], 'missing Lazy spec ' .. plugin.name)
            assert(loaded.dir == vim.env.PARLEY_EDITOR_BUNDLE .. '/plugins/' .. plugin.name)
        end
    end
    local options = require('lazy.core.config').options
    assert(not options.install.missing and not options.pkg.enabled and not options.rocks.enabled and not options.local_spec)
    assert(vim.fn.exists(':Telescope') == 2, 'Telescope missing')
    assert(#vim.o.statusline > 0, 'statusline missing')
    step = 'themes'
    for _, choice in ipairs(require('parley.theme').items()) do
        assert(require('parley.theme').apply(choice.id))
        assert(vim.g.colors_name == choice.colorscheme)
    end
    step = 'completion'
    local parley = require('parley')
    local path = parley.config.chat_dir .. '/2026-09-30.00-00-00.000_bundle-smoke.md'
    vim.fn.writefile({ '---', 'topic: Bundle smoke', 'file: 2026-09-30.00-00-00.000_bundle-smoke.md',
        '---', '', '💬:', 'bundleexample before teh after', '' }, path)
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
    parley.prep_chat(vim.api.nvim_get_current_buf(), path)
    vim.api.nvim_win_set_cursor(0, { 8, 0 })
    keys('ibundleex')
    wait_for(function()
        for _, item in ipairs(cmp.get_items()) do
            if item.source_id == 'buffer' and item.label == 'bundleexample' then return true end
        end
    end, 'real buffer completion missing')
    cmp.hide()
    keys('<Esc>')
    vim.api.nvim_win_set_cursor(0, { 7, 22 })
    wait_for(function()
        for _, item in ipairs(cmp.get_items()) do if item.data and item.data.parley_spell then return true end end
    end, 'real Normal spelling missing')
    cmp.hide()
    step = 'preview'
    vim.cmd([[
        function! ParleyBundlePreviewURL(url) abort
            let g:parley_bundle_preview_url = a:url
        endfunction
    ]])
    vim.g.mkdp_browserfunc = 'ParleyBundlePreviewURL'
    vim.cmd('MarkdownPreview')
    wait_for(function() return type(vim.g.parley_bundle_preview_url) == 'string' end, 'Preview did not start')
    local url = vim.g.parley_bundle_preview_url
    assert(url:match('^http://localhost:') or url:match('^http://127%.0%.0%.1:'), 'Preview not loopback: ' .. url)
    -- Preview asks Neovim for buffer state while serving HTTP. Keep the editor
    -- event loop free instead of synchronously waiting inside its callback.
    local result
    vim.system({ 'curl', '--fail', '--silent', '--show-error', '--max-time', '10', url }, { text = true },
        function(value) result = value end)
    wait_for(function() return result ~= nil end, 'Preview request did not complete')
    assert(result.code == 0 and result.stdout:find('<html', 1, true), 'Preview HTTP request failed: ' .. (result.stderr or ''))
    vim.fn['mkdp#rpc#stop_server']()
    print('PASS bundled production startup, themes, buffer completion, spelling, Preview HTTP')
    vim.cmd('qa!')
end)
local function advance()
    local ok, delay = coroutine.resume(run)
    if not ok then
        pcall(vim.fn['mkdp#rpc#stop_server'])
        io.stderr:write('Bundle smoke failed at ' .. step .. ': ' .. tostring(delay) .. '\n')
        vim.cmd('cquit 1')
    elseif coroutine.status(run) ~= 'dead' then vim.defer_fn(advance, delay or 10) end
end
vim.defer_fn(advance, 100)
vim.defer_fn(function() io.stderr:write('Bundle smoke timeout: ' .. step .. '\n'); vim.cmd('cquit 1') end, 60000)
