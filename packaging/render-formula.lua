-- Headless integration entry: use this release tree's pure renderer and registry.
-- Contract: PARLEY_RELEASE_TAG, PARLEY_RELEASE_SHA256, PARLEY_RELEASE_OUTPUT.
local source = debug.getinfo(1, 'S').source:sub(2)
local directory = source:match('^(.*)/[^/]+$') or '.'
local ok, why = xpcall(function()
    local formula = dofile(directory .. '/formula.lua')
    local rendered = formula.render_formula({
        tag = vim.env.PARLEY_RELEASE_TAG,
        sha256 = vim.env.PARLEY_RELEASE_SHA256,
    })
    local output = assert(io.open(assert(vim.env.PARLEY_RELEASE_OUTPUT, 'Missing release output path'), 'wb'))
    local written, write_error = output:write(rendered)
    local closed, close_error = output:close()
    assert(written, write_error)
    assert(closed, close_error)
end, debug.traceback)
if not ok then
    io.stderr:write(tostring(why) .. '\n')
    vim.cmd('cquit 1')
end
