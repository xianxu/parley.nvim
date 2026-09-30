local root, previous, manifest
describe('installed editor bundle selection', function()
    before_each(function()
        root = vim.fn.tempname()
        previous = { bundle = vim.env.PARLEY_EDITOR_BUNDLE, profile = vim.env.PARLEY_EDITOR_PROFILE,
            deps = package.loaded['parley.editor_dependencies'] }
        manifest = { schema_version = 1, plugins = {
            { name = 'lazy.nvim', repo = 'folke/lazy.nvim', commit = string.rep('a', 40) },
            { name = 'blink.cmp', repo = 'saghen/blink.cmp', commit = string.rep('b', 40) },
        }, artifact = { output = 'plugins/markdown-preview.nvim/app/bin/server' } }
        package.loaded['parley.editor_dependencies'] = { export = function() return vim.deepcopy(manifest) end }
        package.loaded['parley.editor_bundle'] = nil
        for _, item in ipairs(manifest.plugins) do vim.fn.mkdir(root .. '/plugins/' .. item.name, 'p') end
        local binary = root .. '/' .. manifest.artifact.output
        vim.fn.mkdir(vim.fn.fnamemodify(binary, ':h'), 'p')
        vim.fn.writefile({ '#!/bin/sh', 'exit 0' }, binary)
        vim.fn.setfperm(binary, 'rwxr-xr-x')
        vim.fn.writefile({ vim.json.encode({ schema_version = 1, manifest = manifest, files = {} }) }, root .. '/receipt.json')
        vim.env.PARLEY_EDITOR_BUNDLE, vim.env.PARLEY_EDITOR_PROFILE = root, 'app'
    end)
    after_each(function()
        vim.env.PARLEY_EDITOR_BUNDLE, vim.env.PARLEY_EDITOR_PROFILE = previous.bundle, previous.profile
        package.loaded['parley.editor_dependencies'] = previous.deps
        package.loaded['parley.editor_bundle'] = nil
        vim.fn.delete(root, 'rf')
    end)
    it('projects shipped specs onto local immutable dirs without changing caller configuration', function()
        local bundle = require('parley.editor_bundle').select()
        local input = { { 'saghen/blink.cmp', opts = { value = true }, build = function() end },
            { dir = '/custom/parley', name = 'parley.nvim' } }
        local result = bundle:specs(input)
        assert.equals(root .. '/plugins/blink.cmp', result[1].dir)
        assert.is_false(result[1].build)
        assert.is_true(result[1].pin)
        assert.is_true(result[1].opts.value)
        assert.is_nil(input[1].dir)
        assert.equals('/custom/parley', result[2].dir)
        assert.equals(root .. '/plugins/lazy.nvim', bundle.lazy)
    end)
    it('fails closed on incomplete and wrong-version bundles', function()
        local module = require('parley.editor_bundle')
        vim.fn.delete(root .. '/plugins/blink.cmp', 'rf')
        assert.has_error(function() module.select() end)
        vim.fn.mkdir(root .. '/plugins/blink.cmp', 'p')
        manifest.plugins[2].commit = string.rep('c', 40)
        assert.has_error(function() module.select() end)
    end)
    it('keeps standalone source startup distinct from explicit broken bundle selection', function()
        local module = require('parley.editor_bundle')
        vim.env.PARLEY_EDITOR_BUNDLE = nil
        assert.is_nil(module.select())
        vim.env.PARLEY_EDITOR_BUNDLE = root .. '/missing'
        assert.has_error(function() module.select() end)
    end)
end)
