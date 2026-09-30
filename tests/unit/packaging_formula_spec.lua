local function formula()
    return dofile('packaging/formula.lua')
end
local release = { tag = 'v2.3.0', sha256 = string.rep('a', 64) }
describe('Homebrew formula projection', function()
    it('rejects unsafe or mutable release metadata', function()
        for _, tag in ipairs({ 'main', 'v1', 'v1.2.3\n', 'v1.2.3"', '../v1.2.3' }) do
            assert.has_error(function() formula().validate_release({ tag = tag, sha256 = release.sha256 }) end)
        end
        for _, digest in ipairs({ '', string.rep('a', 63), string.rep('g', 64) }) do
            assert.has_error(function() formula().validate_release({ tag = release.tag, sha256 = digest }) end)
        end
        assert.is_true(formula().validate_release(release))
    end)
    it('projects registry defaults and fixes runtime paths in the rendered formula', function()
        local output = formula().render_formula(release)
        local found = {}
        for dependency in output:gmatch('depends_on "([^"]+)"') do found[#found + 1] = dependency end
        local expected = { 'neovim' }
        vim.list_extend(expected, require('parley.deps').packages({ sysname = 'Darwin', manager = 'brew' }, 'default'))
        expected[#expected + 1] = 'python@3.13'
        assert.are.same(expected, found)
        assert.is_truthy(output:find('depends_on "python@3.13" => :build', 1, true))
        assert.is_truthy(output:find('/archive/refs/tags/v2.3.0.tar.gz', 1, true))
        assert.is_truthy(output:find('PARLEY_NVIM', 1, true))
        assert.is_truthy(output:find('PARLEY_STARTER', 1, true))
        assert.is_truthy(output:find('license "MIT"', 1, true))

    end)
    it('stages the complete checksummed editor manifest and seals the installed bundle', function()
        local output = formula().render_formula(release)
        assert.is_truthy(output:find('resource "editor-', 1, true))
        local editor = dofile('lua/parley/editor_dependencies.lua')
        local names = {}
        for name in output:gmatch('resource "editor%-([^"]+)" do') do
            if name ~= 'markdown-preview-binary' then names[#names + 1] = name end
        end
        local expected = {}
        for _, plugin in ipairs(editor.plugins('app')) do
            expected[#expected + 1] = plugin.name
            assert.is_truthy(output:find('url "' .. plugin.url .. '"', 1, true))
            assert.is_truthy(output:find('sha256 "' .. plugin.sha256 .. '"', 1, true))
            assert.is_truthy(output:find('plugins/' .. plugin.name, 1, true))
        end
        table.sort(names)
        table.sort(expected)
        assert.same(expected, names)
        for _, platform in ipairs({ 'macos-arm64', 'macos', 'linux' }) do
            local artifact = editor.artifact(platform)
            assert.is_truthy(output:find('url "' .. artifact.url .. '"', 1, true))
            assert.is_truthy(output:find('sha256 "' .. artifact.sha256 .. '"', 1, true))
            assert.is_truthy(output:find(artifact.output, 1, true))
        end
        assert.is_truthy(output:find('PARLEY_EDITOR_BUNDLE: libexec/"editor-bundle"', 1, true))
        assert.is_truthy(output:find('PARLEY_EDITOR_BUNDLE_INSTALLED: "1"', 1, true))
        assert.is_truthy(output:find('"seal", "--bundle"', 1, true))
        assert.is_truthy(output:find('Dir["*", ".*"]', 1, true))
        assert.is_falsy(output:find('mkdp#util#install', 1, true))
    end)

end)
