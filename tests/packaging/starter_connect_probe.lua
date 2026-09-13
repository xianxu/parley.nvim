-- Exercise Connect through real release download, managed process and login.
vim.cmd.cd(vim.env.STARTER_REPO)
local p = require('parley')
local proxy = require('parley.cliproxy')
local releases = require('tests.helpers.fake_releases')
local port = require('tests.helpers.ready_port').free_port()
local server = releases.start()
proxy._set_releases_url(server.url)
proxy._set_data_dir(vim.fn.stdpath('data') .. '/connect-fixture')
local failure = vim.env.STARTER_CONNECT_MODE == 'failure'
releases.publish(server, '9.9.9', failure and { sha = ('0'):rep(64) } or nil)
p.config.cliproxy.download_version = '9.9.9'
p.dispatcher.providers.cliproxyapi.endpoint = ('http://127.0.0.1:%d/v1/chat/completions'):format(port)
vim.env.PATH = '/usr/bin:/bin:/usr/sbin:/sbin'
vim.env.PARLEY_FAKE_MODE = 'healthy'
vim.env.PARLEY_FAKE_LOGIN_MODE = 'success'
assert(proxy.discover_binary() == nil, 'fixture must begin without a proxy binary')
local notices = {}
vim.notify = function(message) notices[#notices + 1] = tostring(message) end
vim.ui.select = function(_, _, callback) callback('Claude', 1) end
local ok, why = pcall(function()
    vim.cmd('ParleyConnect')
    local credential = p.config.cliproxy.auth_dir .. '/claude-fake@example.com.json'
    assert(vim.wait(8000, function()
        if failure then return table.concat(notices, '\n'):find('auto_download failed', 1, true) ~= nil end
        return vim.fn.filereadable(credential) == 1
    end, 20), table.concat(notices, '\n'))
    assert(#releases.requests(server) > 0, 'Connect did not fetch a release')
    if failure then
        assert(vim.fn.filereadable(credential) == 0, 'failed download entered login')
        assert(not table.concat(notices, '\n'):find('Visit the following URL', 1, true))
        assert(proxy.managed_binary() == nil)
    else
        assert(proxy.managed_binary())
        assert(proxy.installed_version() == '9.9.9')
        assert(#proxy.spawned_pids() > 0, 'downloaded proxy was never started')
    end
end)
for _, pid in ipairs(proxy.spawned_pids()) do pcall(vim.uv.kill, pid, 'sigkill') end
proxy._reset_spawned()
releases.stop(server)
assert(ok, why)
