local manifest = require('parley.editor_dependencies')

describe('editor dependency manifest', function()
    it('exports the closed app inventory and adds only Screenkey for recording', function()
        local app = manifest.plugins()
        assert.same({ 'blink.cmp', 'catppuccin', 'lazy.nvim', 'lualine.nvim',
            'markdown-preview.nvim', 'nightfox', 'onedark', 'plenary.nvim',
            'solarized', 'telescope.nvim', 'tokyonight' },
            vim.tbl_map(function(plugin) return plugin.name end, app))
        local recording = manifest.plugins('recording')
        assert.equals(12, #recording)
        local found = false
        for _, plugin in ipairs(recording) do
            if plugin.name == 'screenkey.nvim' then
                found = true
                assert.equals('recording', plugin.scope)
            else
                assert.equals('app', plugin.scope)
            end
        end
        assert.is_true(found)
    end)

    it('projects Lazy specs without exposing builder metadata or mutable registry tables', function()
        local plugin = manifest.plugin('blink.cmp')
        assert.same({ 'saghen/blink.cmp', name = 'blink.cmp',
            commit = '78336bc89ee5365633bcf754d93df01678b5c08f' }, plugin)
        plugin.commit = 'changed'
        local records = manifest.plugins()
        records[1].sha256 = 'changed'
        assert.equals('78336bc89ee5365633bcf754d93df01678b5c08f', manifest.plugin('blink.cmp').commit)
        assert.equals('74a12c86fd74ea28b37cccad0cf41ec2afff6a0ee07747ad38cc6eee869cce38',
            manifest.plugins()[1].sha256)
    end)

    it('exports every preview architecture with its verified binary and required app layout', function()
        local expected = {
            ['macos-arm64'] = '850e3973513f3e187b87612a15c5fdacc6e82b58b130f36f8e7d9ff93cbd9f4c',
            macos = 'fa2825f30b4da22b6754cf09090ca17ed20debdc55072d9214f1e40b2b9aa474',
            linux = 'cc0373706714b8002a65dfb61d1b71ceffcd77d51fc17472acc0aa14d9bf1416',
        }
        for platform, hash in pairs(expected) do
            local exported = manifest.export('app', platform)
            assert.equals(1, exported.schema_version)
            assert.equals(11, #exported.plugins)
            assert.equals('0.0.10', exported.artifact.version)
            assert.equals(hash, exported.artifact.binary_sha256)
            assert.equals('markdown-preview-' .. platform, exported.artifact.member)
            assert.equals('plugins/markdown-preview.nvim/app/bin/' .. exported.artifact.member,
                exported.artifact.output)
            assert.is_true(manifest.validate_manifest(exported))
            exported.artifact.sha256 = 'changed'
            assert.is_true(manifest.validate_manifest(manifest.export('app', platform)))
        end
    end)

    it('rejects unknown selectors instead of silently choosing a profile or architecture', function()
        assert.has_error(function() manifest.plugins('typo') end)
        assert.has_error(function() manifest.plugin('unknown') end)
        assert.has_error(function() manifest.artifact('linux-arm64') end)
        assert.has_error(function() manifest.artifact() end)
    end)

    it('rejects unsafe and incomplete inventories before any IO boundary can consume them', function()
        local mutations = {
            function(m) m.schema_version = 2 end,
            function(m) m.plugins[2] = vim.deepcopy(m.plugins[1]) end,
            function(m) m.plugins[1].name = '../outside' end,
            function(m) m.plugins[1].repo = 'owner/../../outside' end,
            function(m) m.plugins[1].commit = 'main' end,
            function(m) m.plugins[1].sha256 = string.rep('z', 64) end,
            function(m) m.plugins[1].source_sha256 = nil end,
            function(m) m.plugins[1].source_sha256 = 'invalid' end,
            function(m) m.plugins[1].scope = 'unknown' end,
            function(m) m.plugins[1].url = 'http://untrusted.invalid/archive' end,
            function(m) m.plugins = {} end,
            function(m) m.plugins[3] = nil end,
            function(m) m.artifact.member = '../outside' end,
            function(m) m.artifact.output = 'plugins/other/server' end,
            function(m) m.artifact.binary_sha256 = 'missing' end,
            function(m) m.artifact.platform = 'unknown' end,
            function(m) m.artifact.version = 'latest' end,
        }
        for _, mutate in ipairs(mutations) do
            local exported = manifest.export('app', 'macos-arm64')
            mutate(exported)
            assert.has_error(function() manifest.validate_manifest(exported) end)
        end
    end)

    it('loads and projects without any Neovim dependency', function()
        local chunk = assert(loadfile('lua/parley/editor_dependencies.lua'))
        setfenv(chunk, setmetatable({ vim = false }, { __index = _G }))
        local pure = chunk()
        assert.equals(12, #pure.export('recording', 'linux').plugins)
    end)
end)
