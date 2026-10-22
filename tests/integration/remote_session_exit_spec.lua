local uv = vim.uv or vim.loop
local arrival = require('tests.helpers.arrival')

describe('bounded private editor endpoint exit', function()
    local root, saved, frontend, registry, buffers, gates, blockers, other_servers, requests, completions, options, exited, outstanding, register_cancels
    local function require_exit()
        assert.is_function(frontend.exit, 'synchronous endpoint exit is missing')
        assert.equals(500, frontend.EXIT_BUDGET_MS)
    end
    local function identity(name, namespace)
        local file = root .. '/' .. name .. '.md'
        vim.fn.writefile({ name }, file)
        local buf = vim.fn.bufadd(file); vim.fn.bufload(buf); buffers[#buffers + 1] = buf
        local registration = { ID = vim.fn.sha256(name):sub(1, 32), Namespace = namespace or root, File = file,
            Owner = 'ops:0', RegisteredOwner = 'ops:0', RegisteredAt = '2026-10-22T00:00:00Z' }
        local path = root .. '/registry.json'
        local state = vim.fn.filereadable(path) == 1 and vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
            or { paths = vim.empty_dict(), moves = vim.empty_dict() }
        state.paths[file] = registration
        vim.fn.writefile({ vim.json.encode(state) }, path)
        return buf, registration
    end
    local function attach(buf, registration, client)
        local result
        local selected = { runtime = options.runtime, client = client }
        frontend.attach(buf, registration, function(value) result = value end, selected)
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end, 10))
        assert.equals('confirmed', result.kind, vim.inspect(result))
        return frontend.snapshot(buf)
    end
    local function group(count, prefix, namespace, client)
        local prepared, states = {}, {}
        for index = 1, count do
            local buf, registration = identity(prefix .. index, namespace)
            prepared[#prepared + 1] = { buf, registration }
        end
        for _, item in ipairs(prepared) do states[#states + 1] = attach(item[1], item[2], client) end
        return states
    end
    local function query(context)
        return { Namespace = context.Namespace, DocumentID = context.DocumentID,
            EditorIncarnation = context.EditorIncarnation, AttachID = context.AttachID, Buffer = context.Buffer }
    end
    local function launch_count(operation)
        local path = root .. '/registry.json.editor-launches'
        if vim.fn.filereadable(path) == 0 then return 0 end
        local count = 0
        for _, value in ipairs(vim.fn.readfile(path)) do if value == operation then count = count + 1 end end
        return count
    end
    local function current_binding(context)
        local state = vim.json.decode(table.concat(vim.fn.readfile(root .. '/registry.json'), '\n'))
        return state.editor_endpoints and state.editor_endpoints.current[context.Namespace .. '\n' .. context.DocumentID]
    end
    before_each(function()
        local base = uv.fs_stat('/Volumes/TestScratch') and '/Volumes/TestScratch' or (vim.env.TMPDIR or uv.os_tmpdir())
        root = assert(uv.fs_mkdtemp(base .. '/rx-XXXXXX'))
        buffers, gates, blockers, other_servers, requests, completions = {}, {}, {}, {}, {}, {}
        exited, outstanding, register_cancels = false, 0, 0
        saved = { path = vim.env.PATH, registry = vim.env.FAKE_COUCH_REGISTRY,
            mode = vim.env.FAKE_COUCH_EDITOR_MODE, delay = vim.env.FAKE_COUCH_EDITOR_DELAY, notify = vim.notify }
        require('tests.helpers.fake_couch').write(root, root .. '/sent', root .. '/argv')
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = root .. '/bin:' .. vim.env.PATH, root .. '/registry.json'
        vim.env.FAKE_COUCH_EDITOR_MODE, vim.env.FAKE_COUCH_EDITOR_DELAY = nil, nil
        vim.notify = function() end
        registry = require('parley.document_registry')
        saved.editor = registry.editor
        registry.editor = function(operation, payload, witness, callback, client)
            outstanding = outstanding + 1
            if operation == 'unregister' then
                requests[#requests + 1] = { payload = vim.deepcopy(payload), options = vim.deepcopy(client or {}) }
            end
            local handle = saved.editor(operation, payload, witness, function(result)
                outstanding = outstanding - 1
                if operation == 'unregister' then completions[#completions + 1] = result end
                callback(result)
            end, client)
            if operation == 'register' then
                local cancel = handle.cancel
                handle.cancel = function(...)
                    register_cancels = register_cancels + 1
                    return cancel(...)
                end
            end
            return handle
        end
        package.loaded['parley.remote_session'] = nil
        frontend = require('parley.remote_session')
        if frontend.exit then
            local exit = frontend.exit
            frontend.exit = function() exited = true; return exit() end
        end
        options = { runtime = { parent = root .. '/runtime', source = require('tests.helpers.fake_process_source').new({
            [uv.os_getpid()] = { started = 'Thu Oct 22 05:00:00 2026' },
        }) } }
    end)
    after_each(function()
        for _, gate in ipairs(gates) do vim.fn.writefile({}, gate) end
        for _, handle in ipairs(blockers) do handle.cancel() end
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = root .. '/bin:' .. saved.path, root .. '/registry.json'
        vim.env.FAKE_COUCH_EDITOR_MODE, vim.env.FAKE_COUCH_EDITOR_DELAY = nil, nil
        if not exited then
            local done
            frontend.close(function() done = true end)
            assert.is_true(vim.wait(arrival.MS, function() return done end, 10))
        end
        registry.shutdown()
        assert.is_true(vim.wait(arrival.MS, function() return outstanding == 0 end, 10))
        registry.editor = saved.editor
        vim.notify = saved.notify
        for _, path in ipairs(other_servers) do pcall(vim.fn.serverstop, path) end
        for _, buf in ipairs(buffers) do pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
        vim.fn.delete(root, 'rf')
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = saved.path, saved.registry
        vim.env.FAKE_COUCH_EDITOR_MODE, vim.env.FAKE_COUCH_EDITOR_DELAY = saved.mode, saved.delay
    end)

    for _, count in ipairs({ 8, 16 }) do
        it('freezes ' .. count .. ' exact same-namespace bindings into one idempotent exit batch', function()
            require_exit()
            local states = group(count, 'same-namespace-', root)
            local result = frontend.exit()
            assert.equals('closed', result.kind)
            assert.equals(1, #requests)
            assert.equals(count, #requests[1].payload.Entries)
            assert.equals(root, requests[1].payload.Namespace)
            local wanted = {}
            for _, state in ipairs(states) do wanted[state.binding.DocumentID] = state.binding end
            for _, entry in ipairs(requests[1].payload.Entries) do
                local binding = assert(wanted[entry.DocumentID])
                assert.equals(binding.AttachID, entry.AttachID)
                assert.equals(binding.BindingGeneration, entry.BindingGeneration)
                wanted[entry.DocumentID] = nil
            end
            assert.same({}, wanted)
            assert.equals(1, launch_count('unregister'))
            for _, state in ipairs(states) do
                assert.is_nil(current_binding(state.context))
                assert.is_nil(frontend.endpoint(query(state.context)))
                assert.is_nil(uv.fs_lstat(state.context.Socket))
                assert.equals(1, vim.fn.filereadable(vim.fn.fnamemodify(state.context.Socket, ':h') .. '/owner.json'))
            end
            assert.same(result, frontend.exit())
            assert.equals(1, #requests)
            assert.equals(1, launch_count('unregister'))
        end)
    end

    local function switch_private_producer(client)
        local other = root .. '/other-producer'
        vim.fn.mkdir(other, 'p')
        require('tests.helpers.fake_couch').write(other, other .. '/sent', other .. '/argv')
        local other_store = other .. '/registry.json'
        vim.fn.writefile({ vim.json.encode({ paths = vim.empty_dict(), moves = vim.empty_dict(), Untouched = true }) }, other_store)
        local before = table.concat(vim.fn.readfile(other_store), '\n')
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = other .. '/bin:' .. saved.path, other_store
        client.binary, client.env.FAKE_COUCH_REGISTRY = other .. '/bin/couch', other_store
        return other_store, before
    end

    it('retains the original private producer and environment for detach after ambient selection changes', function()
        local buf, registration = identity('frozen-detach')
        local client = { binary = root .. '/bin/couch', env = { FAKE_COUCH_REGISTRY = root .. '/registry.json' } }
        local state = attach(buf, registration, client)
        local other_store, before = switch_private_producer(client)
        frontend.detach(buf)
        assert.is_true(vim.wait(arrival.MS, function() return current_binding(state.context) == nil end, 10))
        assert.equals(before, table.concat(vim.fn.readfile(other_store), '\n'))
        assert.equals(0, vim.fn.filereadable(other_store .. '.editor-argv'))
    end)

    it('freezes absolute binary, explicit options and complete environment for exit cleanup', function()
        require_exit()
        local buf, registration = identity('frozen-exit')
        local client = { binary = root .. '/bin/couch', env = { FAKE_COUCH_REGISTRY = root .. '/registry.json' } }
        local state = attach(buf, registration, client)
        local original_path = vim.env.PATH
        local other_store, before = switch_private_producer(client)
        assert.equals('closed', frontend.exit().kind)
        assert.is_nil(current_binding(state.context))
        assert.equals(1, #requests)
        assert.equals(root .. '/bin/couch', requests[1].options.binary)
        assert.equals(root .. '/registry.json', requests[1].options.env.FAKE_COUCH_REGISTRY)
        assert.equals(original_path, requests[1].options.env.PATH)
        assert.is_true(requests[1].options.clear_env)
        assert.equals(before, table.concat(vim.fn.readfile(other_store), '\n'))
        assert.equals(0, vim.fn.filereadable(other_store .. '.editor-argv'))
    end)


    local function occupy_slots(count, context)
        local joined = 0
        for _ = 1, count do
            blockers[#blockers + 1] = registry.editor('lookup', { Namespace = context.Namespace,
                DocumentID = context.DocumentID }, {}, function() joined = joined + 1 end,
                { env = { FAKE_COUCH_EDITOR_MODE = 'delay', FAKE_COUCH_EDITOR_DELAY = '10' } })
        end
        assert.is_true(vim.wait(arrival.MS, function() return launch_count('lookup') == count end, 10))
        return function()
            for _, blocker in ipairs(blockers) do blocker.cancel() end
            assert.is_true(vim.wait(arrival.MS, function() return joined == count end, 10))
        end
    end

    it('gives namespace batches one original absolute deadline including queued time', function()
        require_exit()
        local first_ns, second_ns = root .. '/a', root .. '/b'
        vim.fn.mkdir(first_ns, 'p'); vim.fn.mkdir(second_ns, 'p')
        local first_buf, first_identity = identity('first-namespace', first_ns)
        local second_buf, second_identity = identity('second-namespace', second_ns)
        local first = attach(first_buf, first_identity, { env = {
            FAKE_COUCH_EDITOR_MODE = 'delay', FAKE_COUCH_EDITOR_DELAY = '0.3' } })
        local second = attach(second_buf, second_identity, { env = {
            FAKE_COUCH_EDITOR_MODE = 'delay', FAKE_COUCH_EDITOR_DELAY = '0.4' } })
        local release = occupy_slots(3, first.context)
        local started = uv.hrtime() / 1e6
        local result = frontend.exit()
        assert.equals('uncertain', result.kind)
        assert.equals(2, #requests)
        local deadline = requests[1].options.absolute_deadline_ms
        assert.is_number(deadline)
        assert.equals(deadline, requests[2].options.absolute_deadline_ms)
        assert.is_true(deadline >= started and deadline <= started + frontend.EXIT_BUDGET_MS + 5)
        -- Cancellation may join after exit returns; this fixture drain does
        -- not extend the synchronous exit budget.
        assert.is_true(vim.wait(arrival.MS, function() return #completions == 2 end, 10))
        -- The second command's 0.4s cannot fit after the first command's 0.3s
        -- in the sole free child slot. Its authority must remain, never appear
        -- removed through a fresh per-namespace timeout.
        assert.is_table(current_binding(second.context))
        assert.is_not.equals('confirmed', completions[2].kind)
        release()
        assert.same(result, frontend.exit())
        assert.equals(2, #requests)
    end)

    it('expires an exit batch queued behind all four children and never spawns it later', function()
        require_exit()
        local buf, registration = identity('queued-exit')
        local state = attach(buf, registration)
        local release = occupy_slots(4, state.context)
        local result = frontend.exit()
        assert.equals('uncertain', result.kind)
        assert.equals(1, #requests)
        assert.equals(0, launch_count('unregister'))
        assert.is_table(current_binding(state.context))
        assert.is_nil(frontend.endpoint(query(state.context)))
        assert.is_nil(uv.fs_lstat(state.context.Socket))
        release()
        assert.equals(0, launch_count('unregister'))
        assert.equals(1, #completions)
        assert.is_not.equals('confirmed', completions[1].kind)
        assert.same(result, frontend.exit())
        assert.equals(1, #requests)
    end)

    for _, mode in ipairs({ 'held', 'malformed' }) do
        it('keeps ' .. mode .. ' publication uncertain and never fabricates an exit generation', function()
            require_exit()
            local buf, registration = identity('unknown-' .. mode)
            local client = { env = {} }
            if mode == 'held' then
                local gate = root .. '/held-register'
                gates[#gates + 1] = gate
                client.env.FAKE_COUCH_EDITOR_REPLY_GATE = gate
            else client.env.FAKE_COUCH_EDITOR_MODE = 'malformed' end
            local calls = 0
            frontend.attach(buf, registration, function() calls = calls + 1 end,
                { runtime = options.runtime, client = client })
            local state
            assert.is_true(vim.wait(arrival.MS, function()
                state = frontend.snapshot(buf)
                return state and current_binding(state.context) ~= nil
                    and (mode == 'held' or calls == 1)
            end, 10))
            local result = frontend.exit()
            assert.equals('uncertain', result.kind)
            assert.equals(0, #requests)
            assert.equals(0, launch_count('unregister'))
            assert.is_nil(frontend.endpoint(query(state.context)))
            assert.is_nil(uv.fs_lstat(state.context.Socket))
            if mode == 'held' then
                -- The gate stays closed: the observer must be explicitly
                -- canceled at exit, then join independently of its old 3s
                -- Lua deadline or the editor's disappearing event loop.
                assert.equals(1, register_cancels)
                assert.is_true(vim.wait(arrival.MS, function() return outstanding == 0 end, 10))
                assert.equals(1, calls)
            end
            assert.same(result, frontend.exit())
            assert.equals(0, #requests)
        end)
    end

    it('does not call unobserved startup clean at exit or wait for filesystem cleanup', function()
        require_exit()
        local buf, registration = identity('startup-exit')
        options.runtime.source.hold = true
        local calls = 0
        frontend.attach(buf, registration, function() calls = calls + 1 end, options)
        assert.is_true(vim.wait(arrival.MS, function() return #options.runtime.source.pending == 1 end, 10))
        local result = frontend.exit()
        assert.equals('uncertain', result.kind)
        assert.equals(0, #requests)
        assert.equals(0, launch_count('register'))
        -- Drain the held fixture after the exit result; this is not part of
        -- the VimLeave deadline or a promise of callbacks after editor exit.
        options.runtime.source.release(1)
        assert.is_true(vim.wait(arrival.MS, function() return calls == 1 end, 10))
        assert.same(result, frontend.exit())
    end)

    it('unregisters only its frozen generation and leaves a successor and another native server alone', function()
        require_exit()
        local buf, registration = identity('stale-generation-exit')
        local old = attach(buf, registration)
        local other_socket = root .. '/other-native.sock'
        assert.equals(other_socket, vim.fn.serverstart(other_socket))
        other_servers[#other_servers + 1] = other_socket
        local payload = vim.deepcopy(old.context)
        payload.Version, payload.File = 1, nil
        payload.EditorIncarnation, payload.AttachID, payload.Socket = string.rep('f', 32), '1', other_socket
        local successor
        registry.editor('register', payload, {}, function(result) successor = result end)
        assert.is_true(vim.wait(arrival.MS, function() return successor ~= nil end, 10))
        assert.equals('confirmed', successor.kind)
        assert.equals('closed', frontend.exit().kind)
        assert.equals(old.binding.BindingGeneration, requests[1].payload.Entries[1].BindingGeneration)
        assert.equals('stale', completions[1].results[1].Status)
        assert.equals(successor.binding.BindingGeneration, current_binding(old.context).BindingGeneration)
        assert.is_nil(uv.fs_lstat(old.context.Socket))
        assert.equals('socket', uv.fs_lstat(other_socket).type)
        local channel = vim.fn.sockconnect('pipe', other_socket, { rpc = true })
        assert.is_true(channel > 0); vim.fn.chanclose(channel)
    end)

end)
