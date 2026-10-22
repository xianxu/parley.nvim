-- Outside-pane discovery is an ordinary Markdown-open effect. Give that one
-- read-only boundary an empty persisted registry unless a spec supplies its
-- own executable. Bare system calls and every other verb retain the sentinel.
local M = {}
local installed = setmetatable({}, { __mode = 'k' })

function M.install(root)
    local couch = require('parley.couch')
    if installed[couch] then return installed[couch] end
    local repo = vim.fn.getcwd()
    local sentinel = repo .. '/tests/fixtures/sentinel-bin/couch'
    local fixture = repo .. '/tests/fixtures/fake_couch_registry.py'
    local run = couch.run
    local wrapper = function(argv, callback, options)
        if #argv == 5 and argv[1] == 'couch' and argv[2] == '--session-sync' and argv[3] == 'lookup'
            and type(argv[4]) == 'string' and argv[4]:sub(1, 1) == '/' and argv[5] == '--json'
            and vim.fn.exepath('couch') == sentinel then
            vim.fn.mkdir(root, 'p')
            local opts = vim.tbl_extend('force', {}, options or {})
            opts.env = vim.tbl_extend('force', {}, opts.env or {}, { FAKE_COUCH_REGISTRY = root .. '/registry.json' })
            return run({ 'python3', fixture, argv[2], argv[3], argv[4], argv[5] }, callback, opts)
        end
        return run(argv, callback, options)
    end
    couch.run = wrapper
    installed[couch] = wrapper
    return wrapper
end

return M
