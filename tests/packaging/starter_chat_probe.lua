local ok, why = pcall(function()
    local parley = require('parley')
    local source = vim.fn.resolve(vim.env.STARTER_CHAT_OVERRIDE)
    assert(vim.fn.resolve(parley.config.chat_dir) == source, 'chat override ignored')
    assert(not parley.config.repo_root, 'demo inherited repository mode')
    assert(vim.fn.resolve(vim.api.nvim_buf_get_name(0)) == source .. '/welcome.md', 'opened a tutorial copy')
    assert(vim.fn.resolve(parley.config.state_dir):find(vim.fn.resolve(vim.fn.stdpath('state')), 1, true) == 1,
        'state escaped isolated profile')
    vim.api.nvim_buf_set_lines(0, 6, 7, false, { 'Edited tutorial source' })
    vim.cmd.write()
    assert(vim.fn.readfile(source .. '/welcome.md')[7] == 'Edited tutorial source', 'edit missed source')
end)
if not ok then io.stderr:write(tostring(why) .. '\n'); vim.cmd('cquit 1') end
vim.cmd('qa!')
