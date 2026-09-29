-- Real Blink and real prep_chat; only the app's installer/theme startup are fake.
local runtime = assert(vim.env.PARLEY_RUNTIME)
local profile = vim.env.PARLEY_SPELL_PROFILE or 'plugin'
vim.opt.rtp:prepend(runtime)
vim.opt.rtp:append(assert(vim.env.PARLEY_BLINK_RUNTIME))
vim.g.parley_test_mode = true
local cmp = require('blink.cmp')
if profile == 'app' then
    local lazy = vim.fn.stdpath('data') .. '/lazy/lazy.nvim/lua/lazy'
    vim.fn.mkdir(lazy, 'p')
    vim.fn.writefile({ '-- installer fixture' }, lazy .. '/init.lua')
    package.loaded.lazy = { setup = function(plugins)
        for _, plugin in ipairs(plugins) do
            if plugin[1] == 'saghen/blink.cmp' then cmp.setup(plugin.opts) end
        end
    end }
    package.loaded['parley.theme'] = { packaged_plugins = function() return { {} } end,
        capture_startup = function() end, apply = function() end, load = function() end }
    package.loaded['parley.starter'] = { start = function() end }
    dofile(runtime .. '/packaging/starter-config/init.lua')
    package.loaded.lazy = nil
else
    cmp.setup({ fuzzy = { implementation = 'lua' }, sources = { default = { 'buffer' },
        providers = { buffer = { min_keyword_length = 2, opts = { get_bufnrs = function() return { vim.api.nvim_get_current_buf() } end } } } },
        completion = { list = { selection = { preselect = false, auto_insert = false } } },
        keymap = { preset = 'none', ['<Tab>'] = { 'select_next', 'fallback' },
            ['<Down>'] = { 'select_next', 'fallback' }, ['<Up>'] = { 'select_prev', 'fallback' },
            ['<CR>'] = { 'select_and_accept', 'fallback' }, ['<Esc>'] = { 'hide', 'fallback' } } })
end
local parley = require('parley')
local chat_dir = vim.fn.stdpath('state') .. '/chats'
vim.fn.mkdir(chat_dir, 'p')
parley.setup({ chat_dir = chat_dir, state_dir = vim.fn.stdpath('state') .. '/parley', providers = {}, api_keys = {},
    chat_spell = { enable = false, blink = true, typeahead = false, debounce_ms = 30, spelllang = 'en_us', max_suggest = 9 } })
local controller = require('parley.spell_blink')
local list = require('blink.cmp.completion.list')
local step, count, buf = 'startup', 0, nil
local function pause(ms) coroutine.yield(ms) end
local function wait_for(predicate, message)
    local deadline = vim.uv.hrtime() + 2000000000
    while not predicate() and vim.uv.hrtime() < deadline do pause(10) end
    assert(predicate(), message)
end
local function keys(text)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(text, true, false, true), 'm', false)
    pause(30)
end
local function spelling()
    if not cmp.is_menu_visible() then return false end
    for _, item in ipairs(cmp.get_items()) do if item.data and item.data.parley_spell then return true end end
    return false
end
local function text() return vim.api.nvim_get_current_line() end
local function chat(line, col)
    if buf then controller.detach(buf) end
    cmp.hide()
    vim.cmd('stopinsert')
    wait_for(function() return vim.api.nvim_get_mode().mode == 'n' end, 'not Normal')
    count = count + 1
    local path = chat_dir .. '/2026-09-29.spell-' .. count .. '.md'
    local lines = { '---', 'topic: spelling', 'file: 2026-09-29.spell-' .. count .. '.md',
        'model: test-model', 'provider: openai', '---', '', '💬:', line }
    vim.fn.writefile(lines, path)
    vim.cmd('edit! ' .. vim.fn.fnameescape(path))
    buf = vim.api.nvim_get_current_buf()
    parley.prep_chat(buf, path)
    vim.api.nvim_win_set_cursor(0, { 9, col })
    pause(10)
