local arrival = require('tests.helpers.arrival')
local Embedded = require('tests.helpers.embedded_nvim')

describe('default discovery registry fixture', function()
    local root, saved, child
    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, 'p')
        saved = { path = vim.env.PATH, log = vim.env.PARLEY_TEST_SENTINEL_LOG,
            registry = vim.env.FAKE_COUCH_REGISTRY }
        vim.env.PARLEY_TEST_SENTINEL_LOG = root .. '/sentinel.log'
    end)
    after_each(function()
        if child then assert(child:stop()); child = nil end
        require('parley.document_registry').shutdown()
        vim.env.PATH, vim.env.PARLEY_TEST_SENTINEL_LOG = saved.path, saved.log
        vim.env.FAKE_COUCH_REGISTRY = saved.registry
        vim.fn.delete(root, 'rf')
    end)

    local function lookup(file)
        local result
        require('parley.document_registry').request('lookup', { file }, {}, function(value) result = value end)
        assert(vim.wait(arrival.MS, function() return result ~= nil end, 10))
        return result
    end

    it('ordinary Markdown discovery gets positive absence without reaching the sentinel', function()
        local file = root .. '/ordinary.md'
        vim.fn.writefile({ '# Original' }, file)
        local buf = vim.fn.bufadd(file)
        vim.fn.bufload(buf)
        vim.bo[buf].filetype = 'markdown'
        local registry = require('parley.document_registry')
        local request, result = registry.request
        registry.request = function(op, args, witness, callback, options)
            return request(op, args, witness, function(value) result = value; callback(value) end, options)
        end
        local ok, err = pcall(function()
            require('parley.remote_session').observe(buf)
            assert(vim.wait(arrival.MS, function() return result ~= nil end, 10))
            assert.equals('absent', result.kind)
            assert.is_nil(require('parley.remote_session').snapshot(buf))
            assert.same({ '# Original' }, vim.fn.readfile(file))
            assert.equals(0, vim.fn.filereadable(root .. '/sentinel.log'))
        end)
        registry.request = request
        vim.api.nvim_buf_delete(buf, { force = true })
        assert(ok, err)
    end)

    it('keeps direct calls and unmocked mutations behind the strict sentinel', function()
        local direct = vim.system({ 'couch', '--session-sync', 'lookup', '/x.md', '--json' }, { text = true }):wait(5000)
        assert.equals(97, direct.code)
        local mutation
        require('parley.couch').run({ 'couch', '--session-sync', 'forget', '/x.md', '--json' },
            function(value) mutation = value end)
        assert(vim.wait(arrival.MS, function() return mutation ~= nil end, 10))
        assert.equals(97, mutation.code)
        assert.equals(2, #vim.fn.readfile(root .. '/sentinel.log'))
    end)

    it('lets an explicit stateful fake win over the empty discovery fixture', function()
        local file = root .. '/tracked.md'
        vim.fn.writefile({ '# Tracked' }, file)
        require('tests.helpers.fake_couch').write(root, root .. '/sent', root .. '/argv')
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = root .. '/bin:' .. saved.path, root .. '/registry.json'
        vim.fn.writefile({ vim.json.encode({ paths = { [file] = { ID = 'explicit', File = file,
            Owner = 'ops:0', RegisteredOwner = 'ops:0', RegisteredAt = '2026-10-22T00:00:00Z' } }, moves = {} }) },
            vim.env.FAKE_COUCH_REGISTRY)
        assert.equals('explicit', lookup(file).registration.ID)
        assert.equals(0, vim.fn.filereadable(root .. '/sentinel.log'))
    end)

    it('installs the same empty registry boundary in clean embedded editors', function()
        child = Embedded.start()
        local result = child:exec([[
            local result
            local arrival = require('tests.helpers.arrival')
            require('parley.document_registry').request('lookup', { ... }, {}, function(value) result = value end)
            assert(vim.wait(arrival.MS, function() return result ~= nil end, 10))
            return result
        ]], root .. '/embedded.md')
        assert.equals('absent', result.kind)
        assert.equals(0, vim.fn.filereadable(root .. '/sentinel.log'))
    end)

    it('installs once without replacing the first fixture or wrapping it twice', function()
        local fixture = require('tests.helpers.discovery_registry_fixture')
        local run = require('parley.couch').run
        assert.equals(run, fixture.install(root .. '/unused'))
        assert.equals(run, require('parley.couch').run)
        assert.equals('absent', lookup(root .. '/unregistered.md').kind)
        assert.equals(0, vim.fn.isdirectory(root .. '/unused'))
    end)
end)
