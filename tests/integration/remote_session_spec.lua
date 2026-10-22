local uv = vim.uv or vim.loop
local arrival = require('tests.helpers.arrival')

describe('private editor attachment dispatcher', function()
    local root, saved, frontend, buffers, notices, options, gates, releases
    local function identity(name)
        local file = root .. '/' .. name .. '.md'
        vim.fn.writefile({ name }, file)
        local buf = vim.fn.bufadd(file); vim.fn.bufload(buf); buffers[#buffers + 1] = buf
        local registration = { ID = vim.fn.sha256(name):sub(1, 32), Namespace = root, File = file,
            Owner = 'ops:0', RegisteredOwner = 'ops:0', RegisteredAt = '2026-10-22T00:00:00Z' }
        local path = root .. '/registry.json'
        local state = vim.fn.filereadable(path) == 1 and vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
            or { paths = {}, moves = {} }
        state.paths[file] = registration
        vim.fn.writefile({ vim.json.encode(state) }, path)
        return buf, registration
    end
    local function attach(buf, registration)
        assert.is_function(frontend.attach, 'remote session dispatcher is missing')
        local done, result
        frontend.attach(buf, registration, function(value) result = value; done = true end, options)
        assert.is_true(vim.wait(arrival.MS, function() return done end, 10))
        return result
    end
    local function query(context)
        return { Namespace = context.Namespace, DocumentID = context.DocumentID,
            EditorIncarnation = context.EditorIncarnation, AttachID = context.AttachID, Buffer = context.Buffer }
    end
    local function notice(binding)
        return { Namespace = binding.Namespace, DocumentID = binding.DocumentID,
            EditorIncarnation = binding.EditorIncarnation, AttachID = binding.AttachID,
            BindingGeneration = binding.BindingGeneration }
    end
    before_each(function()
        local base = uv.fs_stat('/Volumes/TestScratch') and '/Volumes/TestScratch' or (vim.env.TMPDIR or uv.os_tmpdir())
        root = assert(uv.fs_mkdtemp(base .. '/rs-XXXXXX')); buffers, notices, gates, releases = {}, {}, {}, {}
        saved = { fs_fsync = uv.fs_fsync, fs_write = uv.fs_write,
            acquire = require('parley.remote_runtime').acquire, fs_rmdir = uv.fs_rmdir, serverstart = vim.fn.serverstart, editor = require('parley.document_registry').editor,
            path = vim.env.PATH, registry = vim.env.FAKE_COUCH_REGISTRY,
            mode = vim.env.FAKE_COUCH_EDITOR_MODE, notify = vim.notify }
        require('tests.helpers.fake_couch').write(root, root .. '/sent', root .. '/argv')
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = root .. '/bin:' .. vim.env.PATH, root .. '/registry.json'
        vim.env.FAKE_COUCH_EDITOR_MODE = nil
        vim.notify = function(message) notices[#notices + 1] = message end
        package.loaded['parley.remote_session'] = nil
        local ok, module = pcall(require, 'parley.remote_session')
        frontend = ok and module or {}
        options = { runtime = { parent = root .. '/runtime', source = require('tests.helpers.fake_process_source').new({
            [uv.os_getpid()] = { started = 'Thu Oct 22 05:00:00 2026' },
        }) } }
    end)
    after_each(function()
        for _, gate in ipairs(gates) do vim.fn.writefile({}, gate) end
        for _, release in ipairs(releases) do release() end
        uv.fs_rmdir, uv.fs_write, uv.fs_fsync = saved.fs_rmdir, saved.fs_write, saved.fs_fsync
        require('parley.remote_runtime').acquire = saved.acquire
        if frontend.close then
            local done; frontend.close(function() done = true end)
            assert.is_true(vim.wait(arrival.MS, function() return done end, 10))
        end
        vim.fn.serverstart = saved.serverstart
        require('parley.document_registry').editor = saved.editor
        require('parley.document_registry').shutdown()
        for _, buf in ipairs(buffers) do pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = saved.path, saved.registry
        vim.env.FAKE_COUCH_EDITOR_MODE, vim.notify = saved.mode, saved.notify
        vim.fn.delete(root, 'rf')
    end)

    it('publishes a real per-file listener and serves only the exact native query tuple', function()
        local buf, registration = identity('session')
        assert.equals('confirmed', attach(buf, registration).kind)
        local state = frontend.snapshot(buf)
        assert.equals('active', state.phase)
        local endpoint = frontend.endpoint(query(state.context))
        assert.equals(registration.File, endpoint.File)
        assert.equals(uv.os_getpid(), endpoint.PID)
        assert.equals('socket', uv.fs_lstat(endpoint.Socket).type)
        local channel = vim.fn.sockconnect('pipe', endpoint.Socket, { rpc = true })
        assert.is_true(channel > 0); vim.fn.chanclose(channel)
        local bad = query(state.context); bad.Buffer = bad.Buffer + 1
        assert.is_nil(frontend.endpoint(bad))
        bad = query(state.context); bad.Extra = true
        assert.is_nil(frontend.endpoint(bad))
        assert.is_false(vim.bo[buf].modified)
        assert.is_true(vim.bo[buf].modifiable)
    end)

    it('retires only an exact superseded generation, without reclaiming on duplicate attach', function()
        local buf, registration = identity('session')
        attach(buf, registration)
        local state = frontend.snapshot(buf)
        local stale = notice(state.binding); stale.BindingGeneration = string.rep('f', 32)
        frontend.superseded(stale)
        assert.equals('active', frontend.snapshot(buf).phase)
        frontend.superseded(notice(state.binding))
        assert.equals('superseded', frontend.snapshot(buf).phase)
        assert.is_nil(frontend.endpoint(query(state.context)))
        assert.is_true(vim.wait(arrival.MS, function() return not uv.fs_lstat(state.context.Socket) end, 10))
        frontend.superseded(notice(state.binding))
        assert.equals(1, #notices)
        attach(buf, registration)
        assert.equals(state.context.AttachID, frontend.snapshot(buf).context.AttachID)
        assert.equals('superseded', frontend.snapshot(buf).phase)
    end)

    it('detaches one buffer without stopping another and advances an explicit reopen counter', function()
        local first, one = identity('one'); local second, two = identity('two')
        attach(first, one); attach(second, two)
        local old = frontend.snapshot(first).context
        frontend.detach(first)
        assert.is_nil(frontend.endpoint(query(old)))
        assert.is_true(vim.wait(arrival.MS, function() return not uv.fs_lstat(old.Socket) end, 10))
        assert.is_table(frontend.endpoint(query(frontend.snapshot(second).context)))
        assert.equals('confirmed', attach(first, one).kind)
        assert.is_not.equals(old.AttachID, frontend.snapshot(first).context.AttachID)
        assert.equals('active', frontend.snapshot(second).phase)
    end)

    it('keeps failed remote publication separate from local editing and submits', function()
        local buf, registration = identity('unavailable')
        vim.env.FAKE_COUCH_EDITOR_MODE = 'malformed'
        assert.equals('unavailable', attach(buf, registration).kind)
        local unconfirmed = frontend.snapshot(buf)
        assert.equals('unconfirmed', unconfirmed.phase)
        assert.equals('socket', uv.fs_lstat(unconfirmed.context.Socket).type)
        assert.equals(1, vim.fn.filereadable(vim.fn.fnamemodify(unconfirmed.context.Socket, ':h') .. '/owner.json'))
        assert.is_true(vim.bo[buf].modifiable)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'local edit' })
        assert.same({ 'local edit' }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        assert.equals(1, #notices)
        assert.equals(0, vim.fn.filereadable(root .. '/sent'))
    end)

    it('reports only the model outcome when a confirmed acknowledgment names a different file', function()
        local buf, registration = identity('mismatched-canonical-file')
        local registry = require('parley.document_registry')
        local editor = registry.editor
        local registrations, unregisters = 0, 0
        registry.editor = function(operation, payload, witness, callback, client_options)
            if operation == 'register' then registrations = registrations + 1 end
            if operation == 'unregister' then unregisters = unregisters + 1 end
            return editor(operation, payload, witness, function(result)
                if operation == 'register' and result.kind == 'confirmed' then
                    result.binding.File = root .. '/another-document.md'
                end
                callback(result)
            end, client_options)
        end
        local result = attach(buf, registration)
        assert.equals('uncertain', result.kind)
        assert.is_nil(result.binding)
        local state = frontend.snapshot(buf)
        assert.equals('unconfirmed', state.phase)
        assert.same(state.result, result)
        assert.equals(1, #notices)
        assert.is_truthy(notices[1]:find('Remote view unavailable', 1, true))
        assert.is_true(vim.bo[buf].modifiable)
        assert.is_false(vim.bo[buf].modified)
        assert.equals('socket', uv.fs_lstat(state.context.Socket).type)
        assert.same(result, attach(buf, registration))
        assert.equals(1, registrations)
        assert.equals(1, #notices)
        frontend.detach(buf)
        assert.is_true(vim.wait(arrival.MS, function() return not uv.fs_lstat(state.context.Socket) end, 10))
        assert.equals(0, unregisters)
    end)

    it('refuses unknown membership before allocating a directory or spawning a command', function()
        local buf, registration = identity('ordinary')
        registration.Namespace = nil
        assert.equals('unavailable', attach(buf, registration).kind)
        assert.is_nil(uv.fs_lstat(root .. '/runtime'))
        assert.equals(0, vim.fn.filereadable(root .. '/registry.json.editor-argv'))
        assert.is_true(vim.bo[buf].modifiable)
    end)

    it('answers nil after a native buffer rename until confirmed republish', function()
        local buf, registration = identity('old')
        attach(buf, registration)
        local context = frontend.snapshot(buf).context
        vim.api.nvim_buf_set_name(buf, root .. '/new.md')
        assert.is_nil(frontend.endpoint(query(context)))
    end)

    it('serializes concurrent attachments through one runtime allocation and closes every listener', function()
        assert.is_function(frontend.attach, 'remote session dispatcher is missing')
        local remaining = 8
        for index = 1, 8 do
            local buf, registration = identity('doc' .. index)
            frontend.attach(buf, registration, function(result)
                assert.equals('confirmed', result.kind, vim.inspect(result)); remaining = remaining - 1
            end, options)
        end
        assert.is_true(vim.wait(arrival.MS, function() return remaining == 0 end, 10))
        local directories = vim.fn.glob(root .. '/runtime/e-*', false, true)
        assert.equals(1, #directories)
        local sockets = {}
        for _, buf in ipairs(buffers) do sockets[#sockets + 1] = frontend.snapshot(buf).context.Socket end
        local done; frontend.close(function() done = true end)
        assert.is_true(vim.wait(arrival.MS, function() return done end, 10))
        for _, socket in ipairs(sockets) do assert.is_nil(uv.fs_lstat(socket)) end
        assert.is_nil(uv.fs_lstat(directories[1]))
    end)

    local function edit_locally(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'unsaved local edit' })
        assert.is_true(vim.bo[buf].modified)
        assert.is_true(vim.bo[buf].modifiable)
    end
    local function assert_local_edit(buf)
        assert.same({ 'unsaved local edit' }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        assert.is_true(vim.bo[buf].modified)
        assert.is_true(vim.bo[buf].modifiable)
    end
    local function hold_ack()
        local gate = root .. '/reply-gate-' .. (#gates + 1)
        gates[#gates + 1] = gate
        options.client = { env = { FAKE_COUCH_EDITOR_REPLY_GATE = gate } }
        return gate
    end
    local function published(registration)
        local binding
        assert.is_true(vim.wait(arrival.MS, function()
            local ok, state = pcall(function()
                return vim.json.decode(table.concat(vim.fn.readfile(root .. '/registry.json'), '\n'))
            end)
            binding = ok and state.editor_endpoints and state.editor_endpoints.current[root .. '\n' .. registration.ID]
            return binding ~= nil
        end, 10))
        return binding
    end
    local function lookup(registration)
        local result
        require('parley.document_registry').editor('lookup', { Namespace = root, DocumentID = registration.ID }, {},
            function(value) result = value end)
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end, 10))
        return result
    end

    it('retires before held runtime identity completes without publishing or changing local edits', function()
        local buf, registration = identity('detach-before-runtime')
        edit_locally(buf)
        local source = options.runtime.source
        source.hold = true
        local calls, result = 0
        frontend.attach(buf, registration, function(value) calls = calls + 1; result = value end, options)
        assert.is_true(vim.wait(arrival.MS, function() return #source.reads == 1 end, 10))
        frontend.detach(buf)
        assert.is_nil(frontend.snapshot(buf))
        source.release(1)
        assert.is_true(vim.wait(arrival.MS, function() return calls == 1 end, 10))
        assert.equals('unavailable', result.kind)
        assert.equals(0, vim.fn.filereadable(root .. '/registry.json.editor-argv'))
        assert.equals(0, #vim.fn.glob(root .. '/runtime/e-*/s*', false, true))
        assert_local_edit(buf)
    end)

    it('joins a held startup on close and ignores its late process-source completion', function()
        local buf, registration = identity('close-before-runtime')
        edit_locally(buf)
        local source = options.runtime.source
        source.hold = true
        local calls, closed = 0, 0
        frontend.attach(buf, registration, function() calls = calls + 1 end, options)
        assert.is_true(vim.wait(arrival.MS, function() return #source.reads == 1 end, 10))
        frontend.close(function() closed = closed + 1 end)
        assert.is_true(vim.wait(arrival.MS, function() return closed == 1 and calls == 1 end, 10))
        source.release(1)
        assert.equals(1, calls)
        assert.equals(1, closed)
        assert.is_nil(frontend.snapshot(buf))
        assert.equals(0, vim.fn.filereadable(root .. '/registry.json.editor-argv'))
        assert_local_edit(buf)
    end)

    it('reports attachment retirement exactly once after native listen and before durable listen completion', function()
        local buf, registration = identity('detach-during-listen')
        edit_locally(buf)
        local calls, closed, detached = 0, 0, false
        local socket_witness, owner_at_start, socket
        local serverstart = vim.fn.serverstart
        -- Observe the real native call; detach at the first instant its socket
        -- exists, before runtime.listen can persist its listening-state marker.
        vim.fn.serverstart = function(path)
            local result = serverstart(path)
            if path:sub(1, #root) == root then
                socket, socket_witness, owner_at_start = path, uv.fs_lstat(path), frontend.snapshot(buf)
                frontend.detach(buf)
                detached = true
            end
            return result
        end
        frontend.attach(buf, registration, function() calls = calls + 1 end, options)
        assert.is_true(vim.wait(arrival.MS, function() return detached end, 10))
        assert.equals('socket', socket_witness and socket_witness.type)
        assert.is_nil(owner_at_start)
        assert.is_true(vim.wait(arrival.MS, function() return calls == 1 end, 10))
        frontend.close(function() closed = closed + 1 end)
        assert.is_true(vim.wait(arrival.MS, function() return closed == 1 end, 10))
        assert.equals(1, calls)
        assert.is_nil(frontend.snapshot(buf))
        assert.is_nil(uv.fs_lstat(socket))
        assert.equals(0, vim.fn.filereadable(root .. '/registry.json.editor-argv'))
        assert_local_edit(buf)
    end)

    it('compares a pre-ack supersession notice before activating and reports the attach once', function()
        local buf, registration = identity('notice-before-ack')
        edit_locally(buf)
        local gate = hold_ack()
        local calls = 0
        frontend.attach(buf, registration, function() calls = calls + 1 end, options)
        local binding = published(registration)
        assert.equals('publishing', frontend.snapshot(buf).phase)
        frontend.superseded(notice(binding))
        frontend.superseded(notice(binding))
        assert.equals('publishing', frontend.snapshot(buf).phase)
        vim.fn.writefile({}, gate)
        assert.is_true(vim.wait(arrival.MS, function() return calls == 1 end, 10))
        assert.equals('superseded', frontend.snapshot(buf).phase)
        assert.is_nil(frontend.endpoint(query(binding)))
        assert.is_true(vim.wait(arrival.MS, function() return not uv.fs_lstat(binding.Socket) end, 10))
        assert.equals(1, #notices)
        assert_local_edit(buf)
    end)

    it('cleans a detached late acknowledgment without activating it or erasing its successor', function()
        local buf, registration = identity('detach-before-ack')
        edit_locally(buf)
        local gate = hold_ack()
        local calls, old_result, cleaned = 0, nil, 0
        local registry = require('parley.document_registry')
        local editor = registry.editor
        registry.editor = function(operation, payload, witness, callback, client_options)
            return editor(operation, payload, witness, function(result)
                if operation == 'unregister' then cleaned = cleaned + 1 end
                callback(result)
            end, client_options)
        end
        frontend.attach(buf, registration, function(value) calls = calls + 1; old_result = value end, options)
        local old = published(registration)
        frontend.detach(buf)
        assert.is_nil(frontend.endpoint(query(old)))
        options.client = nil
        local successor_calls, successor_result = 0
        frontend.attach(buf, registration, function(value)
            successor_calls = successor_calls + 1; successor_result = value
        end, options)
        vim.fn.writefile({}, gate)
        assert.is_true(vim.wait(arrival.MS, function() return calls == 1 and successor_calls == 1 end, 10))
        assert.equals('confirmed', successor_result.kind)
        local successor = frontend.snapshot(buf)
        assert.is_not.equals(old.AttachID, successor.context.AttachID)
        assert.equals('confirmed', old_result.kind)
        assert.is_true(vim.wait(arrival.MS, function() return cleaned == 1 end, 10))
        frontend.superseded(notice(old))
        assert.equals('active', frontend.snapshot(buf).phase)
        local current = lookup(registration)
        assert.equals('confirmed', current.kind)
        assert.equals(successor.binding.BindingGeneration, current.binding.BindingGeneration)
        assert.is_table(frontend.endpoint(query(successor.context)))
        assert.equals(1, calls)
        assert_local_edit(buf)
    end)

    it('closes the last superseded runtime without forgetting terminal attachment history', function()
        local buf, registration = identity('terminal-superseded')
        attach(buf, registration)
        local old = frontend.snapshot(buf)
        local directory = vim.fn.fnamemodify(old.context.Socket, ':h')
        frontend.superseded(notice(old.binding))
        assert.is_true(vim.wait(arrival.MS, function() return not uv.fs_lstat(directory) end, 10))
        assert.equals('superseded', frontend.snapshot(buf).phase)
        assert.is_nil(frontend.endpoint(query(old.context)))
        attach(buf, registration)
        local duplicate = frontend.snapshot(buf)
        assert.equals('superseded', duplicate.phase)
        assert.equals(old.context.AttachID, duplicate.context.AttachID)
        local registrations = 0
        for _, operation in ipairs(vim.fn.readfile(root .. '/registry.json.editor-launches')) do
            if operation == 'register' then registrations = registrations + 1 end
        end
        assert.equals(1, registrations)
        assert.is_nil(uv.fs_lstat(directory))
    end)

    it('closes permanently refused publication resources while preserving refusal history', function()
        local buf, registration = identity('terminal-refused')
        vim.fn.writefile({ vim.json.encode({ paths = vim.empty_dict(), moves = vim.empty_dict() }) }, root .. '/registry.json')
        local result = attach(buf, registration)
        assert.equals('refused', result.kind)
        assert.equals('not-registered', result.code)
        local old = frontend.snapshot(buf)
        assert.equals('unavailable', old.phase)
        local directory = vim.fn.fnamemodify(old.context.Socket, ':h')
        assert.is_true(vim.wait(arrival.MS, function() return not uv.fs_lstat(directory) end, 10))
        assert.equals('refused', attach(buf, registration).kind)
        assert.equals(old.context.AttachID, frontend.snapshot(buf).context.AttachID)
        assert.equals('unavailable', frontend.snapshot(buf).phase)
        local registrations = 0
        for _, operation in ipairs(vim.fn.readfile(root .. '/registry.json.editor-launches')) do
            if operation == 'register' then registrations = registrations + 1 end
        end
        assert.equals(1, registrations)
    end)

    it('cancels its unstarted registry publication when four live children hold every transport slot', function()
        local buf, registration = identity('queued-publication')
        edit_locally(buf)
        local registry = require('parley.document_registry')
        local blockers, finished = {}, 0
        for _ = 1, 4 do
            blockers[#blockers + 1] = registry.editor('lookup', { Namespace = root, DocumentID = registration.ID }, {},
                function() finished = finished + 1 end,
                { env = { FAKE_COUCH_EDITOR_MODE = 'delay', FAKE_COUCH_EDITOR_DELAY = '10' } })
        end
        local launches = root .. '/registry.json.editor-launches'
        assert.is_true(vim.wait(arrival.MS, function()
            return vim.fn.filereadable(launches) == 1 and #vim.fn.readfile(launches) == 4
        end, 10))
        local calls = 0
        frontend.attach(buf, registration, function() calls = calls + 1 end, options)
        assert.is_true(vim.wait(arrival.MS, function()
            local state = frontend.snapshot(buf)
            return state and state.phase == 'publishing'
        end, 10))
        frontend.detach(buf)
        for _, blocker in ipairs(blockers) do blocker.cancel() end
        assert.is_true(vim.wait(arrival.MS, function() return finished == 4 and calls == 1 end, 10))
        local registrations = 0
        for _, operation in ipairs(vim.fn.readfile(launches)) do
            if operation == 'register' then registrations = registrations + 1 end
        end
        assert.equals(0, registrations)
        assert.is_nil(frontend.snapshot(buf))
        assert_local_edit(buf)
    end)

    it('cancels and joins the last held startup directly on detach without releasing its source', function()
        local buf, registration = identity('last-startup-consumer')
        edit_locally(buf)
        local source = options.runtime.source
        source.hold = true
        local calls = 0
        frontend.attach(buf, registration, function() calls = calls + 1 end, options)
        assert.is_true(vim.wait(arrival.MS, function() return #source.pending == 1 end, 10))
        frontend.detach(buf)
        -- Cancellation must originate from departure, before the independent
        -- process-inspection deadline could eventually cancel the held source.
        assert.is_true(source.pending[1].canceled)
        assert.is_true(vim.wait(arrival.MS, function() return calls == 1 end, 10))
        assert.is_false(source.pending[1].delivered == true)
        source.release(1)
        assert.equals(1, calls)
        assert.equals(0, #vim.fn.glob(root .. '/runtime/e-*', false, true))
        assert.equals(0, vim.fn.filereadable(root .. '/registry.json.editor-argv'))
        assert_local_edit(buf)
    end)

    it('removes the final detached listener marker and directory without closing the editor', function()
        local buf, registration = identity('final-runtime-consumer')
        attach(buf, registration)
        edit_locally(buf)
        local context = frontend.snapshot(buf).context
        local directory = vim.fn.fnamemodify(context.Socket, ':h')
        assert.equals(1, vim.fn.filereadable(directory .. '/owner.json'))
        frontend.detach(buf)
        assert.is_true(vim.wait(arrival.MS, function() return not uv.fs_lstat(directory) end, 10))
        assert.is_nil(uv.fs_lstat(context.Socket))
        assert.is_nil(uv.fs_lstat(directory .. '/owner.json'))
        assert.is_nil(frontend.endpoint(query(context)))
        assert_local_edit(buf)
    end)

    it('waits for the exact old runtime close before allocating for an attachment arriving during drain', function()
        local first, one = identity('draining-runtime')
        local second, two = identity('fresh-runtime')
        attach(first, one)
        local old = frontend.snapshot(first).context
        local old_directory = vim.fn.fnamemodify(old.Socket, ':h')
        local original_rmdir = uv.fs_rmdir
        local held, release_close = false
        uv.fs_rmdir = function(path, callback)
            if path == old_directory and type(callback) == 'function' and not held then
                return original_rmdir(path, function(err, result)
                    held = true
                    local released = false
                    release_close = function()
                        if released then return end
                        released = true
                        callback(err, result)
                    end
                    releases[#releases + 1] = release_close
                end)
            end
            return original_rmdir(path, callback)
        end
        frontend.detach(first)
        assert.is_true(vim.wait(arrival.MS, function() return held end, 10))
        assert.is_nil(uv.fs_lstat(old_directory))
        local calls, result = 0
        frontend.attach(second, two, function(value) calls = calls + 1; result = value end, options)
        assert.equals(0, calls)
        assert.is_nil(frontend.snapshot(second))
        assert.equals(1, #options.runtime.source.reads)
        release_close()
        assert.is_true(vim.wait(arrival.MS, function() return calls == 1 end, 10))
        assert.equals('confirmed', result.kind)
        local fresh = frontend.snapshot(second)
        assert.equals('active', fresh.phase)
        assert.is_not.equals(old_directory, vim.fn.fnamemodify(fresh.context.Socket, ':h'))
        assert.equals(2, #options.runtime.source.reads)
        assert.is_table(frontend.endpoint(query(fresh.context)))
        assert.is_nil(frontend.endpoint(query(old)))
        assert.equals('socket', uv.fs_lstat(fresh.context.Socket).type)
    end)

    -- Hold only delivery of real IO completions. The returned real listen
    -- handle is observed independently from the shared acquisition handle.
    local function hold_listen(stage, target_buf, target_name)
        local control = { cancels = 0, shared_cancels = 0, starts = 0, later_starts = 0, later_writes = 0 }
        local runtime_module = require('parley.remote_runtime')
        local acquire = runtime_module.acquire
        local descriptors = {}
        local function hold(callback)
            control.paused = true
            local released = false
            control.release = function()
                if released then return end
                released = true
                callback()
            end
            releases[#releases + 1] = control.release
        end
        runtime_module.acquire = function(runtime_options, callback)
            local operation = acquire(runtime_options, function(result)
                if result.kind == 'ready' and not control.directory then
                    local resource = result.runtime
                    control.directory, control.path = resource.directory, resource.directory .. '/' .. target_name
                    local stop = resource.stop
                    resource.stop = function(name, ready)
                        return stop(name, function(value)
                            if ready then ready(value) end
                            if name == target_name then
                                control.stop_result = value
                                control.stopped = value.kind == 'closed'
                            end
                        end)
                    end
                    local listen = resource.listen
                    resource.listen = function(name, ready)
                        local handle = listen(name, function(value)
                            if name == target_name and stage == 'completed callback' and not control.paused then
                                control.completed_result = value
                                hold(function() ready(value) end)
                            else ready(value) end
                        end)
                        if name == target_name then
                            local cancel = handle.cancel
                            handle.cancel = function(...)
                                control.cancels = control.cancels + 1
                                return cancel(...)
                            end
                            control.handle = handle
                        end
                        return handle
                    end
                end
                callback(result)
            end)
            local cancel = operation.cancel
            operation.cancel = function(...)
                control.shared_cancels = control.shared_cancels + 1
                return cancel(...)
            end
            return operation
        end
        uv.fs_write = function(fd, data, offset, callback)
            if type(data) == 'string' then
                local ok, record = pcall(vim.json.decode, data)
                local last = ok and type(record) == 'table' and type(record.Sockets) == 'table'
                    and record.Sockets[#record.Sockets]
                if last and last.Name == target_name and control.directory
                    and record.Directory.Name == vim.fn.fnamemodify(control.directory, ':t') then
                    descriptors[fd] = last.State
                    if control.retired then control.later_writes = control.later_writes + 1 end
                end
            end
            return saved.fs_write(fd, data, offset, callback)
        end
        uv.fs_fsync = function(fd, callback)
            if type(callback) == 'function' and not control.paused
                and ((stage == 'reservation fsync' and descriptors[fd] == 'reserved')
                    or (stage == 'listening marker fsync' and descriptors[fd] == 'listening')) then
                return saved.fs_fsync(fd, function(err, result)
                    hold(function() callback(err, result) end)
                end)
            end
            return saved.fs_fsync(fd, callback)
        end
        vim.fn.serverstart = function(path)
            local result = saved.serverstart(path)
            if path == control.path then
                control.starts = control.starts + 1
                if control.retired then control.later_starts = control.later_starts + 1 end
                if stage == 'native listen return' and not control.paused then
                    control.paused, control.retired = true, true
                    frontend.detach(target_buf)
                end
            end
            return result
        end
        return control
    end

    for _, stage in ipairs({ 'reservation fsync', 'native listen return', 'listening marker fsync', 'completed callback' }) do
        it('cancels the exact consumer listen at ' .. stage .. ' and joins its owned effects', function()
            local buf, registration = identity('canceled-' .. stage:gsub(' ', '-'))
            local keeper, keeper_registration, reuse, reuse_registration
            if stage == 'reservation fsync' then
                keeper, keeper_registration = identity('still-live-consumer')
                reuse, reuse_registration = identity('reuse-canceled-listener-slot')
            end
            local control = hold_listen(stage, buf, keeper and 's2' or 's1')
            if keeper then assert.equals('confirmed', attach(keeper, keeper_registration).kind) end
            local calls, result = 0
            frontend.attach(buf, registration, function(value) calls = calls + 1; result = value end, options)
            assert.is_true(vim.wait(arrival.MS, function() return control.paused end, 10))
            assert.is_table(control.handle)
            if stage ~= 'native listen return' then
                control.retired = true
                frontend.detach(buf)
            end
            assert.equals(1, control.cancels)
            assert.equals(0, control.shared_cancels)
            assert.is_nil(frontend.snapshot(buf))
            if control.release then control.release() end
            assert.is_true(vim.wait(arrival.MS, function() return calls == 1 end, 10))
            assert.equals('unavailable', result.kind)
            assert.equals(0, control.later_starts)
            assert.equals(0, control.later_writes)
            assert.is_nil(uv.fs_lstat(control.path))
            if keeper then
                local keeper_state = frontend.snapshot(keeper)
                assert.equals('active', keeper_state.phase)
                assert.is_table(frontend.endpoint(query(keeper_state.context)))
                assert.equals('socket', uv.fs_lstat(keeper_state.context.Socket).type)
                local channel = vim.fn.sockconnect('pipe', keeper_state.context.Socket, { rpc = true })
                assert.is_true(channel > 0)
                vim.fn.chanclose(channel)
                assert.is_true(vim.wait(arrival.MS, function() return control.stopped end, 10))
                local marker = assert(require('parley.remote_runtime_record').decode(
                    table.concat(vim.fn.readfile(control.directory .. '/owner.json'), '\n')))
                for _, socket in ipairs(marker.Sockets) do assert.is_not.equals('s2', socket.Name) end
                assert.equals('confirmed', attach(reuse, reuse_registration).kind)
                assert.equals(control.path, frontend.snapshot(reuse).context.Socket)
                assert.equals('active', frontend.snapshot(keeper).phase)
                frontend.detach(reuse)
                frontend.detach(keeper)
            end
            assert.is_true(vim.wait(arrival.MS, function() return not uv.fs_lstat(control.directory) end, 10))
            local registers = 0
            local launches = root .. '/registry.json.editor-launches'
            if vim.fn.filereadable(launches) == 1 then
                for _, operation in ipairs(vim.fn.readfile(launches)) do
                    if operation == 'register' then registers = registers + 1 end
                end
            end
            assert.equals(keeper and 2 or 0, registers)
            local fresh, fresh_registration = identity('fresh-after-' .. stage:gsub(' ', '-'))
            assert.equals('confirmed', attach(fresh, fresh_registration).kind)
            local fresh_state = frontend.snapshot(fresh)
            assert.is_not.equals(control.directory, vim.fn.fnamemodify(fresh_state.context.Socket, ':h'))
            assert.equals('active', fresh_state.phase)
            assert.equals(1, calls)
        end)
    end

    it('retains a foreign socket replacement when a completed listen result retires before delivery', function()
        local buf, registration = identity('foreign-completed-listen')
        local control = hold_listen('completed callback', buf, 's1')
        local calls = 0
        frontend.attach(buf, registration, function() calls = calls + 1 end, options)
        assert.is_true(vim.wait(arrival.MS, function() return control.paused end, 10))
        assert.equals('listening', control.completed_result.kind)
        local displaced = root .. '/displaced-owned-socket'
        assert(uv.fs_rename(control.path, displaced))
        vim.fn.writefile({ 'foreign replacement' }, control.path)
        local foreign = assert(uv.fs_lstat(control.path))
        -- Only test teardown removes the sentinel. Runtime cleanup must retain it.
        releases[#releases + 1] = function()
            local current = uv.fs_lstat(control.path)
            if current and current.dev == foreign.dev and current.ino == foreign.ino then uv.fs_unlink(control.path) end
            -- The socket itself was created by this test. End its native
            -- lifetime after the foreign sentinel has passed its assertions.
            pcall(vim.fn.serverstop, control.path)
        end
        control.retired = true
        frontend.detach(buf)
        assert.equals(1, control.cancels)
        control.release()
        assert.is_true(vim.wait(arrival.MS, function() return calls == 1 end, 10))
        assert.same({ 'foreign replacement' }, vim.fn.readfile(control.path))
        local current = assert(uv.fs_lstat(control.path))
        assert.equals(foreign.dev, current.dev)
        assert.equals(foreign.ino, current.ino)
        assert.is_nil(frontend.snapshot(buf))
        assert.equals(0, vim.fn.filereadable(root .. '/registry.json.editor-argv'))
    end)

    for _, count in ipairs({ 8, 16 }) do
        it('does one startup read and exactly ' .. count .. ' publications despite duplicate lifecycle events', function()
            local prepared = {}
            for index = 1, count do
                local buf, registration = identity('counted-' .. index)
                prepared[#prepared + 1] = { buf = buf, registration = registration, calls = 0, duplicates = 0 }
            end
            local remaining = count
            for _, item in ipairs(prepared) do
                frontend.attach(item.buf, item.registration, function(result)
                    item.calls = item.calls + 1
                    assert.equals('confirmed', result.kind, vim.inspect(result))
                    remaining = remaining - 1
                end, options)
                for _ = 1, 2 do
                    frontend.attach(item.buf, item.registration, function() item.duplicates = item.duplicates + 1 end, options)
                end
            end
            assert.is_true(vim.wait(arrival.MS, function() return remaining == 0 end, 10))
            for _, item in ipairs(prepared) do
                assert.equals(1, item.calls)
                assert.equals(2, item.duplicates)
                assert.equals('active', frontend.snapshot(item.buf).phase)
                frontend.attach(item.buf, item.registration, function(result)
                    assert.equals('confirmed', result.kind)
                    item.duplicates = item.duplicates + 1
                end, options)
                assert.equals(3, item.duplicates)
            end
            assert.equals(1, #options.runtime.source.reads)
            local registers = 0
            for _, operation in ipairs(vim.fn.readfile(root .. '/registry.json.editor-launches')) do
                if operation == 'register' then registers = registers + 1 end
            end
            assert.equals(count, registers)
            assert.equals(1, #vim.fn.glob(root .. '/runtime/e-*', false, true))
        end)
    end

end)
