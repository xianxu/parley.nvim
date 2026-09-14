-- Stop through the existing identity-checked owner, then verify its config has no process.
local proxy = require('parley.cliproxy')
local path = proxy._config_path()
proxy.stop()
local function stopped()
    local result = vim.system({'ps', 'ax', '-o', 'pid,lstart,command'}, {text = true}):wait(5000)
    assert(result.code == 0, 'process table unavailable')
    for _, row in ipairs(require('parley.cliproxy_auth').parse_ps(result.stdout)) do
        local _, last = row.command:find('-config ' .. path, 1, true)
        if last and (last == #row.command or row.command:sub(last + 1, last + 1) == ' ') then
            return false
        end
    end
    return true
end
assert(vim.wait(15000, stopped, 100), 'owned proxy remains after stop')
local roots = {}
for _, kind in ipairs({'config', 'data', 'state', 'cache'}) do roots[kind] = vim.fn.stdpath(kind) end
vim.fn.writefile({vim.json.encode({stopped = true, config_path = path, roots = roots})},
    vim.env.HOME .. '/.parley-acceptance/stop.json')
