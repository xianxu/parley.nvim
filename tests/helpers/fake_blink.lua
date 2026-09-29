-- Stateful Blink boundary: provider registration, visible context and deferred requests.
local M = {}
function M.new()
    local fake = { ready = true, providers = { 'buffer' }, pending = {}, contexts = 0, shows = 0 }
    fake.list = { items = {}, get_selection_mode = function() return { preselect = true, auto_insert = true } end }
    local cmp = {}
    fake.cmp = cmp
    function cmp.add_source_provider(id, opts) fake.provider = { id = id, opts = opts } end
    function cmp.add_filetype_source(_, id)
        if not vim.tbl_contains(fake.providers, id) then table.insert(fake.providers, id) end
    end
    function fake.enabled_providers() return vim.deepcopy(fake.providers) end
    function cmp.get_items() return fake.list.items end
    function cmp.is_menu_visible() return fake.visible == true end
    function cmp.get_context() return fake.context end
    function cmp.hide()
        local context = fake.context
        fake.visible, fake.context, fake.list.items = false, nil, {}
        if context then vim.api.nvim_exec_autocmds('User', { pattern = 'BlinkCmpHide', data = { context = context } }) end
        return true
    end
    function fake.deliver()
        local job = table.remove(fake.pending, 1)
        if not job then return end
        local source = require(fake.provider.opts.module).new()
        source:get_completions(job, function(response)
            fake.list.items, fake.context = response.items, job
            fake.visible = #response.items > 0
            for _, item in ipairs(response.items) do item.source_id = fake.provider.id end
            if fake.visible then
                vim.api.nvim_exec_autocmds('User', { pattern = 'BlinkCmpShow', data = { context = job } })
            end
        end)
    end
    function cmp.show(opts)
        fake.shows, fake.contexts = fake.shows + 1, fake.contexts + 1
        fake.requested_providers = opts.providers
        table.insert(fake.pending, { id = fake.contexts, bufnr = vim.api.nvim_get_current_buf() })
        if not fake.defer then fake.deliver() end
        return true
    end
    function cmp.select_next(opts) fake.selection = { direction = 1, opts = opts } end
    function cmp.select_prev(opts) fake.selection = { direction = -1, opts = opts } end
    function cmp.select_and_accept() fake.accepted = true end
    return fake
end
return M
