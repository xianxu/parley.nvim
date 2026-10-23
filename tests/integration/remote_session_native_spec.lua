local uv = vim.uv or vim.loop
local arrival = require('tests.helpers.arrival')
local Embedded = require('tests.helpers.embedded_nvim')

describe('private editor endpoint native document lifetime', function()
    local root, child, registrations
    local function document(name, lines, tracked)
        local file = root .. '/' .. name
        vim.fn.mkdir(vim.fs.dirname(file), 'p')
        vim.fn.writefile(lines or { '# Original', 'original contents' }, file)
        if tracked ~= false then
            registrations[file] = { ID = vim.fn.sha256(name):sub(1, 32), Namespace = root, File = file,
                Owner = 'ops:0', RegisteredOwner = 'ops:0', RegisteredAt = '2026-10-22T00:00:00Z' }
            vim.fn.writefile({ vim.json.encode({ paths = registrations, moves = vim.empty_dict() }) }, root .. '/registry.json')
        end
        return file
    end
    local function open(file, pane, fixture)
        child:exec([[
            local root, file, pane, fixture = ...
            fixture = fixture or {}
            vim.env.PATH = root .. '/bin:' .. vim.env.PATH
            vim.env.FAKE_COUCH_REGISTRY = root .. '/registry.json'
            vim.env.FAKE_COUCH_REGISTRY_MODE, vim.env.FAKE_COUCH_EDITOR_MODE = fixture.registry_mode, fixture.editor_mode
            vim.env.COUCH_ISOLATED_ROOT = root
            vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = pane and 'native-endpoint' or nil, pane and 'pane' or nil
            vim.env.FAKE_COUCH_ACTORS = vim.json.encode({ Code = 'ok', Actors = {
                { Binding = { Slot = 'ops:0', Scope = 'native-endpoint', Tag = 'pane' } },
            } })
            _G.endpoint_probe = { lookups = 0, lookup_completions = 0, registers = 0, renames = 0, rename_completions = 0, acquires = 0, notices = {} }
            _G.held_endpoint_lookups = {}
            vim.notify = function(message) endpoint_probe.notices[#endpoint_probe.notices + 1] = message end
            local registry = require('parley.document_registry')
            local request, editor = registry.request, registry.editor
            registry.request = function(operation, args, witness, callback, options)
                if operation == 'lookup' then endpoint_probe.lookups = endpoint_probe.lookups + 1 end
                if operation == 'rename' then endpoint_probe.renames = endpoint_probe.renames + 1 end
                local ordinal = endpoint_probe.lookups
                if operation == 'lookup' and fixture.lookup_timeout_ms and vim.env.FAKE_COUCH_REGISTRY_MODE == 'delay' then
                    options = vim.tbl_extend('force', {}, options or {}, { timeout_ms = fixture.lookup_timeout_ms })
                end
                return request(operation, args, witness, function(result)
                    if operation == 'lookup' then
                        endpoint_probe.lookup_completions = endpoint_probe.lookup_completions + 1
                        endpoint_probe.lookup_result = result.kind
                        endpoint_probe.lookup_error = result.error
                    end
                    if operation == 'rename' then endpoint_probe.rename_completions = endpoint_probe.rename_completions + 1 end
                    if operation == 'lookup' and ordinal <= (fixture.hold_lookups or 0) then
                        held_endpoint_lookups[ordinal] = function() callback(result) end
                    elseif operation == 'rename' and fixture.hold_rename and not endpoint_probe.rename_held then
                        endpoint_probe.rename_held = true
                        _G.held_endpoint_rename = function() callback(result) end
                    else callback(result) end
                end, options)
            end
            registry.editor = function(operation, ...)
                if operation == 'register' then endpoint_probe.registers = endpoint_probe.registers + 1 end
                return editor(operation, ...)
            end
            local runtime = require('parley.remote_runtime')
            local acquire = runtime.acquire
            local source = require('tests.helpers.fake_process_source').new({
                [(vim.uv or vim.loop).os_getpid()] = { started = 'Thu Oct 22 05:00:00 2026' },
            })
            runtime.acquire = function(options, callback)
                endpoint_probe.acquires = endpoint_probe.acquires + 1
                return acquire(vim.tbl_extend('force', {}, options, { parent = root .. '/runtime', source = source }), callback)
            end
            require('parley').config.state_dir = root .. '/state'
            if fixture.chat_dirs then
                require('parley').config.review_shortcut_next = { modes = { 'n', 'i' }, shortcut = '<M-CR>' }
                assert(require('parley').set_chat_dirs(fixture.chat_dirs, false))
            end
            require('parley.session_sync').POLL_MS = 60000
            vim.cmd('edit ' .. vim.fn.fnameescape(file))
            _G.endpoint_buf = vim.api.nvim_get_current_buf()
            require('parley').setup_markdown_keymaps(endpoint_buf)
        ]], root, file, pane == true, fixture or {})
    end
    local function observe(phase)
        return child:exec([[
            local phase, arrival_ms = ...
            local state
            local complete = vim.wait(arrival_ms, function()
                state = require('parley.remote_session').snapshot(endpoint_buf)
                return state and state.phase == phase
            end, 10)
            return { complete = complete, state = state, counts = endpoint_probe,
                identity = require('parley.session_sync').identity(endpoint_buf),
                agentic = require('parley.agentic_document').status(endpoint_buf) }
        ]], phase or 'active', arrival.MS)
    end
    before_each(function()
        local base = uv.fs_stat('/Volumes/TestScratch') and '/Volumes/TestScratch' or (vim.env.TMPDIR or uv.os_tmpdir())
        root = assert(uv.fs_mkdtemp(base .. '/rn-XXXXXX'))
        registrations = {}
        require('tests.helpers.fake_couch').write(root, root .. '/sent', root .. '/argv')
        child = Embedded.start()
    end)
    after_each(function()
        if child then
            pcall(function()
                child:exec([[
                    local arrival_ms = ...
                    local complete
                    require('parley.remote_session').close(function() complete = true end)
                    assert(vim.wait(arrival_ms, function() return complete end, 10), 'endpoint close did not finish')
                    require('parley.document_registry').shutdown()
                ]], arrival.MS)
            end)
            child:stop()
        end
        vim.fn.delete(root, 'rf')
    end)

    it('discovers a registered headerless file outside Couch once without adopting submit or turn ownership', function()
        local file = document('session.side/01-question.md')
        open(file)
        local observed = observe()
        assert.is_true(observed.complete, vim.inspect(observed))
        assert.equals(registrations[file].ID, observed.state.context.DocumentID)
        assert.is_nil(observed.identity)
        assert.is_nil(observed.agentic)
        child:exec([[for _ = 1, 8 do require('parley').setup_markdown_keymaps(endpoint_buf) end]])
        local counts = child:exec('return endpoint_probe')
        assert.equals(1, counts.lookups)
        assert.equals(1, counts.registers)
        assert.equals(0, vim.fn.filereadable(root .. '/sent'))
        assert.equals('socket', uv.fs_lstat(observed.state.context.Socket).type)
    end)

    for _, failure in ipairs({
        { name = 'unavailable command', registry_mode = 'unsupported' },
        { name = 'malformed reply', registry_mode = 'malformed' },
        { name = 'missing absence witness', registry_mode = 'missing' },
        { name = 'lookup timeout', registry_mode = 'delay', lookup_timeout_ms = 50 },
        { name = 'rejected identity', invalid_identity = true },
        { name = 'rejected registration', editor_mode = 'wrong-identity', allocated = true, registers = 1 },
        { name = 'rejected runtime', unsafe_runtime = true, allocated = true, registers = 0 },
    }) do
        it('reports ' .. failure.name .. ' once per outside-pane incarnation and retries only on reopen', function()
            local file = document('discovery-failure.md')
            if failure.invalid_identity then
                registrations[file].ID = 'invalid'
                vim.fn.writefile({ vim.json.encode({ paths = registrations, moves = vim.empty_dict() }) }, root .. '/registry.json')
            end
            if failure.unsafe_runtime then assert(uv.fs_mkdir(root .. '/runtime', 493)) end
            open(file, false, failure)
            local first = child:exec([[
                local arrival_ms = ...
                assert(vim.wait(arrival_ms, function() return #endpoint_probe.notices > 0 end, 10),
                    'discovery failure must surface remote unavailability')
                for _ = 1, 8 do require('parley').setup_markdown_keymaps(endpoint_buf) end
                return { counts = endpoint_probe, modifiable = vim.bo[endpoint_buf].modifiable,
                    modified = vim.bo[endpoint_buf].modified, lines = vim.api.nvim_buf_get_lines(endpoint_buf, 0, -1, false) }
            ]], arrival.MS)
            assert.equals(1, first.counts.lookups)
            assert.equals(1, #first.counts.notices, 'discovery callback and dispatcher share one notice owner')
            assert.equals('Remote view unavailable; reopen the file to retry', first.counts.notices[1])
            assert.equals(failure.allocated and 1 or 0, first.counts.acquires)
            assert.equals(failure.registers or 0, first.counts.registers)
            assert.equals((failure.invalid_identity or failure.allocated) and 'registered' or 'unavailable', first.counts.lookup_result)
            if failure.lookup_timeout_ms then assert.matches('deadline exceeded', first.counts.lookup_error) end
            assert.is_true(first.modifiable)
            assert.is_false(first.modified)
            assert.same({ '# Original', 'original contents' }, first.lines)
            if not failure.allocated then assert.is_nil(uv.fs_lstat(root .. '/runtime')) end
            if failure.unsafe_runtime then assert(uv.fs_chmod(root .. '/runtime', 448)) end
            registrations[file].ID = vim.fn.sha256('discovery-failure.md'):sub(1, 32)
            vim.fn.writefile({ vim.json.encode({ paths = registrations, moves = vim.empty_dict() }) }, root .. '/registry.json')
            child:exec([[
                vim.env.FAKE_COUCH_REGISTRY_MODE, vim.env.FAKE_COUCH_EDITOR_MODE = nil, nil
                vim.cmd('edit!')
            ]])
            local reopened = observe()
            assert.is_true(reopened.complete, vim.inspect(reopened))
            assert.equals(2, reopened.counts.lookups)
            assert.equals(1, #reopened.counts.notices)
        end)
    end

    it('leaves an ordinary outside-Couch Markdown file local after its one positive absence lookup', function()
        open(document('ordinary.md', nil, false))
        local observed = child:exec([[
            local arrival_ms = ...
            local complete = vim.wait(arrival_ms, function() return endpoint_probe.lookup_completions == 1 end, 10)
            for _ = 1, 8 do require('parley').setup_markdown_keymaps(endpoint_buf) end
            return { complete = complete, counts = endpoint_probe,
                state = require('parley.remote_session').snapshot(endpoint_buf),
                modifiable = vim.bo[endpoint_buf].modifiable }
        ]], arrival.MS)
        assert.is_true(observed.complete)
        assert.equals(1, observed.counts.lookups)
        assert.equals(0, observed.counts.registers)
        assert.is_nil(observed.state)
        assert.is_true(observed.modifiable)
        assert.same({}, observed.counts.notices)
        assert.is_nil(uv.fs_lstat(root .. '/runtime'))
    end)

    for _, terminal in ipairs({ false, true }) do
        it('preserves ' .. (terminal and 'superseded' or 'active') .. ' attachment history through passive and guarded native rereads', function()
            local file = document('reads.md')
            open(file)
            local first = observe()
            assert.is_true(first.complete, vim.inspect(first))
            if terminal then
                child:exec([[
                    local binding = require('parley.remote_session').snapshot(endpoint_buf).binding
                    require('parley.remote_session').superseded({ Namespace = binding.Namespace,
                        DocumentID = binding.DocumentID, EditorIncarnation = binding.EditorIncarnation,
                        AttachID = binding.AttachID, BindingGeneration = binding.BindingGeneration })
                ]])
            end
            child:exec('vim.bo[endpoint_buf].autoread = true')
            vim.fn.writefile({ '# New disk contents', 'externally rewritten' }, file)
            child:exec([[vim.cmd('checktime')]])
            child:exec([[
                require('parley.session_sync').with_buffer_read(endpoint_buf, function() vim.cmd('edit!') end)
            ]])
            local after = observe(terminal and 'superseded' or 'active')
            assert.is_true(after.complete, vim.inspect(after))
            assert.equals(first.state.context.AttachID, after.state.context.AttachID)
            assert.equals(1, after.counts.lookups)
            assert.equals(1, after.counts.registers)
            child:exec([[vim.cmd('edit!')]])
            local reopened = observe()
            assert.is_true(reopened.complete, vim.inspect(reopened))
            assert.is_not.equals(first.state.context.AttachID, reopened.state.context.AttachID)
            assert.equals(2, reopened.counts.lookups)
            assert.equals(2, reopened.counts.registers)
        end)
    end

    for _, side in ipairs({ false, true }) do
        it('advertises a confirmed ' .. (side and 'side document' or 'session file') .. ' through the existing Couch-pane admission', function()
            local lines
            if not side then lines = { '---', 'type: session-sync', 'owner: ops:0', '---', '# Session', 'body' } end
            local file = document(side and 'session.side/01-side.md' or 'session.md', lines)
            open(file, true)
            local observed = observe()
            assert.is_true(observed.complete, vim.inspect(observed))
            assert.equals(registrations[file].ID, observed.identity.ID)
            assert.equals(observed.identity.ID, observed.state.context.DocumentID)
            assert.equals(1, observed.counts.lookups)
            assert.equals(1, observed.counts.registers)
        end)
    end

    for _, lookup_failure in ipairs({ false, true }) do
        it('ignores a real ' .. (lookup_failure and 'failed' or 'registered') .. ' lookup completed for an unloaded incarnation', function()
            local file = document('held-discovery.md')
            open(file, false, { hold_lookups = 2, registry_mode = lookup_failure and 'malformed' or nil })
            local observed = child:exec([[
                local file, arrival_ms = ...
                local remote = require('parley.remote_session')
                assert(vim.wait(arrival_ms, function() return held_endpoint_lookups[1] ~= nil end, 10), 'first lookup not held')
                local old_buf = endpoint_buf
                assert(remote.snapshot(old_buf) == nil)
                vim.env.FAKE_COUCH_REGISTRY_MODE = nil
                vim.cmd('bdelete! ' .. old_buf)
                vim.cmd('edit ' .. vim.fn.fnameescape(file))
                endpoint_buf = vim.api.nvim_get_current_buf()
                assert(endpoint_buf == old_buf, 'fixture must reuse one buffer across true unload/reopen')
                require('parley').setup_markdown_keymaps(endpoint_buf)
                assert(vim.wait(arrival_ms, function() return held_endpoint_lookups[2] ~= nil end, 10), 'reopen lookup not held')
                held_endpoint_lookups[1]()
                local stale_advertised = remote.snapshot(endpoint_buf) ~= nil
                local stale_registers, stale_acquires = endpoint_probe.registers, endpoint_probe.acquires
                held_endpoint_lookups[2]()
                local complete = vim.wait(arrival_ms, function()
                    local state = remote.snapshot(endpoint_buf)
                    return state and state.phase == 'active'
                end, 10)
                return { complete = complete, stale_advertised = stale_advertised, stale_registers = stale_registers, stale_acquires = stale_acquires,
                    state = remote.snapshot(endpoint_buf), counts = endpoint_probe }
            ]], file, arrival.MS)
            assert.is_false(observed.stale_advertised)
            assert.equals(0, observed.stale_registers)
            assert.equals(0, observed.stale_acquires)
            assert.is_true(observed.complete, vim.inspect(observed))
            assert.equals(registrations[file].ID, observed.state.context.DocumentID)
            assert.equals(2, observed.counts.lookups)
            assert.equals(1, observed.counts.registers)
            assert.same({}, observed.counts.notices)
        end)
    end

    for _, door in ipairs({ 'move_path', 'saveas' }) do
        it('fences a registered ' .. door .. ' until its real registry rename confirms the stable ID', function()
            local source, destination = root .. '/source', root .. '/destination'
            vim.fn.mkdir(destination, 'p')
            local file = document('source/ordinary.md', { '---', 'owner: business-team', '---', '# Original', 'original' })
            local target = destination .. '/renamed.md'
            open(file, true, { chat_dirs = { source, destination }, hold_rename = true })
            local first = observe()
            assert.is_true(first.complete, vim.inspect(first))
            local observed = child:exec([[
                local file, target, door, arrival_ms = ...
                local remote = require('parley.remote_session')
                local old = assert(remote.snapshot(endpoint_buf)).context
                local old_query = { Namespace = old.Namespace, DocumentID = old.DocumentID,
                    EditorIncarnation = old.EditorIncarnation, AttachID = old.AttachID, Buffer = old.Buffer }
                if door == 'move_path' then
                    local handled, moved, err = require('parley.agentic_document').move_path(file, target)
                    assert(handled and moved == target, tostring(err))
                else vim.cmd('saveas ' .. vim.fn.fnameescape(target)) end
                assert(vim.wait(arrival_ms, function() return held_endpoint_rename ~= nil end, 10), 'rename acknowledgment not held')
                local paused = remote.snapshot(endpoint_buf) == nil and remote.endpoint(old_query) == nil
                local registers_before_ack = endpoint_probe.registers
                held_endpoint_rename()
                local complete = vim.wait(arrival_ms, function()
                    local state = remote.snapshot(endpoint_buf)
                    return state and state.phase == 'active' and state.context.File == target
                end, 10)
                return { complete = complete, paused = paused, registers_before_ack = registers_before_ack,
                    state = remote.snapshot(endpoint_buf), identity = require('parley.session_sync').identity(endpoint_buf),
                    counts = endpoint_probe, modifiable = vim.bo[endpoint_buf].modifiable }
            ]], file, target, door, arrival.MS)
            assert.is_true(observed.paused, vim.inspect(observed))
            assert.equals(1, observed.registers_before_ack)
            assert.is_true(observed.complete, vim.inspect(observed))
            assert.equals(registrations[file].ID, observed.state.context.DocumentID)
            assert.equals(registrations[file].ID, observed.identity.ID)
            assert.equals(target, observed.identity.File)
            assert.is_not.equals(first.state.context.AttachID, observed.state.context.AttachID)
            assert.equals(2, observed.counts.registers)
            assert.is_true(observed.modifiable)
            assert.is_nil(uv.fs_lstat(first.state.context.Socket))
        end)
    end

    it('resumes only the proven old identity after a no-effect native move abort', function()
        local file = document('abort.md', { '---', 'type: session-sync', 'owner: ops:0', '---', '# Original' })
        open(file, true)
        local first = observe()
        assert.is_true(first.complete, vim.inspect(first))
        local observed = child:exec([[
            local arrival_ms = ...
            local ss, remote = require('parley.session_sync'), require('parley.remote_session')
            local old = remote.snapshot(endpoint_buf).context
            local token = assert(ss.begin_move(endpoint_buf))
            local paused = remote.snapshot(endpoint_buf) == nil
            assert(ss.abort_move(endpoint_buf, token))
            local complete = vim.wait(arrival_ms, function()
                local state = remote.snapshot(endpoint_buf)
                return state and state.phase == 'active'
            end, 10)
            return { complete = complete, paused = paused, state = remote.snapshot(endpoint_buf), counts = endpoint_probe }
        ]], arrival.MS)
        assert.is_true(observed.paused)
        assert.is_true(observed.complete, vim.inspect(observed))
        assert.equals(file, observed.state.context.File)
        assert.equals(first.state.context.DocumentID, observed.state.context.DocumentID)
        assert.is_not.equals(first.state.context.AttachID, observed.state.context.AttachID)
        assert.equals(2, observed.counts.registers)
    end)

    it('keeps an interrupted real move unadvertised while its registry rename is unavailable', function()
        local source, destination = root .. '/source', root .. '/destination'
        vim.fn.mkdir(destination, 'p')
        local file = document('source/interrupted.md', { '---', 'owner: business-team', '---', '# Original', 'original' })
        local target = destination .. '/interrupted.md'
        open(file, true, { chat_dirs = { source, destination } })
        local first = observe()
        assert.is_true(first.complete, vim.inspect(first))
        local observed = child:exec([[
            local file, target, arrival_ms = ...
            vim.env.FAKE_COUCH_REGISTRY_MODE = 'unsupported'
            local handled, moved, err = require('parley.agentic_document').move_path(file, target)
            assert(handled and moved == target, tostring(err))
            local complete = vim.wait(arrival_ms, function()
                return vim.fn.glob(require('parley').config.state_dir .. '/document-moves/*/*.json') ~= ''
                    and endpoint_probe.rename_completions >= 1
            end, 10)
            local remote = require('parley.remote_session')
            for _ = 1, 4 do require('parley').setup_markdown_keymaps(endpoint_buf) end
            assert(require('parley.session_sync').begin_move(endpoint_buf) == nil, 'interrupted move must remain suspended')
            return { complete = complete, state = remote.snapshot(endpoint_buf), counts = endpoint_probe,
                name = vim.api.nvim_buf_get_name(endpoint_buf), modifiable = vim.bo[endpoint_buf].modifiable,
                journal = vim.fn.glob(require('parley').config.state_dir .. '/document-moves/*/*.json') }
        ]], file, target, arrival.MS)
        assert.is_true(observed.complete, vim.inspect(observed))
        assert.is_nil(observed.state)
        assert.equals(1, observed.counts.registers)
        assert.equals(target, observed.name)
        assert.is_true(observed.modifiable)
        assert.is_not.equals('', observed.journal)
        assert.is_nil(uv.fs_lstat(first.state.context.Socket))
    end)

    for _, count in ipairs({ 8, 16 }) do
        it('does exactly ' .. count .. ' outside lookup/register operations despite duplicate enters and managed reloads', function()
            local files = {}
            for index = 1, count do files[index] = document('counted-' .. index .. '.md') end
            open(files[1])
            local observed = child:exec([[
                local files, arrival_ms = ...
                vim.o.hidden = true
                local buffers, ids = { endpoint_buf }, {}
                for index = 2, #files do
                    vim.cmd('edit ' .. vim.fn.fnameescape(files[index]))
                    local buf = vim.api.nvim_get_current_buf()
                    buffers[#buffers + 1] = buf
                    require('parley').setup_markdown_keymaps(buf)
                end
                local remote = require('parley.remote_session')
                local complete = vim.wait(arrival_ms, function()
                    for _, buf in ipairs(buffers) do
                        local state = remote.snapshot(buf)
                        if not state or state.phase ~= 'active' then return false end
                    end
                    return true
                end, 10)
                assert(complete, 'counted attachments did not become active')
                for _, buf in ipairs(buffers) do ids[buf] = remote.snapshot(buf).context.AttachID end
                for _, buf in ipairs(buffers) do
                    vim.api.nvim_set_current_buf(buf)
                    for _ = 1, 4 do require('parley').setup_markdown_keymaps(buf) end
                    require('parley.session_sync').with_buffer_read(buf, function() vim.cmd('edit!') end)
                    assert(remote.snapshot(buf).context.AttachID == ids[buf], 'managed reload rotated AttachID')
                end
                return { counts = endpoint_probe, buffers = #buffers }
            ]], files, arrival.MS)
            assert.equals(count, observed.buffers)
            assert.equals(count, observed.counts.lookups)
            assert.equals(count, observed.counts.registers)
            local launches = vim.fn.readfile(root .. '/registry.json.editor-launches')
            local registers = 0
            for _, operation in ipairs(launches) do if operation == 'register' then registers = registers + 1 end end
            assert.equals(count, registers)
        end)
    end

end)
