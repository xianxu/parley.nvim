local uv = vim.uv or vim.loop
local arrival = require('tests.helpers.arrival')

describe('editor endpoint registry process boundary', function()
    local root, saved, client, identity, operations, gates, timers, pending
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

    local function async_editor(operation,payload,callback,options)
        pending=pending+1
        local handle=client.editor(operation,payload,{},function(result) pending=pending-1;callback(result) end,options)
        operations[#operations+1]=handle
        return handle
    end
    local function release_gate(path) vim.fn.writefile({},path) end
    local function launches()
        local path=root..'/registry.json.editor-launches'
        return vim.fn.filereadable(path)==1 and #vim.fn.readfile(path) or 0
    end
    local function occupy_slots()
        local gate=root..'/release';gates[#gates+1]=gate
        for index=1,4 do
            async_editor('register',intent(tostring(index),string.rep(tostring(index),32)),function() end,
                {env={FAKE_COUCH_EDITOR_REPLY_GATE=gate},timeout_ms=arrival.MS})
        end
        assert(vim.wait(arrival.MS,function() return launches()==4 end,10))
        return gate
    end
    before_each(function()
        operations,gates,timers,pending={},{},{},0
        root = vim.fn.tempname(); vim.fn.mkdir(root, 'p'); root = assert(uv.fs_realpath(root))
        require('tests.helpers.fake_couch').write(root, root .. '/sent', root .. '/argv')
        saved = { path = vim.env.PATH, registry = vim.env.FAKE_COUCH_REGISTRY,
            mode = vim.env.FAKE_COUCH_EDITOR_MODE, delay = vim.env.FAKE_COUCH_EDITOR_DELAY,
            run=require('parley.couch').run,deadline=require('parley.helper').start_deadline }
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
        require('parley.couch').run=saved.run
        require('parley.helper').start_deadline=saved.deadline
        for _,timer in ipairs(timers) do if not timer:is_closing() then timer:stop();timer:close() end end
        for _,gate in ipairs(gates) do release_gate(gate) end
        for _,operation in ipairs(operations) do operation.cancel() end
        if client then client.shutdown() end
        assert(vim.wait(arrival.MS,function() return pending==0 end,10))
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

    it('expires an absolute queued deadline before occupied transport slots open',function()
        local gate=occupy_slots()
        local released=false
        timers[#timers+1]=vim.defer_fn(function() released=true;release_gate(gate) end,250)
        local result
        async_editor('lookup',{Namespace=root,DocumentID=identity.ID},function(value) result=value end,
            {absolute_deadline_ms=uv.hrtime()/1e6+100})
        assert(vim.wait(arrival.MS,function() return result~=nil end,10))
        assert.equals('unavailable',result.kind,vim.inspect(result))
        assert.matches('deadline',result.error)
        assert.is_false(released,'queued expiry waited for a child slot')
        assert.equals(4,launches())
    end)
    it('refuses an expired queued request before spawn even when its timer is held',function()
        local gate=occupy_slots()
        require('parley.helper').start_deadline=function(timer,ms,callback)
            if ms<=100 then return end
            return saved.deadline(timer,ms,callback)
        end
        local deadline=uv.hrtime()/1e6+30
        local result
        async_editor('lookup',{Namespace=root,DocumentID=identity.ID},function(value) result=value end,
            {absolute_deadline_ms=deadline})
        assert(vim.wait(arrival.MS,function() return uv.hrtime()/1e6>=deadline end,10))
        release_gate(gate)
        assert(vim.wait(arrival.MS,function() return result~=nil end,10))
        require('parley.helper').start_deadline=saved.deadline
        assert.equals('unavailable',result.kind,vim.inspect(result))
        assert.matches('deadline',result.error)
        assert.equals(4,launches(),'expired request spawned when a slot opened')
    end)
    it('joins an admitted absolute deadline while retaining a possibly published binding',function()
        local gate=root..'/release';gates[#gates+1]=gate
        timers[#timers+1]=vim.defer_fn(function() release_gate(gate) end,600)
        local result
        async_editor('register',intent(),function(value) result=value end,
            {absolute_deadline_ms=uv.hrtime()/1e6+200,env={FAKE_COUCH_EDITOR_REPLY_GATE=gate}})
        assert(vim.wait(arrival.MS,function() return result~=nil end,10))
        assert.equals('unavailable',result.kind,vim.inspect(result))
        assert.matches('deadline',result.error)
        local pid=tonumber(vim.fn.readfile(root..'/registry.json.editor-pid')[1])
        local live,err=uv.kill(pid,0);assert.is_nil(live);assert.matches('ESRCH',err)
        -- Publication precedes the held acknowledgment. Expiry is not absence.
        assert.equals('confirmed',request('lookup',{Namespace=root,DocumentID=identity.ID}).kind)
    end)
    it('keeps the absolute-deadline observer until its native exit delivery joins',function()
        local release,delivery
        require('parley.couch').run=function(argv,callback,options)
            return saved.run(argv,function(value) delivery=value;release=function() callback(value) end end,options)
        end
        local gate=root..'/release';gates[#gates+1]=gate
        local result,calls=nil,0
        async_editor('register',intent(),function(value) result=value;calls=calls+1 end,
            {absolute_deadline_ms=uv.hrtime()/1e6+200,timeout_ms=1000,env={FAKE_COUCH_EDITOR_REPLY_GATE=gate}})
        assert(vim.wait(arrival.MS,function() return release~=nil end,10))
        assert.is_nil(result,'expiry reported before the owned native completion joined')
        local pid=tonumber(vim.fn.readfile(root..'/registry.json.editor-pid')[1])
        local live,err=uv.kill(pid,0);assert.is_nil(live);assert.matches('ESRCH',err)
        assert.is_table(delivery)
        release()
        assert(vim.wait(arrival.MS,function() return result~=nil end,10))
        assert.equals('unavailable',result.kind);assert.matches('deadline',result.error)
        assert.equals(1,calls)
    end)
    it('rejects a late admitted reply when the absolute timer callback is delayed',function()
        require('parley.helper').start_deadline=function(timer,ms,callback)
            if ms<=300 then return end
            return saved.deadline(timer,ms,callback)
        end
        local gate=root..'/release';gates[#gates+1]=gate
        timers[#timers+1]=vim.defer_fn(function() release_gate(gate) end,300)
        local result
        async_editor('register',intent(),function(value) result=value end,
            {absolute_deadline_ms=uv.hrtime()/1e6+100,env={FAKE_COUCH_EDITOR_REPLY_GATE=gate}})
        assert(vim.wait(arrival.MS,function() return result~=nil end,10))
        assert.equals('unavailable',result.kind,vim.inspect(result))
        assert.matches('deadline',result.error)
    end)
end)
