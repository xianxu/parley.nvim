-- One chat spell controller; pure spell_state authorizes every request and edit.
local model = require('parley.spell_state')
local M = {}
local controllers, registrations, adapters = {}, setmetatable({}, { __mode = 'k' }), {}
local source_id = 'parley_spell'
local dispatch, observe, activate

local function number(value, default, minimum, maximum)
    if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then return default end
    return math.max(minimum, math.min(maximum, math.floor(value)))
end

-- Blink 1.10.2 has no public readiness signal. Never require this internal
-- module to probe readiness: buffer_events exists only after setup activates it.
local function backend()
    local trigger = package.loaded['blink.cmp.completion.trigger']
    if not trigger or not trigger.buffer_events then return nil end
    local ok, cmp = pcall(require, 'blink.cmp')
    local list = package.loaded['blink.cmp.completion.list']
    local sources = package.loaded['blink.cmp.sources.lib']
    if not ok or not list or type(list.get_selection_mode) ~= 'function'
        or not sources or type(sources.get_enabled_provider_ids) ~= 'function' then return nil end
    return { cmp = cmp, list = list, ready = true,
        enabled_providers = function() return sources.get_enabled_provider_ids('default') end }
end

local function mapping(buf, mode, key)
    local encoded = vim.api.nvim_replace_termcodes(key, true, true, true)
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
        if vim.api.nvim_replace_termcodes(map.lhs, true, true, true) == encoded then return map end
    end
end

local function release(c)
    if not c.leases then return end
    if vim.api.nvim_buf_is_valid(c.buf) then
        for _, lease in ipairs(c.leases) do
            local current = mapping(c.buf, lease.mode, lease.key)
            if current and current.callback == lease.callback then
                vim.keymap.del(lease.mode, lease.key, { buffer = c.buf })
                if lease.previous then
                    vim.api.nvim_buf_call(c.buf, function() vim.fn.mapset(lease.mode, false, lease.previous) end)
                end
            end
        end
    end
    c.leases = nil
end

