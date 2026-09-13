-- Installation advice has one owner; recipe additions must declare their tool.
describe('dependency registry ownership', function()
    it('keeps package installation commands in the registry', function()
        local violations = {}
        for _, path in ipairs(vim.fn.glob('lua/parley/**/*.lua', false, true)) do
            if path ~= 'lua/parley/deps.lua' then
                local lines = vim.fn.readfile(path)
                for index, line in ipairs(lines) do
                    if line:match('brew%s+install%f[%W]') or line:match('apt[%w%-]*%s+install%f[%W]')
                        or line:match('dnf%s+install%f[%W]') or line:match('pacman%s+%-S') then
                        violations[#violations+1] = path .. ':' .. index
                    end
                end
            end
        end
        assert.same({}, violations)
    end)
    it('requires a registry entry for every builtin recipe', function()
        local deps = require('parley.deps')
        for _, module in ipairs({'clipboard_image', 'image_shrink'}) do
            for _, recipe in pairs(require('parley.' .. module).RECIPES) do
                assert.is_truthy(deps.get(recipe.dependency), module .. ': ' .. recipe.tool)
                assert.is_nil(recipe.install, 'advice must be derived at selection')
            end
        end
    end)
end)
