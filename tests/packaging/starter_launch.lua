if vim.env.STARTER_HOLD then
    local parley = require('parley')
    local open_buf = parley.open_buf
    parley.open_buf = function(...)
        local result = open_buf(...)
        vim.fn.writefile({ 'ready' }, vim.env.STARTER_HOLD .. '.ready')
        assert(vim.wait(10000, function()
            return vim.fn.filereadable(vim.env.STARTER_HOLD .. '.release') == 1
        end, 10))
        return result
    end
end
local ok, why = pcall(function() require('parley.starter').start() end)
if vim.env.STARTER_EXPECT_ERROR then
    if ok or not tostring(why):find(vim.env.STARTER_EXPECT_ERROR, 1, true) then
        io.stderr:write('Expected starter error: ' .. tostring(why) .. '\n')
        vim.cmd('cquit 1')
    end
    vim.cmd('qa!')
elseif not ok then
    io.stderr:write(tostring(why) .. '\n')
    vim.cmd('cquit 1')
end