end
local run = coroutine.create(function()
    step = 'Normal movement, whole-word acceptance and undo'
    chat('before teh after', 0)
    keys('7l')
    wait_for(spelling, 'Normal motion did not show spelling')
    assert(vim.api.nvim_get_mode().mode == 'n')
    keys('<Tab>')
    local first = assert(list.get_selected_item()).label
    keys('<Down>')
    assert(list.get_selected_item().label ~= first, 'Down did not select a distinct item')
    keys('<Up>')
    assert(list.get_selected_item().label == first)
    keys('<CR>')
    wait_for(function() return text() == 'before ' .. first .. ' after' end, 'Normal acceptance did not replace exactly the word')
    assert(vim.api.nvim_get_mode().mode == 'n')
    keys('u')
    assert(text() == 'before teh after', 'Normal undo did not restore typo')

    step = 'Esc suppression, no-menu keys and retrigger'
    wait_for(spelling, 'undo did not reobserve typo')
    keys('<Esc>')
    assert(vim.api.nvim_get_mode().mode == 'n')
    pause(150)
    assert(not spelling(), 'same word reopened after Esc')
    keys('0')
    pause(80)
    keys('8l')
    wait_for(spelling, 'return to typo did not retrigger')

    step = 'Insert entry at mid-word, whole replacement and undo'
    chat('é teh after', 4)
    keys('i')
    wait_for(function() return vim.api.nvim_get_mode().mode == 'i' and spelling() end, 'Insert entry did not show short typo')
    keys('<Tab>')
    local replacement = assert(list.get_selected_item()).label
    keys('<CR>')
    wait_for(function() return text() == 'é ' .. replacement .. ' after' end, 'Insert mid-word stranded suffix')
    assert(vim.api.nvim_get_mode().mode == 'i', 'acceptance left Insert')
    keys('<Esc>')
    if vim.api.nvim_get_mode().mode == 'i' then keys('<Esc>') end
    keys('u')
    assert(text() == 'é teh after', 'Insert undo did not restore whole word')

    step = 'Contiguous typing, Insert Esc and correct/non-word positions'
    chat('', 0)
    keys('irecieve')
    wait_for(spelling, 'typing did not show spelling')
    assert(text() == 'recieve', 'typing silently changed text')
    keys('<Esc>')
    assert(vim.api.nvim_get_mode().mode == 'i', 'menu Esc unexpectedly left Insert')
    pause(150)
    assert(not spelling(), 'Insert dismissal reopened')
    keys('<Esc>')
    chat('receive !', 2)
    pause(180)
    assert(not cmp.is_menu_visible(), 'correct-word motion forced a completion menu')
    keys('$')
    pause(180)
    assert(not spelling(), 'punctuation opened spelling')

    step = 'Preview policy across explicit selection and async refresh'
    local selection = require('blink.cmp.config').completion.list.selection
    selection.auto_insert, selection.preselect = true, true
    chat('before teh after', 8)
    wait_for(spelling, 'custom configuration missing menu')
    keys('<Down>')
    assert(text() == 'before teh after', 'navigation preview edited text')
    -- Replay a real list refresh with current items; this is the pinned path
    -- that reselects an existing item without navigation options.
    list.show(list.context, { parley_spell = vim.deepcopy(list.items) })
    pause(30)
    assert(text() == 'before teh after', 'refresh preview edited text')
    assert(selection.auto_insert == true and selection.preselect == true, 'user config mutated')
    selection.auto_insert, selection.preselect = false, false

    step = 'Delayed resolve, cursor excursion and stale rejection'
    local source = require('blink.cmp.sources.lib').get_provider_by_id('parley_spell').module
    local pending
    source.resolve = function(_, item, callback) pending = function() callback(item) end end
    keys('<CR>')
    wait_for(function() return pending ~= nil end, 'resolve seam did not delay')
    keys('0')
    keys('8l')
    pending()
    pause(100)
    assert(text() == 'before teh after', 'late acceptance changed moved target')
    source.resolve = nil

    step = 'Current-buffer completion still present'
    chat('marshmallow marmalade', 0)
    keys('A<CR>ma')
    wait_for(function()
        for _, item in ipairs(cmp.get_items()) do if item.label == 'marshmallow' then return true end end
        return false
    end, 'buffer completion lost')
    step = 'Spelling latency sample'
    local samples = {}
    for _ = 1, 10 do
        for _, word in ipairs({ 'teh', 'recieve', 'mispeling' }) do
            local started = vim.uv.hrtime()
            vim.fn.spellsuggest(word, 9)
            samples[#samples + 1] = (vim.uv.hrtime() - started) / 1000000
        end
    end
    table.sort(samples)
    print(string.format('spell timing %s en_us n=%d p50=%.2fms p95=%.2fms', profile, #samples,
        samples[math.ceil(#samples / 2)], samples[math.ceil(#samples * .95)]))
    print('PASS spell compatibility ' .. profile)
    vim.cmd('qa!')
end)
local function resume()
    local ok, delay = coroutine.resume(run)
    if not ok then
        io.stderr:write('FAIL ' .. profile .. ' / ' .. step .. ': ' .. tostring(delay) .. '\n')
        vim.cmd('cquit 1')
    elseif coroutine.status(run) ~= 'dead' then vim.defer_fn(resume, delay or 10) end
end
vim.schedule(resume)
vim.defer_fn(function() io.stderr:write('spell compatibility timeout: ' .. step .. '\n'); vim.cmd('cquit 1') end, 30000)
