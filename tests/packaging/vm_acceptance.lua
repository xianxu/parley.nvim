-- Runs through the installed launcher in the disposable guest, never via -u NONE.
assert(vim.env.NVIM_APPNAME == 'parley', 'launcher did not isolate app name')
local home = assert(vim.env.HOME)
local expected = {
    config = home .. '/.config/parley',
    data = home .. '/.local/share/parley',
    state = home .. '/.local/state/parley',
    cache = home .. '/.cache/parley',
}
for kind, path in pairs(expected) do
    assert(vim.fn.resolve(vim.fn.stdpath(kind)) == vim.fn.resolve(path), kind .. ' escaped the owned profile')
end
assert(vim.fn.filereadable(expected.config .. '/init.lua') == 1, 'starter missing')
assert(vim.env.PARLEY_RUNTIME and vim.env.PARLEY_RUNTIME ~= '', 'installed runtime missing')
assert(vim.fn.exists(':ParleyProxy') == 2, 'installed app failed to boot')
local check = vim.system({'shasum', '-a', '256', '-c', home .. '/.parley-acceptance/decoy.sha'},
    {text = true}):wait()
assert(check.code == 0, 'decoy profile changed')
vim.fn.writefile({vim.json.encode({boot = true, containment = true, decoy_unchanged = true,
    live = 'pending', upgrade = 'pending'})}, home .. '/.parley-acceptance/boot.json')
