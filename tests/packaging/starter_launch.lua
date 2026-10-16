if vim.env.STARTER_CROSS_FILESYSTEM then
    local uv = vim.uv or vim.loop
    local link = uv.fs_link
    uv.fs_link = function(source, destination)
        local dir = vim.fs.dirname(destination)
        if source:sub(1, #dir + 1) ~= dir .. '/' then
            return nil, 'EXDEV: cross-device link', 'EXDEV'
        end
        assert(uv.fs_stat(vim.fs.dirname(source)).mode % 512 == 448,
            'tutorial staging directory must be private')
        if vim.env.STARTER_LINK_FAILURE then return nil, 'injected publication failure' end
        return link(source, destination)
    end
end
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
-- #348: pause the welcome lock between its two halves, so a second starter can
-- arrive in the gap. A gate is `<base>.ready` (written here), then wait for
-- `<base>.release`.
local function gate(base)
    vim.fn.writefile({ 'ready' }, base .. '.ready')
    assert(vim.wait(10000, function() return vim.fn.filereadable(base .. '.release') == 1 end, 10))
end
if vim.env.STARTER_OWNER_GATE then
    -- Pause before the owner record is written.
    local writefile = vim.fn.writefile
    vim.fn.writefile = function(lines, path, ...)
        if type(path) == 'string' and path:find('welcome-initializer', 1, true) and path:match('/owner$') then
            vim.fn.writefile = writefile
            gate(vim.env.STARTER_OWNER_GATE)
        end
        return writefile(lines, path, ...)
    end
end
if vim.env.STARTER_RETIRE_GATE then
    -- Pause a recursive delete of the lock after its owner record is gone.
    local delete = vim.fn.delete
    vim.fn.delete = function(path, flags, ...)
        if type(path) == 'string' and path:find('welcome-initializer', 1, true) and flags == 'rf' then
            vim.fn.delete = delete
            delete(path .. '/owner')
            gate(vim.env.STARTER_RETIRE_GATE)
        end
        return delete(path, flags, ...)
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
