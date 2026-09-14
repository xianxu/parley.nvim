-- Guest-only managed-proxy acceptance. Evidence contains no account IDs or text.
local M = {}
local function await(start, timeout)
    local done, value, failure = false, nil, nil
    start(function(result) value, done = result, true end,
        function() failure, done = true, true end)
    assert(vim.wait(timeout or 30000, function() return done end, 20), 'phase timeout')
    assert(not failure, 'managed operation failed')
    return value
end

function M.auth_is_private(auth, data)
    local stat = vim.uv.fs_lstat(auth)
    if not stat or stat.type ~= 'directory' or stat.uid ~= vim.uv.getuid() then return false end
    if stat.mode % 512 == 448 then return true end
    local parent = vim.uv.fs_lstat(data)
    local prefix = vim.fn.resolve(data) .. '/'
    return parent and parent.type == 'directory' and parent.uid == vim.uv.getuid()
        and parent.mode % 512 == 448 and vim.fn.resolve(auth):sub(1, #prefix) == prefix or false
end

local function ready(proxy)
    assert(proxy.is_managed(), 'installed starter must manage the proxy')
    await(function(ok, fail) proxy.ensure_running(ok, fail) end, 840000)
    assert(proxy.managed_binary(), 'managed first-use download missing')
    local path = proxy._config_path()
    local stat = assert(vim.uv.fs_stat(path), 'managed config missing')
    assert(stat.mode % 512 == 384, 'managed config is not private')
    local auth = require('parley').config.cliproxy.auth_dir
    assert(M.auth_is_private(auth, vim.fn.stdpath('data')), 'auth directory is not private')
end

local function ask(model, image)
    local p = require('parley')
    local buf = p.new_chat('Answer briefly. Do not use tools.',
        {model = model, provider = 'cliproxyapi'},
        image and 'Describe the attached image in one short sentence.' or 'Reply with the word ok.')
    assert(buf and vim.api.nvim_buf_is_valid(buf), 'chat creation failed')
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, {vim.api.nvim_buf_line_count(buf), 0})
    if image then
        local result = vim.system({'osascript', '-e', 'on run argv', '-e',
            'set the clipboard to (read (POSIX file (item 1 of argv)) as «class PNGf»)',
            '-e', 'end run', vim.env.HOME .. '/.parley-acceptance/one_pixel.png'},
            {text = true}):wait(10000)
        assert(result.code == 0, 'guest clipboard seed failed')
        p.paste_image(buf)
        assert(vim.wait(15000, function()
            return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
                :find('!%[') ~= nil
        end, 20), 'image paste failed')
    end
    local tasker = require('parley.tasker')
    local before = vim.tbl_extend('force', {}, tasker._queries)
    p.cmd.ChatRespond({args = '', range = 0})
    local query
    assert(vim.wait(120000, function()
        for id, candidate in pairs(tasker._queries) do
            if not before[id] and candidate.buf == buf and candidate.response
                and vim.trim(candidate.response) ~= '' then
                query = candidate
                return not tasker.is_busy(buf, true)
            end
        end
        return false
    end, 30), 'model response exceeded 120 seconds or was empty')
    assert(query.provider == 'cliproxyapi', 'request bypassed managed provider')
    if image then
        assert(require('parley.assets').has_image(query.payload), 'request omitted clipboard image')
    end
    return {response_nonempty = true, image_sent = image or false, managed_route = true}
end

function M.live_model(proxy)
    local selected, healthy_seen
    for _, login in ipairs(require('parley.cliproxy_config').providers()) do
        local health = await(function(done) proxy.credential_health_for_login(login, done) end)
        assert(health and health.state ~= 'unknown', 'credential health could not be verified')
        if health.state == 'healthy' then
            healthy_seen = true
            local models = await(function(done, fail) proxy.list_models(login, function(ids, err)
                if err then fail() else done(ids) end
            end) end)
            if models and #models > 0 then selected = models[1]; break end
        end
    end
    return selected, healthy_seen
end

function M.run(phase)
    local p, proxy = require('parley'), require('parley.cliproxy')
    if phase == 'fake' then
        p.config.llm_onboarding = false -- this phase proves transport; onboarding has dedicated UI tests
        -- Fixtures are part of the released tree; only the guest starts them.
        vim.cmd.cd(vim.env.PARLEY_RUNTIME)
        local releases = require('tests.helpers.fake_releases')
        local server = releases.start()
        local root = vim.fn.tempname()
        local ok, evidence = pcall(function()
            local port = require('tests.helpers.ready_port').free_port()
            proxy._set_releases_url(server.url)
            proxy._set_data_dir(root .. '/managed')
            p.config.cliproxy.auth_dir = root .. '/auth'
            require('parley.fs').ensure_dir(p.config.cliproxy.auth_dir, 448)
            p.config.cliproxy.download_version = '9.9.9'
            p.dispatcher.providers.cliproxyapi.endpoint = ('http://127.0.0.1:%d/v1/chat/completions'):format(port)
            releases.publish(server, '9.9.9')
            vim.env.PARLEY_FAKE_MODE = 'healthy'
            vim.env.PARLEY_FAKE_LOGIN_MODE = nil -- login flags select the fixture's success path
            vim.cmd('ParleyProxy connect')
            assert(vim.api.nvim_win_get_config(0).relative ~= '', 'Connect did not open a floating picker')
            local confirm = vim.fn.maparg('<CR>', 'i', false, true)
            assert(type(confirm.callback) == 'function', 'provider picker has no Enter action')
            confirm.callback() -- choose Claude through the existing provider picker
            assert(vim.wait(30000, function()
                return vim.fn.filereadable(root .. '/auth/claude-fake@example.com.json') == 1
            end, 20), 'guest fake managed login failed')
            ready(proxy)
            local result = ask('gpt-5-codex', false)
            result.fake = true
            result.status = 'fake_verified'
            result.first_use = #releases.requests(server) > 0
            assert(result.first_use, 'fake first use did not download')
            return result
        end)
        proxy.stop()
        releases.stop(server)
        vim.fn.delete(root, 'rf')
        assert(ok, 'guest fake provider failed: ' .. tostring(evidence))
        return evidence
    end
    ready(proxy)
    if phase == 'prepare-auth' then
        return {status = 'auth_pending', managed_download = true, private_config = true,
            private_auth = true, login_command = ':ParleyProxy connect'}
    end
    local selected, healthy_seen = M.live_model(proxy)
    if not selected then
        assert(not healthy_seen, 'authenticated account has no available live model')
        return {status = 'auth_pending', reason = 'no_authenticated_live_model'}
    end
    local evidence = ask(selected, true)
    evidence.status = 'live_verified'
    return evidence
end

return M
