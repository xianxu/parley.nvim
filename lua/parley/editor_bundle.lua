-- Installed payloads are verified at package construction; writable local
-- bundles are verified by the lease-owning launcher before editor startup.
local M = {}

function M.platform()
    local host = (vim.uv or vim.loop).os_uname()
    if host.sysname == 'Darwin' then return host.machine == 'arm64' and 'macos-arm64' or 'macos' end
    assert(host.sysname == 'Linux' and (host.machine == 'x86_64' or host.machine == 'i686'),
        'No bundled Markdown Preview binary for ' .. host.sysname .. '/' .. host.machine)
    return 'linux'
end

function M.select()
    local root = vim.env.PARLEY_EDITOR_BUNDLE
    if not root or root == '' then return nil end
    local function check(value, reason)
        assert(value, 'Parley editor bundle: ' .. reason .. '; repair/reinstall the bundle: ' .. root)
    end
    local expected = require('parley.editor_dependencies').export(vim.env.PARLEY_EDITOR_PROFILE or 'app', M.platform())
    local receipt_path = root .. '/receipt.json'
    check(vim.fn.filereadable(receipt_path) == 1, 'missing receipt')
    local ok, receipt = pcall(vim.json.decode, table.concat(vim.fn.readfile(receipt_path), '\n'))
    check(ok and type(receipt) == 'table' and receipt.schema_version == 1
        and vim.deep_equal(receipt.manifest, expected), 'manifest mismatch')
    local by_repo = {}
    for _, plugin in ipairs(expected.plugins) do
        local path = root .. '/plugins/' .. plugin.name
        check(vim.fn.isdirectory(path) == 1, 'missing plugin ' .. plugin.name)
        by_repo[plugin.repo] = { path = path, name = plugin.name }
    end
    check(vim.fn.executable(root .. '/' .. expected.artifact.output) == 1, 'missing Preview executable')
    local bundle = { lazy = root .. '/plugins/lazy.nvim' }
    function bundle.specs(_, specs)
        local result = vim.deepcopy(specs)
        for _, spec in ipairs(result) do
            local plugin = by_repo[spec[1]]
            if plugin then
                spec.dir, spec.name, spec.pin, spec.build = plugin.path, plugin.name, true, false
            end
        end
        return result
    end
    return bundle
end

return M
