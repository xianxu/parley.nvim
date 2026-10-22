local uv = vim.uv or vim.loop
local arrival = require('tests.helpers.arrival')

describe('editor endpoint registry process boundary', function()
    local root, saved, client, identity
    local function request(operation, payload, options)
        assert.is_function(client.editor, 'typed editor endpoint request is missing')
        local result
        client.editor(operation, payload, { generation = 17 }, function(value) result = value end, options)
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end, 10))
        assert.equals(17, result.witness.generation)
        return result
    end
    local function intent(attach, incarnation)
        return { Version = 1, Namespace = root, DocumentID = identity.ID,
            EditorIncarnation = incarnation or string.rep('a', 32), AttachID = attach or '1',
            PID = uv.os_getpid(), Socket = root .. '/s1', Buffer = 7, Mode = 'desktop' }
    end
    local function unregister(binding)
        return { Version = 1, Namespace = binding.Namespace, PID = binding.PID,
            EditorIncarnation = binding.EditorIncarnation,
            Entries = { { DocumentID = binding.DocumentID, AttachID = binding.AttachID,
                BindingGeneration = binding.BindingGeneration } } }
    end

    before_each(function()
        root = vim.fn.tempname(); vim.fn.mkdir(root, 'p'); root = assert(uv.fs_realpath(root))
        require('tests.helpers.fake_couch').write(root, root .. '/sent', root .. '/argv')
        saved = { path = vim.env.PATH, registry = vim.env.FAKE_COUCH_REGISTRY,
            mode = vim.env.FAKE_COUCH_EDITOR_MODE, delay = vim.env.FAKE_COUCH_EDITOR_DELAY }
        vim.env.PATH = root .. '/bin:' .. vim.env.PATH
        vim.env.FAKE_COUCH_REGISTRY = root .. '/registry.json'
        vim.env.FAKE_COUCH_EDITOR_MODE, vim.env.FAKE_COUCH_EDITOR_DELAY = nil, nil
        local file = root .. '/session.md'; vim.fn.writefile({ 'session' }, file)
        identity = { ID = string.rep('1', 32), Namespace = root, File = file,
            Owner = 'ops:0', RegisteredOwner = 'ops:0', RegisteredAt = '2026-10-22T00:00:00Z' }
        vim.fn.writefile({ vim.json.encode({ paths = { [file] = identity }, moves = {} }) }, vim.env.FAKE_COUCH_REGISTRY)
        package.loaded['parley.document_registry'] = nil
        client = require('parley.document_registry')
    end)
    after_each(function()
        if client then client.shutdown() end
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = saved.path, saved.registry
        vim.env.FAKE_COUCH_EDITOR_MODE, vim.env.FAKE_COUCH_EDITOR_DELAY = saved.mode, saved.delay
        vim.fn.delete(root, 'rf')
    end)

    it('publishes, looks up and removes the exact editor binding through stdin JSON', function()
        local first = request('register', intent())
        assert.equals('confirmed', first.kind, vim.inspect(first))
        assert.equals(identity.File, first.binding.File)
        assert.equals('1', first.binding.AttachID)
        local found = request('lookup', { Namespace = root, DocumentID = identity.ID })
        assert.same(first.binding, found.binding)
        local removed = request('unregister', unregister(first.binding))
        assert.equals('confirmed', removed.kind)
        assert.equals('removed', removed.results[1].Status)
        assert.equals('absent', request('lookup', { Namespace = root, DocumentID = identity.ID }).kind)
    end)

    it('preserves generation on retry but never reclaims a superseded attachment', function()
        local old = request('register', intent())
        local same = request('register', intent())
        assert.equals(old.binding.BindingGeneration, same.binding.BindingGeneration)
        local newer = request('register', intent('2', string.rep('b', 32)))
        assert.is_not.equals(old.binding.BindingGeneration, newer.binding.BindingGeneration)
        local stale = request('register', intent())
        assert.equals('refused', stale.kind)
        assert.equals('superseded', stale.code)
        local cleanup = request('unregister', unregister(old.binding))
        assert.equals('stale', cleanup.results[1].Status)
        assert.same(newer.binding, request('lookup', { Namespace = root, DocumentID = identity.ID }).binding)
    end)

    it('preserves uncertain publication and confirms the identical retry', function()
        vim.env.FAKE_COUCH_EDITOR_MODE = 'uncertain'
        assert.equals('uncertain', request('register', intent()).kind)
        vim.env.FAKE_COUCH_EDITOR_MODE = nil
        assert.equals('confirmed', request('register', intent()).kind)
    end)

    it('keeps malformed, missing, unsupported and mismatched responses unknown', function()
        for _, mode in ipairs({ 'malformed', 'missing', 'unsupported', 'wrong-identity', 'oversized' }) do
            vim.env.FAKE_COUCH_EDITOR_MODE = mode
            assert.equals('unavailable', request('register', intent()).kind, mode)
        end
    end)

    it('validates input size and shape before spawning a child', function()
        local bad = intent(); bad.Socket = '../public'
        assert.equals('unavailable', request('register', bad).kind)
        bad = intent(); bad.Extra = string.rep('x', 9000)
        assert.equals('unavailable', request('register', bad).kind)
        assert.equals('unavailable', request('unregister', { Version = 1, Entries = {} }).kind)
        assert.equals('unavailable', request('lookup', { Namespace = root, DocumentID = 'wrong' }).kind)
        assert.equals(0, vim.fn.filereadable(root .. '/registry.json.editor-argv'))
    end)

    it('uses the fixed endpoint deadline and joins a timed-out child', function()
        vim.env.FAKE_COUCH_EDITOR_MODE, vim.env.FAKE_COUCH_EDITOR_DELAY = 'delay', '10'
        local started = uv.hrtime()
        local result = request('register', intent(), { timeout_ms = 1000 })
        assert.equals('unavailable', result.kind)
        assert.matches('deadline', result.error)
        assert.is_true((uv.hrtime() - started) / 1e6 >= 1000)
        assert.equals(3000, client.EDITOR_TIMEOUT_MS)
        local pid = tonumber(vim.fn.readfile(root .. '/registry.json.editor-pid')[1])
        local live, err = uv.kill(pid, 0)
        assert.is_nil(live)
        assert.matches('ESRCH', err)
    end)

    it('joins a canceled running request before delivering its result', function()
        assert.is_function(client.editor)
        vim.env.FAKE_COUCH_EDITOR_MODE, vim.env.FAKE_COUCH_EDITOR_DELAY = 'delay', '10'
        local result
        local operation = client.editor('register', intent(), {}, function(value) result = value end)
        assert.is_true(vim.wait(arrival.MS, function()
            return vim.fn.filereadable(root .. '/registry.json.editor-pid') == 1
        end, 10))
        local pid = tonumber(vim.fn.readfile(root .. '/registry.json.editor-pid')[1])
        operation.cancel()
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end, 10))
        assert.equals('unavailable', result.kind)
        assert.matches('canceled', result.error)
        local live, err = uv.kill(pid, 0)
        assert.is_nil(live)
        assert.matches('ESRCH', err)
    end)
end)