local function lease(c)
    if c.leases then return end
    c.leases = {}
    local cmp = c.backend.cmp
    local actions = {
        ['<Tab>'] = function() cmp.select_next({ auto_insert = false }) end,
        ['<Down>'] = function() cmp.select_next({ auto_insert = false }) end,
        ['<Up>'] = function() cmp.select_prev({ auto_insert = false }) end,
        ['<CR>'] = function() cmp.select_and_accept() end,
        ['<Esc>'] = function() dispatch(c, { kind = 'dismiss' }) end,
    }
    for _, mode in ipairs({ 'n', 'i' }) do
        for key, callback in pairs(actions) do
            c.leases[#c.leases + 1] = { mode = mode, key = key, previous = mapping(c.buf, mode, key), callback = callback }
            vim.keymap.set(mode, key, callback, { buffer = c.buf, silent = true, desc = 'parley: Blink spelling menu' })
        end
    end
end

-- Preserve config values and foreign contexts. Blink reselects on async refresh
-- without passing navigation options; this is the narrow version-dependent seam.
local function install_adapter(c)
    local list = c.backend.list
    local adapter = adapters[list]
    if not adapter then
        adapter = { original = list.get_selection_mode, owners = {} }
        adapter.wrapper = function(context)
            local result = adapter.original(context)
            for owner in pairs(adapter.owners) do
                if context and owner.context == context.id and owner.buf == context.bufnr then
                    result = vim.tbl_extend('force', result, { auto_insert = false })
                    break
                end
            end
            return result
        end
        list.get_selection_mode, adapters[list] = adapter.wrapper, adapter
    end
    adapter.owners[c] = true
end

local function uninstall_adapter(c)
    if not c.backend then return end
    local list = c.backend.list
    local adapter = adapters[list]
    if not adapter then return end
    adapter.owners[c] = nil
    if not next(adapter.owners) then
        if list.get_selection_mode == adapter.wrapper then list.get_selection_mode = adapter.original end
        adapters[list] = nil
    end
end

local function snapshot(c)
    if not vim.api.nvim_buf_is_valid(c.buf) or vim.api.nvim_get_current_buf() ~= c.buf then return nil end
    local mode = vim.api.nvim_get_mode().mode
    if mode ~= 'n' and mode ~= 'i' then return nil end
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    if #line > 16384 then return nil end
    local spans, offset = {}, 0
    -- Neovim's Unicode character classes, not Lua's byte-only %a.
    local pattern = [=[\v[[:alpha:]]+(['’][[:alpha:]]+)*]=]
    while offset < #line do
        local match = vim.fn.matchstrpos(line, pattern, offset)
        if match[2] < 0 then break end
        spans[#spans + 1] = { start_col = match[2], end_col = match[3] }
        offset = match[3]
    end
    local target = model.target_at(line, cursor[2], mode, spans)
    if not target then return nil end
    target.buf, target.win, target.row = c.buf, vim.api.nvim_get_current_win(), cursor[1] - 1
    target.col, target.mode, target.tick = cursor[2], mode, vim.api.nvim_buf_get_changedtick(c.buf)
    target.max_suggest = c.max_suggest
    return target
end

local function cancel(c)
    if c.timer then c.timer:stop(); c.timer:close(); c.timer = nil end
end

local function hide(c)
    if c.context and c.backend then
        local current = c.backend.cmp.get_context()
        if current and current.id == c.context then c.backend.cmp.hide() end
    end
    c.context = nil
end

dispatch = function(c, event)
    local effects
    c.state, effects = model.transition(c.state, event)
    for _, effect in ipairs(effects) do
        if effect.kind == 'cancel' then cancel(c)
        elseif effect.kind == 'hide' then hide(c)
        elseif effect.kind == 'release' then release(c)
        elseif effect.kind == 'lease' then lease(c)
        elseif effect.kind == 'schedule' then
            cancel(c)
            c.timer = vim.uv.new_timer()
            c.timer:start(c.debounce_ms, 0, vim.schedule_wrap(function()
                if controllers[c.buf] ~= c or c.state.generation ~= effect.generation then return end
                cancel(c)
                dispatch(c, { kind = 'timer', generation = effect.generation })
            end))
        elseif effect.kind == 'show' then
            local live = snapshot(c)
            if live then live.generation = c.state.generation end
            if model.accepts(effect.evidence, live) and c.active
                and require('parley.spell_source').is_misspelled(live) then
                local providers = live.mode == 'n' and { source_id } or c.backend.enabled_providers()
                if not vim.tbl_contains(providers, source_id) then providers = vim.list_extend(vim.deepcopy(providers), { source_id }) end
                c.backend.cmp.show({ providers = providers })
            end
        end
    end
    return effects
end

activate = function(c)
    c.backend = c.backend or backend()
    local dep = c.backend
    if not dep or not dep.ready or type(dep.list.get_selection_mode) ~= 'function' then return false end
    if not registrations[dep.cmp] then
        dep.cmp.add_source_provider(source_id, { name = 'Spelling', module = 'parley.spell_source',
            score_offset = 100, min_keyword_length = 0 })
        registrations[dep.cmp] = {}
    end
    local ft = vim.bo[c.buf].filetype
    if not registrations[dep.cmp][ft] then
        dep.cmp.add_filetype_source(ft, source_id)
        registrations[dep.cmp][ft] = true
    end
    if not c.active then
        install_adapter(c)
        c.active = true
        if c.on_ready then c.on_ready() end
    end
    return true
end

observe = function(c)
    if controllers[c.buf] ~= c then return end
    if activate(c) then dispatch(c, { kind = 'observe', target = snapshot(c) }) end
end

function M.owns(buf)
    local c = controllers[buf]
    return c ~= nil and c.active == true
end

function M.source_target(buf)
    local c = controllers[buf]
    if not c or not c.active then return nil end
    for _, effect in ipairs(dispatch(c, { kind = 'source_request', target = snapshot(c) })) do
        if effect.kind == 'admitted' then return effect.evidence end
    end
end

function M.consume(evidence)
    local c = evidence and controllers[evidence.buf]
    if not c then return false end
    local live = snapshot(c)
    if live then live.generation = c.state.generation end
    for _, effect in ipairs(dispatch(c, { kind = 'consume', evidence = evidence, live = live })) do
        if effect.kind == 'consumed' then return true end
    end
    return false
end

function M.request(buf)
    local c = controllers[buf or vim.api.nvim_get_current_buf()]
    if c and activate(c) then dispatch(c, { kind = 'request', target = snapshot(c) }) end
end

function M.detach(buf)
    local c = controllers[buf]
    if not c then return end
    dispatch(c, { kind = 'detach' })
    uninstall_adapter(c)
    pcall(vim.api.nvim_del_augroup_by_id, c.group)
    controllers[buf] = nil
end

function M.attach(buf, opts, dependency)
    M.detach(buf)
    if not opts.blink then return false end
    local c = { buf = buf, state = model.new(), backend = dependency, on_ready = opts.on_ready,
        debounce_ms = number(opts.debounce_ms, 180, 0, 5000), max_suggest = number(opts.max_suggest, 9, 1, 20) }
    controllers[buf] = c
    c.group = vim.api.nvim_create_augroup('ParleySpellBlink_' .. buf, { clear = true })
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'TextChanged', 'TextChangedI', 'TextChangedP',
        'InsertEnter', 'InsertLeave', 'BufEnter', 'FileType' }, { group = c.group, buffer = buf, callback = function()
        dispatch(c, { kind = 'invalidate' })
        -- Observe at the boundary as well as after mode transitions settle, so
        -- coalescing cannot erase a visit to another word while dismissed.
        observe(c)
        vim.schedule(function() observe(c) end)
    end })
    vim.api.nvim_create_autocmd('BufLeave', { group = c.group, buffer = buf, callback = function()
        dispatch(c, { kind = 'invalidate' })
    end })
    vim.api.nvim_create_autocmd('BufWipeout', { group = c.group, buffer = buf, callback = function() M.detach(buf) end })
    vim.api.nvim_create_autocmd('ModeChanged', { group = c.group, callback = function()
        if vim.api.nvim_get_current_buf() == buf then
            dispatch(c, { kind = 'invalidate' })
            vim.schedule(function() observe(c) end)
        end
    end })
    vim.api.nvim_create_autocmd('User', { group = c.group, pattern = { 'BlinkCmpShow', 'BlinkCmpHide' }, callback = function(event)
        local context = event.data and event.data.context
        if not context or context.bufnr ~= buf or not c.active then return end
        if event.match == 'BlinkCmpHide' then
            if c.context == context.id then c.context = nil; dispatch(c, { kind = 'hidden' }) end
            return
        end
        for _, item in ipairs(c.backend.cmp.get_items()) do
            local evidence = item.data and item.data.parley_spell
            if evidence and evidence.generation == c.state.generation and M.source_target(buf) then
                c.context = context.id
                dispatch(c, { kind = 'shown', generation = evidence.generation })
                return
            end
        end
        c.context = nil
        dispatch(c, { kind = 'hidden' })
    end })
    vim.schedule(function() observe(c) end)
    return activate(c)
end

return M
