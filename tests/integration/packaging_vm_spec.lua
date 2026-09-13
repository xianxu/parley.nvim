local repository = vim.fn.getcwd()
describe('disposable packaging VM ownership', function()
    local root
    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root .. '/home', 'p')
    end)
    after_each(function() vim.fn.delete(root, 'rf') end)
    local function run(phase, extra, flags)
        local env = {
            HOME = root .. '/home', PATH = vim.env.PATH,
            TART = repository .. '/tests/fixtures/fake_tart', FAKE_TART_STATE = root .. '/fake',
        }
        for key, value in pairs(extra or {}) do env[key] = value end
        local argv = {'python3', repository .. '/tests/fixtures/run_packaging_vm.py', phase, root .. '/run'}
        vim.list_extend(argv, flags or {})
        return vim.system(argv,
            {text = true, clear_env = true, env = env}):wait(10000)
    end
    local function state()
        return vim.json.decode(table.concat(vim.fn.readfile(root .. '/fake/vms.json'), '\n'))
    end
    it('rejects insufficient simulated disk before cloning and releases its reservation', function()
        local result = run('prepare', {FAKE_DISK_FREE_BYTES = tostring(59 * 1024 ^ 3)})
        assert.equals(1, result.code)
        local manifest = vim.json.decode(table.concat(vim.fn.readfile(root .. '/run/manifest.json'), '\n'))
        assert.equals('failed', manifest.outcome)
        assert.equals(0, vim.fn.filereadable(root .. '/fake/calls.jsonl'))
        assert.equals(0, vim.fn.filereadable(root .. '/home/.cache/parley-vm-acceptance.owner'))
    end)
    it('matches Tart exit 2 for stop and delete of an unknown VM', function()
        for _, verb in ipairs({'stop', 'delete'}) do
            local result = vim.system({repository .. '/tests/fixtures/fake_tart', verb, 'absent'},
                {text = true, env = {FAKE_TART_STATE = root .. '/fake'}}):wait()
            assert.equals(2, result.code)
        end
    end)
    it('preserves clone failure and releases the reservation when absence is confirmed', function()
        local result = run('prepare', {FAKE_TART_FAIL = 'clone'})
        assert.equals(1, result.code)
        local manifest = vim.json.decode(table.concat(vim.fn.readfile(root .. '/run/manifest.json'), '\n'))
        assert.equals('clone', manifest.failure.command)
        assert.matches('clone', manifest.failure.reason)
        assert.equals('cleaned', manifest.status)
        assert.equals(0, vim.fn.filereadable(root .. '/home/.cache/parley-vm-acceptance.owner'))
    end)
    it('retains the owned VM and safe phase diagnostic when explicitly requested', function()
        local result = run('prepare', {FAKE_TART_FAIL = 'brew install'}, {'--keep-on-failure'})
        assert.equals(1, result.code)
        local manifest = vim.json.decode(table.concat(vim.fn.readfile(root .. '/run/manifest.json'), '\n'))
        assert.equals('failed_retained', manifest.status)
        assert.equals('install', manifest.failure.phase)
        assert.equals('exec', manifest.failure.command)
        assert.is_not_nil(state()[manifest.vm])
        assert.equals(1, vim.fn.filereadable(root .. '/home/.cache/parley-vm-acceptance.owner'))
        assert.matches('install', result.stderr)
        assert.equals(0, run('cleanup').code)
    end)
    it('retains ownership and the original failure if cleanup cannot delete an existing VM', function()
        local result = run('prepare', {FAKE_TART_FAIL = 'brew install', FAKE_TART_DELETE_FAIL = '1'})
        assert.equals(1, result.code)
        local manifest = vim.json.decode(table.concat(vim.fn.readfile(root .. '/run/manifest.json'), '\n'))
        assert.equals('cleanup_failed', manifest.status)
        assert.equals('install', manifest.failure.phase)
        assert.equals('exec', manifest.failure.command)
        assert.equals('delete', manifest.cleanup_failure.command)
        assert.is_not_nil(state()[manifest.vm])
        assert.equals(1, vim.fn.filereadable(root .. '/home/.cache/parley-vm-acceptance.owner'))
        assert.equals(0, run('cleanup').code)
    end)
    it('retains only its unique VM while authentication is pending and cleans it explicitly', function()
        local result = run('prepare')
        assert.equals(75, result.code, result.stderr)
        local manifest = vim.json.decode(table.concat(vim.fn.readfile(root .. '/run/manifest.json'), '\n'))
        assert.equals('auth_pending', manifest.status)
        assert.equals(120 * 1024 ^ 3, manifest.free_before_bytes)
        assert.equals(0, manifest.observed_clone_allocation_bytes)
        assert.equals('running', state()['tools-test'])
        assert.is_not_nil(state()[manifest.vm])
        local calls = {}
        for _, line in ipairs(vim.fn.readfile(root .. '/fake/calls.jsonl')) do
            local call = vim.json.decode(line)
            assert.equals('1', call.no_prune)
            calls[call.args[1]] = call.args
        end
        assert.same({'run', '--no-graphics', '--no-audio', '--no-clipboard', manifest.vm}, calls.run)
        assert.matches('@sha256:1b093499716409d29e8b5336844528e1cae375db97d2ad8e5aeff78cf0da201e$', calls.clone[2])
        assert.equals(75, run('verify').code)
        result = run('cleanup')
        assert.equals(0, result.code, result.stderr)
        assert.same({['tools-test'] = 'running'}, state())
    end)
    it('cleans its clone after package failure without deleting pre-existing VMs', function()
        local result = run('prepare', {FAKE_TART_FAIL = 'brew install'})
        assert.equals(1, result.code, result.stderr)
        assert.same({['tools-test'] = 'running'}, state())
    end)
    it('refuses another preparation while an owned run is pending', function()
        assert.equals(75, run('prepare').code)
        assert.equals(1, run('prepare').code)
        assert.equals(0, run('cleanup').code)
    end)
    it('boots before publication then resumes public installation in the same clone', function()
        assert.equals(0, run('boot').code)
        local initial = state()
        local calls = table.concat(vim.fn.readfile(root .. '/fake/calls.jsonl'), '\n')
        assert.is_nil(calls:find('brew install', 1, true))
        assert.equals(75, run('install').code)
        assert.same(initial, state())
        assert.equals(0, run('cleanup').code)
    end)
    it('resumes authenticated live evidence without treating pending auth as success', function()
        assert.equals(75, run('prepare').code)
        assert.equals(0, run('fake', {FAKE_TART_PROBE_STATUS = 'fake_verified'}).code)
        assert.equals(75, run('check-live').code)
        assert.equals(0, run('check-live', {FAKE_TART_PROBE_STATUS = 'live_verified'}).code)
        local manifest = vim.json.decode(table.concat(vim.fn.readfile(root .. '/run/manifest.json'), '\n'))
        assert.equals('live_verified', manifest.live.status)
        assert.equals(75, run('verify').code) -- upgrade/uninstall evidence still absent
        assert.equals(0, run('cleanup').code)
    end)
    it('exercises guest fake first use, login prompt and real chat dispatch in an isolated profile', function()
        local script = root .. '/fake-chat.lua'
        vim.fn.writefile({
            'vim.opt.runtimepath:prepend(' .. string.format('%q', repository) .. ')',
            'require("parley.starter").start()',
            'local ok, result = pcall(function() return dofile(' .. string.format('%q', repository .. '/tests/packaging/vm_chat.lua') .. ').run("fake") end)',
            'if not ok then io.stderr:write(tostring(result)); vim.cmd("cquit 1") end',
            'assert(result.first_use and result.managed_route and result.response_nonempty)',
            'vim.cmd("qa!")',
        }, script)
        local result = vim.system({vim.v.progpath, '--headless', '-n', '-i', 'NONE', '-u', 'NONE', '-l', script},
            {text = true, clear_env = true, env = {
                HOME = root .. '/home', PATH = vim.env.PATH, NVIM_APPNAME = 'parley',
                XDG_CONFIG_HOME = root .. '/config', XDG_DATA_HOME = root .. '/data',
                XDG_STATE_HOME = root .. '/state', XDG_CACHE_HOME = root .. '/cache',
                TMPDIR = root, PARLEY_RUNTIME = repository,
            }}):wait(45000)
        assert.equals(0, result.code, result.stderr)
    end)
    local function full_evidence()
        assert.equals(75, run('prepare').code)
        assert.equals(0, run('fake', {FAKE_TART_PROBE_STATUS = 'fake_verified'}).code)
        assert.equals(0, run('upgrade').code)
        assert.equals(0, run('check-live', {FAKE_TART_PROBE_STATUS = 'live_verified'}).code)
        assert.equals(75, run('verify').code)
        assert.equals(0, run('uninstall').code)
    end
    it('requires every acceptance phase then records completion only after owned VM deletion', function()
        full_evidence()
        local result = run('verify')
        assert.equals(0, result.code, result.stderr)
        assert.same({['tools-test'] = 'running'}, state())
        local manifest = vim.json.decode(table.concat(vim.fn.readfile(root .. '/run/manifest.json'), '\n'))
        assert.equals('complete', manifest.outcome)
        assert.equals('cleaned', manifest.status)
    end)
    it('never records completion when owned VM cleanup fails', function()
        full_evidence()
        assert.equals(1, run('verify', {FAKE_TART_FAIL = 'delete'}).code)
        local manifest = vim.json.decode(table.concat(vim.fn.readfile(root .. '/run/manifest.json'), '\n'))
        assert.is_not_equal('complete', manifest.outcome)
        assert.equals(0, run('cleanup').code)
    end)
    it('removes exactly four guest profile roots after stop and brew uninstall', function()
        local home = vim.fn.resolve(root .. '/home')
        local work = home .. '/.parley-acceptance'
        local bin = root .. '/bin'
        vim.fn.mkdir(work, 'p')
        vim.fn.mkdir(bin, 'p')
        vim.fn.mkdir(home .. '/.config/nvim', 'p')
        vim.fn.writefile({'decoy'}, home .. '/.config/nvim/init.lua')
        local digest = vim.fn.sha256('decoy\n')
        vim.fn.writefile({digest .. '  ' .. home .. '/.config/nvim/init.lua'}, work .. '/decoy.sha')
        local roots = {config = home .. '/.config/parley', data = home .. '/.local/share/parley',
            state = home .. '/.local/state/parley', cache = home .. '/.cache/parley'}
        for _, path in pairs(roots) do vim.fn.mkdir(path, 'p'); vim.fn.writefile({'owned'}, path .. '/file') end
        vim.fn.writefile({vim.json.encode({stopped = true, roots = roots,
            config_path = roots.data .. '/parley/cliproxy/config.yaml'})}, work .. '/stop.json')
        vim.fn.writefile({'#!/bin/sh', 'if [ "$1" = uninstall ]; then exit 0; fi', 'exit 1'}, bin .. '/brew')
        vim.fn.writefile({'#!/bin/sh', 'exit 0'}, bin .. '/ps')
        vim.uv.fs_chmod(bin .. '/brew', 493)
        vim.uv.fs_chmod(bin .. '/ps', 493)
        local result = vim.system({'python3', repository .. '/tests/packaging/vm_uninstall.py'},
            {text = true, clear_env = true, env = {HOME = home, PATH = bin .. ':' .. vim.env.PATH}}):wait(10000)
        assert.equals(0, result.code, result.stderr)
        for _, path in pairs(roots) do assert.equals(0, vim.fn.isdirectory(path)) end
        assert.same({'decoy'}, vim.fn.readfile(home .. '/.config/nvim/init.lua'))
        assert.equals('passed', vim.json.decode(table.concat(vim.fn.readfile(work .. '/uninstall.json'), '\n')).status)
    end)
    it('does not accept a forged ownership manifest', function()
        vim.fn.mkdir(root .. '/run', 'p')
        vim.fn.writefile({vim.json.encode({vm = 'tools-test', status = 'auth_pending'})}, root .. '/run/manifest.json')
        assert.equals(1, run('cleanup').code)
        assert.equals(0, vim.fn.filereadable(root .. '/fake/calls.jsonl'))
    end)
end)
