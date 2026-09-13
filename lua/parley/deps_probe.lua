-- Local observations only. Policy and installation advice live in deps.lua.
local deps = require('parley.deps')
local M = {}

function M.host()
    local uname = (vim.uv or vim.loop).os_uname()
    local host = { sysname = uname and uname.sysname or '' }
    if host.sysname == 'Darwin' and vim.fn.executable('brew') == 1 then
        host.manager = 'brew'
    elseif host.sysname == 'Linux' and vim.fn.executable('apt') == 1 then
        host.manager = 'apt'
    end
    return host
end

function M.observe(entry, host)
    local result = { applicable = deps.applicable(entry, host), present = false, source = 'none' }
    if not result.applicable then
        return result
    end
    if entry.tier == 'managed' then
        local cliproxy = require('parley.cliproxy')
        result.path, result.source = cliproxy.discover_binary()
        result.present = result.path ~= nil
        if result.source == 'managed' then
            result.version = cliproxy.installed_version()
        end
        return result
    end
    for _, executable in ipairs(entry.executables) do
        if vim.fn.executable(executable) == 1 then
            result.present = true
            result.path = vim.fn.exepath(executable)
            result.source = 'PATH'
            break
        end
    end
    return result
end

return M
