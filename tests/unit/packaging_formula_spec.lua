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
    it('projects registry defaults and fixes runtime paths in a valid Ruby formula', function()
        local output = formula().render_formula(release)
        local found = {}
        for dependency in output:gmatch('depends_on "([^"]+)"') do found[#found + 1] = dependency end
        local expected = { 'neovim' }
        vim.list_extend(expected, require('parley.deps').packages({ sysname = 'Darwin', manager = 'brew' }, 'default'))
        assert.are.same(expected, found)
        assert.is_truthy(output:find('/archive/refs/tags/v2.3.0.tar.gz', 1, true))
        assert.is_truthy(output:find('PARLEY_NVIM', 1, true))
        assert.is_truthy(output:find('PARLEY_STARTER', 1, true))
        assert.is_truthy(output:find('license "MIT"', 1, true))
        if vim.fn.executable('ruby') == 1 then
            local path = vim.fn.tempname() .. '.rb'
            vim.fn.writefile(vim.split(output, '\n', { plain = true }), path)
            local result = vim.fn.system({ 'ruby', '-c', path })
            vim.fn.delete(path)
            assert.are.equal(0, vim.v.shell_error, result)
        end
    end)
end)
