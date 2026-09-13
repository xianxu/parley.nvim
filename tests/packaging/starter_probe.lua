local ok, why = pcall(function()
    local p = require('parley')
    if vim.env.STARTER_PICK_MODEL then
        p.register_live_agent({ id = vim.env.STARTER_PICK_MODEL, owner = 'anthropic' })
    end
    if vim.env.STARTER_EXPECT_MODEL then
        assert(p._state.agent == vim.env.STARTER_EXPECT_MODEL, 'saved model was replaced: ' .. tostring(p._state.agent))
    end
    assert(p.config.default_keymaps == false)
    assert(p.config.web_search == false)
    assert(vim.tbl_count(p.dispatcher.providers) == 1)
    assert(p.dispatcher.providers.cliproxyapi)
    assert(p.agents['ToolOpus*'] == nil)
    for _, a in pairs(p.agents) do assert(#a.tools == 0) end
    local data, state = vim.fn.resolve(vim.fn.stdpath('data')), vim.fn.resolve(vim.fn.stdpath('state'))
    for _, name in ipairs({ 'chat_dir', 'notes_dir', 'export_html_dir', 'export_markdown_dir' }) do
        assert(vim.fn.resolve(p.config[name]):sub(1, #data + 1) == data .. '/', name .. ' escaped profile')
    end
    assert(vim.fn.resolve(p.config.state_dir):sub(1, #state + 1) == state .. '/')
    assert(vim.fn.resolve(p.config.cliproxy.auth_dir) == data .. '/auth')
    assert(not vim.uv.fs_stat(vim.env.HOME .. '/Library/Mobile Documents'))
    assert(not vim.uv.fs_stat(vim.env.HOME .. '/blogs'))
    local key = table.concat(vim.fn.readfile(data .. '/client-key'), '')
    local log = table.concat(vim.fn.readfile(p.config.log_file), '\n')
    assert(not log:find(key, 1, true), 'client key leaked into profile log')
    assert(vim.fn.exists(':ParleyConnect') == 2)
    if vim.fn.argc() > 0 then
        assert(vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0)) == vim.uv.fs_realpath(vim.fn.argv(0)), vim.inspect({actual=vim.api.nvim_buf_get_name(0),expected=vim.fn.argv(0)}))
    else
        assert(vim.api.nvim_buf_get_name(0):find('/chats/welcome/', 1, true))
        assert(vim.wo.conceallevel == 0)
        local map = vim.fn.maparg('<M-CR>', 'n', false, true)
        assert(next(map) ~= nil)
    end
    if vim.env.STARTER_CONNECT_MODE then
        dofile(vim.env.STARTER_REPO .. '/tests/packaging/starter_connect_probe.lua')
    end
end)
if not ok then
    io.stderr:write(tostring(why) .. '\n')
    vim.cmd('cquit 1')
else
    vim.cmd('qa!')
end
