local loaded, Model = pcall(require, 'parley.remote_session_model')
if not loaded then
    Model = {
        next_attach_id = function() return nil end,
        classify_reply = function() return {} end,
        prepare_request = function() return nil end,
        new = function() assert.is_true(loaded, 'attachment model must be implemented') end,
    }
end

local function context()
    return { Namespace = '/repo/.couch', DocumentID = string.rep('a', 32),
        EditorIncarnation = string.rep('b', 32), AttachID = '9007199254740993',
        PID = 42, Socket = '/tmp/editor.sock', Buffer = 7, Mode = 'desktop', File = '/repo/doc.md' }
end
local function binding()
    local value = context()
    value.ProcessIdentity = 'native-start:42'
    value.BindingGeneration = string.rep('c', 32)
    return value
end
local function envelope()
    return { Version = 1, Code = 'ok', Error = '', Changed = true, EditorEndpoint = binding() }
end
local function confirmed(value)
    local response = envelope()
    response.EditorEndpoint = value or binding()
    return Model.classify_reply('register', 0, response, context(), vim.NIL)
end
local function notice(generation)
    local value = context()
    return { Namespace = value.Namespace, DocumentID = value.DocumentID, EditorIncarnation = value.EditorIncarnation,
        AttachID = value.AttachID, BindingGeneration = generation or binding().BindingGeneration }
end
local function publish(model)
    return model:dispatch({ type = 'publish' })[1]
end
local function reply(model, effect, result)
    return model:dispatch({ type = 'reply', witness = effect.witness, result = result or confirmed() })
end
local function query()
    local value = context()
    return { Namespace = value.Namespace, DocumentID = value.DocumentID, EditorIncarnation = value.EditorIncarnation,
        AttachID = value.AttachID, Buffer = value.Buffer }
end

describe('remote attachment counter', function()
    for _, case in ipairs({ { false, '1' }, { '9', '10' }, { '999', '1000' },
        { '9007199254740992', '9007199254740993' }, { '18446744073709551614', '18446744073709551615' } }) do
        it('increments exactly ' .. tostring(case[1]), function()
            assert.equals(case[2], Model.next_attach_id(case[1] or nil))
        end)
    end
    it('refuses invalid and exhausted counters', function()
        for _, value in ipairs({ '0', '01', '-1', '1.0', '', '18446744073709551615', '18446744073709551616', 1 }) do
            local next_id, err = Model.next_attach_id(value)
            assert.is_nil(next_id)
            assert.is_string(err)
        end
    end)
end)

local function register_request()
    local value = context()
    value.File, value.Version = nil, 1
    return value
end
local function unregister_request()
    local value = binding()
    return { Version = 1, Namespace = value.Namespace, EditorIncarnation = value.EditorIncarnation,
        PID = value.PID, Entries = { { DocumentID = value.DocumentID, AttachID = value.AttachID,
            BindingGeneration = value.BindingGeneration } } }
end
local function refused_request(operation, payload)
    local request, err = Model.prepare_request(operation, payload)
    assert.is_nil(request)
    assert.is_string(err)
end

describe('remote producer outbound requests', function()
    it('encodes the exact register contract and copies its expected tuple', function()
        local payload = register_request()
        local request = Model.prepare_request('register', payload)
        assert.is_table(request)
        assert.same({ '--editor-endpoint', 'register', '--json' }, request.args)
        assert.same(payload, vim.json.decode(request.stdin))
        assert.same(payload, request.expected)
        payload.Socket = '/changed.sock'
        assert.equals(context().Socket, request.expected.Socket)
        assert.equals(context().Socket, vim.json.decode(request.stdin).Socket)
    end)
    it('uses only namespace and document ID arguments for lookup with no stdin', function()
        local payload = { Namespace = context().Namespace, DocumentID = context().DocumentID }
        local request = Model.prepare_request('lookup', payload)
        assert.is_table(request)
        assert.same({ '--editor-endpoint', 'lookup', '--namespace', payload.Namespace,
            '--document-id', payload.DocumentID, '--json' }, request.args)
        assert.is_nil(request.stdin)
        payload.DocumentID = string.rep('d', 32)
        assert.equals(context().DocumentID, request.expected.DocumentID)
        payload = { Namespace = context().Namespace, DocumentID = context().DocumentID, Version = 1 }
        refused_request('lookup', payload)
    end)
    it('encodes unregister batches with an optional producer process identity and private entries', function()
        local payload = unregister_request()
        payload.ProcessIdentity = 'opaque-native-identity'
        local request = Model.prepare_request('unregister', payload)
        assert.is_table(request)
        assert.same({ '--editor-endpoint', 'unregister', '--json' }, request.args)
        assert.same(payload, vim.json.decode(request.stdin))
        assert.same(payload, request.expected)
        payload.Entries[1].AttachID = '1'
        assert.equals(context().AttachID, request.expected.Entries[1].AttachID)
        assert.is_table(Model.prepare_request('unregister', unregister_request()))
    end)
    it('requires exactly the known outbound fields before encoding', function()
        for operation, factory in pairs({ register = register_request, unregister = unregister_request,
            lookup = function() return { Namespace = context().Namespace, DocumentID = context().DocumentID } end }) do
            local valid = factory()
            for key in pairs(valid) do
                local payload = factory()
                payload[key] = nil
                refused_request(operation, payload)
            end
            local payload = factory()
            payload.Future = true
            refused_request(operation, payload)
            refused_request(operation, false)
            refused_request(operation, {})
            refused_request(operation, { factory() })
        end
        refused_request('future', register_request())
        local payload = register_request()
        payload.ProcessIdentity = 'not-a-register-field'
        refused_request('register', payload)
    end)
    it('rejects invalid versions, IDs, positive integers, modes and decimal uint64 counters', function()
        for field, values in pairs({ Version = { 0, 2, '1', true }, DocumentID = { 'A', string.rep('A', 32) },
            EditorIncarnation = { '', string.rep('g', 32) }, PID = { 0, -1, 1.5, math.huge, '42' },
            Buffer = { 0, -1, 1.5, math.huge, '7' }, Mode = { 'web', false },
            AttachID = { '0', '01', '-1', '1.0', '18446744073709551616', 1 } }) do
            for _, invalid in ipairs(values) do
                local payload = register_request()
                payload[field] = invalid
                refused_request('register', payload)
            end
        end
        for _, id in ipairs({ '1', '9007199254740993', '18446744073709551615' }) do
            local payload = register_request()
            payload.AttachID = id
            assert.is_table(Model.prepare_request('register', payload))
        end
        local payload = register_request()
        payload.Mode = 'headless'
        assert.is_table(Model.prepare_request('register', payload))
    end)
    it('rejects lexical path aliases and control characters without filesystem IO', function()
        for _, path in ipairs({ 'relative', '/repo/', '/repo//file', '/repo/./file', '/repo/../file',
            '/repo/.', '/repo/..', '/repo\nfile', '/repo\rfile', '/repo\0file' }) do
            for _, field in ipairs({ 'Namespace', 'Socket' }) do
                local payload = register_request()
                payload[field] = path
                refused_request('register', payload)
            end
            refused_request('lookup', { Namespace = path, DocumentID = context().DocumentID })
        end
    end)
    it('refuses duplicate document IDs, malformed entries and sparse or oversized batches', function()
        local payload = unregister_request()
        payload.Entries[2] = vim.deepcopy(payload.Entries[1])
        payload.Entries[2].AttachID = '2'
        refused_request('unregister', payload)
        for _, entries in ipairs({ {}, { [2] = unregister_request().Entries[1] },
            { unregister_request().Entries[1], extra = true }, { false } }) do
            payload = unregister_request()
            payload.Entries = entries
            refused_request('unregister', payload)
        end
        for _, field in ipairs({ 'DocumentID', 'AttachID', 'BindingGeneration' }) do
            payload = unregister_request()
            payload.Entries[1][field] = nil
            refused_request('unregister', payload)
            payload.Entries[1][field] = false
            refused_request('unregister', payload)
        end
        payload = unregister_request()
        payload.Entries[1].Future = true
        refused_request('unregister', payload)
        payload = unregister_request()
        for index = 1, 256 do
            payload.Entries[index] = { DocumentID = string.format('%032x', index), AttachID = '1',
                BindingGeneration = binding().BindingGeneration }
        end
        assert.is_table(Model.prepare_request('unregister', payload))
        payload.Entries[257] = { DocumentID = string.format('%032x', 257), AttachID = '1',
            BindingGeneration = binding().BindingGeneration }
        refused_request('unregister', payload)
        for _, invalid in ipairs({ false, '', 'bad\0identity' }) do
            payload = unregister_request()
            payload.ProcessIdentity = invalid
            refused_request('unregister', payload)
        end
    end)
    it('bounds actual encoded register and unregister bytes at their inclusive limits', function()
        for _, case in ipairs({ { 'register', register_request, 8192, 'Socket', '/' },
            { 'unregister', unregister_request, 262144, 'ProcessIdentity', 'x' } }) do
            local operation, factory, limit, field, prefix = unpack(case)
            local payload = factory()
            payload[field] = prefix
            payload[field] = prefix .. string.rep('x', limit - #vim.json.encode(payload))
            local request = Model.prepare_request(operation, payload)
            assert.is_table(request)
            assert.equals(limit, #request.stdin)
            payload[field] = payload[field] .. 'x'
            refused_request(operation, payload)
        end
    end)
end)

describe('remote producer replies', function()
    it('requires a complete matching binding and copies harmless future fields', function()
        local response = envelope()
        response.EditorEndpoint.Future = { 'safe' }
        local result = Model.classify_reply('register', 0, response, context(), vim.NIL)
        assert.equals('confirmed', result.kind)
        response.EditorEndpoint.Future[1] = 'mutated'
        assert.same({ 'safe' }, result.binding.Future)
    end)
    it('validates every known binding field', function()
        local bad = { Namespace = 'relative', DocumentID = 'A', EditorIncarnation = false, AttachID = '01',
            PID = 1.2, ProcessIdentity = '', Socket = 'relative', Buffer = 0, Mode = 'web',
            BindingGeneration = 'x', File = 'relative' }
        for field, value in pairs(bad) do
            local response = envelope()
            response.EditorEndpoint[field] = value
            assert.equals('unavailable', Model.classify_reply('register', 0, response, context(), vim.NIL).kind, field)
            response.EditorEndpoint[field] = nil
            assert.equals('unavailable', Model.classify_reply('register', 0, response, context(), vim.NIL).kind, field)
        end
    end)
    it('rejects valid but mismatching expected tuple values', function()
        for field, value in pairs(binding()) do
            local expected = { [field] = type(value) == 'number' and value + 1 or value .. 'x' }
            assert.equals('unavailable', Model.classify_reply('register', 0, envelope(), expected, vim.NIL).kind, field)
        end
    end)
    it('rejects unsafe success envelopes', function()
        for _, field in ipairs({ 'Version', 'Code', 'Error', 'Changed', 'EditorEndpoint' }) do
            local response = envelope()
            response[field] = nil
            assert.equals('unavailable', Model.classify_reply('register', 0, response, context(), vim.NIL).kind, field)
        end
        for _, value in ipairs({ false, '', {}, { Version = 2, Code = 'ok', Error = '' } }) do
            assert.equals('unavailable', Model.classify_reply('register', 0, value, context(), vim.NIL).kind)
        end
    end)
    it('only explicit success null proves lookup absence', function()
        local response = { Version = 1, Code = 'ok', Error = '', EditorEndpoint = vim.NIL }
        assert.equals('absent', Model.classify_reply('lookup', 0, response, {}, vim.NIL).kind)
        response.EditorEndpoint = nil
        assert.equals('unavailable', Model.classify_reply('lookup', 0, response, {}, vim.NIL).kind)
        assert.equals('unavailable', Model.classify_reply('lookup', 3, response, {}, vim.NIL).kind)
        response.EditorEndpoint = binding()
        assert.equals('confirmed', Model.classify_reply('lookup', 0, response, context(), vim.NIL).kind)
    end)
    it('requires recognized matching exit and response codes', function()
        for _, case in ipairs({ { 2, 'invalid', 'refused' }, { 3, 'unavailable', 'unavailable' },
            { 4, 'superseded', 'refused' }, { 4, 'conflict', 'refused' }, { 4, 'stale', 'refused' },
            { 4, 'not-registered', 'refused' }, { 4, 'desktop-active', 'refused' },
            { 5, 'uncertain', 'uncertain' }, { 9, 'ok', 'unavailable' }, { 0, 'uncertain', 'unavailable' } }) do
            local response = { Version = 1, Code = case[2], Error = 'reason' }
            assert.equals(case[3], Model.classify_reply('register', case[1], response, context(), vim.NIL).kind)
        end
    end)
    it('confirms unregister only with exactly one matching outcome per requested entry', function()
        local entry = { DocumentID = binding().DocumentID, AttachID = binding().AttachID, BindingGeneration = binding().BindingGeneration }
        local expected = { Entries = { entry } }
        for _, status in ipairs({ 'removed', 'stale', 'absent' }) do
            local row = vim.deepcopy(entry)
            row.Status = status
            local response = { Version = 1, Code = 'ok', Error = '', Results = { row } }
            assert.equals('confirmed', Model.classify_reply('unregister', 0, response, expected, vim.NIL).kind)
            response.Results = { row, row }
            assert.equals('unavailable', Model.classify_reply('unregister', 0, response, expected, vim.NIL).kind)
            response.Results = {}
            assert.equals('unavailable', Model.classify_reply('unregister', 0, response, expected, vim.NIL).kind)
            response.Results = { row }
            row.AttachID = '1'
            assert.equals('unavailable', Model.classify_reply('unregister', 0, response, expected, vim.NIL).kind)
        end
    end)
end)

describe('remote attachment lifecycle', function()
    it('publishes once with a private copied tuple and serves exact handshake', function()
        local original = context()
        local model = Model.new(original)
        original.File = '/changed'
        assert.equals('listening', model:snapshot().phase)
        assert.equals('/repo/doc.md', model:endpoint(query()).File)
        local effect = publish(model)
        assert.equals('register', effect.kind)
        assert.equals(1, effect.request.Version)
        assert.is_nil(effect.request.File)
        assert.same({}, model:dispatch({ type = 'publish' }))
        effect.request.AttachID = '1'
        reply(model, effect)
        assert.equals('active', model:snapshot().phase)
        assert.equals(context().AttachID, model:snapshot().binding.AttachID)
        local state = model:snapshot()
        state.binding.File = '/bad'
        assert.equals('/repo/doc.md', model:snapshot().binding.File)
    end)
    it('refuses any extra or wrong handshake fields', function()
        local model = Model.new(context())
        local wrong = query()
        wrong.extra = true
        assert.is_nil(model:endpoint(wrong))
        for key in pairs(query()) do
            wrong = query()
            wrong[key] = nil
            assert.is_nil(model:endpoint(wrong))
        end
    end)
    it('retries uncertain publication with the same tuple and a new witness', function()
        local model = Model.new(context())
        local first = publish(model)
        reply(model, first, { kind = 'uncertain', code = 'uncertain' })
        assert.equals('unconfirmed', model:snapshot().phase)
        assert.is_table(model:endpoint(query()))
        local second = model:dispatch({ type = 'retry' })[1]
        assert.same(first.request, second.request)
        assert.is_not.equals(first.witness, second.witness)
        reply(model, first)
        assert.equals('publishing', model:snapshot().phase)
        reply(model, second)
        assert.equals('active', model:snapshot().phase)
    end)
    it('keeps unsafe acknowledgments unconfirmed without automatic calls', function()
        for _, result in ipairs({ { kind = 'unavailable' }, { kind = 'uncertain' },
            { kind = 'refused', code = 'invalid' }, { kind = 'refused', code = 'superseded' } }) do
            local model = Model.new(context())
            local effects = reply(model, publish(model), result)
            assert.is_not.equals('active', model:snapshot().phase)
            for _, effect in ipairs(effects) do assert.is_not.equals('register', effect.kind) end
        end
    end)
    it('only accepts exact generation supersession and deduplicates stop and notice', function()
        local model = Model.new(context())
        reply(model, publish(model))
        assert.same({}, model:dispatch({ type = 'superseded', notice = notice(string.rep('d', 32)) }))
        local effects = model:dispatch({ type = 'superseded', notice = notice() })
        assert.equals('superseded', model:snapshot().phase)
        assert.equals('stop_listener', effects[1].kind)
        assert.equals('notify', effects[2].kind)
        assert.is_nil(model:endpoint(query()))
        assert.same({}, model:dispatch({ type = 'superseded', notice = notice() }))
    end)
    it('defers notice-before-ack and compares its generation before activation', function()
        for _, matching in ipairs({ true, false }) do
            local model = Model.new(context())
            local effect = publish(model)
            assert.same({}, model:dispatch({ type = 'superseded', notice = notice(matching and binding().BindingGeneration or string.rep('d', 32)) }))
            assert.equals('publishing', model:snapshot().phase)
            reply(model, effect)
            assert.equals(matching and 'superseded' or 'active', model:snapshot().phase)
        end
    end)
    it('ignores malformed and other-attachment notices', function()
        local model = Model.new(context())
        local effect = publish(model)
        for _, value in ipairs({ {}, { Namespace = '/other' }, notice() }) do
            value.AttachID = '1'
            assert.same({}, model:dispatch({ type = 'superseded', notice = value }))
        end
        reply(model, effect)
        assert.equals('active', model:snapshot().phase)
    end)
    it('retires immediately and cleans only exact owned late binding once', function()
        local model = Model.new(context())
        local effect = publish(model)
        local effects = model:dispatch({ type = 'detach' })
        assert.equals('stop_listener', effects[1].kind)
        assert.equals(1, #effects)
        assert.is_nil(model:endpoint(query()))
        effects = reply(model, effect)
        assert.equals('retired', model:snapshot().phase)
        assert.equals('unregister', effects[1].kind)
        assert.equals(binding().BindingGeneration, effects[1].request.Entries[1].BindingGeneration)
        assert.same({}, reply(model, effect))
        assert.same({}, model:dispatch({ type = 'close' }))
    end)
    it('never activates mismatching or fabricated confirmed completion evidence', function()
        for _, bad in ipairs({ {}, { AttachID = '1' }, binding() }) do
            bad.File = '/different.md'
            local model = Model.new(context())
            local effect = publish(model)
            reply(model, effect, { kind = 'confirmed', binding = bad })
            assert.equals('unconfirmed', model:snapshot().phase)
            assert.same({ { kind = 'stop_listener' } }, model:dispatch({ type = 'detach' }))
        end
    end)
    it('normalizes a producer confirmation of a different canonical file to uncertain ownership', function()
        local response = envelope()
        response.EditorEndpoint.File = '/repo/renamed.md'
        -- File is resolved by the producer, so it is absent from the outbound
        -- register request and can pass transport validation without matching
        -- the buffer's pending canonical file. The owner must decide this.
        local transport = Model.classify_reply('register', 0, response, register_request(), vim.NIL)
        assert.equals('confirmed', transport.kind)
        local model = Model.new(context())
        assert.same({}, reply(model, publish(model), transport))
        local state = model:snapshot()
        assert.equals('unconfirmed', state.phase)
        assert.equals('uncertain', state.result.kind)
        assert.equals('uncertain', state.result.code)
        assert.is_string(state.result.error)
        assert.matches('binding', state.result.error)
        assert.is_nil(state.result.binding)
        assert.is_nil(state.binding)
        assert.equals('confirmed', transport.kind)
        assert.same({ { kind = 'stop_listener' } }, model:dispatch({ type = 'detach' }))
    end)

    for _, mismatch in ipairs({
        { 'Namespace', '/other' }, { 'DocumentID', string.rep('d', 32) },
        { 'EditorIncarnation', string.rep('e', 32) }, { 'AttachID', '1' },
        { 'PID', 43 }, { 'Socket', '/tmp/other.sock' }, { 'Buffer', 8 }, { 'Mode', 'headless' },
    }) do
        it('stores uncertain rather than confirmed for a mismatching ' .. mismatch[1], function()
            local other = binding()
            other[mismatch[1]] = mismatch[2]
            local model = Model.new(context())
            local result = { kind = 'confirmed', code = 'ok', binding = other }
            assert.same({}, reply(model, publish(model), result))
            local accepted = model:snapshot()
            assert.equals('unconfirmed', accepted.phase)
            assert.equals('uncertain', accepted.result.kind)
            assert.is_string(accepted.result.error)
            assert.is_true(#accepted.result.error > 0)
            assert.is_nil(accepted.result.binding)
            assert.is_nil(accepted.binding)
            assert.same({ { kind = 'stop_listener' } }, model:dispatch({ type = 'detach' }))
        end)
    end

    it('never exposes malformed confirmed bindings or unregisters them after retirement', function()
        local malformed = { {}, { BindingGeneration = string.rep('c', 32) } }
        for _, field in ipairs({ 'Namespace', 'DocumentID', 'EditorIncarnation', 'AttachID', 'PID',
            'ProcessIdentity', 'Socket', 'Buffer', 'Mode', 'BindingGeneration', 'File' }) do
            local value = binding(); value[field] = nil
            malformed[#malformed + 1] = value
        end
        for _, bad in ipairs(malformed) do
            for _, retired in ipairs({ false, true }) do
                local model = Model.new(context())
                local effect = publish(model)
                if retired then model:dispatch({ type = 'detach' }) end
                assert.same({}, reply(model, effect, { kind = 'confirmed', binding = bad }))
                local state = model:snapshot()
                assert.equals(retired and 'retired' or 'unconfirmed', state.phase)
                assert.equals('uncertain', state.result.kind)
                assert.is_nil(state.result.binding)
                assert.is_nil(state.binding)
                assert.same({}, reply(model, effect, confirmed()))
            end
        end
    end)

    it('keeps rejected late canonical-file proof uncertain and leaves every foreign generation untouched', function()
        local other = binding(); other.File = '/repo/successor.md'
        local model = Model.new(context())
        local effect = publish(model)
        model:dispatch({ type = 'detach' })
        assert.same({}, reply(model, effect, { kind = 'confirmed', binding = other }))
        local state = model:snapshot()
        assert.equals('retired', state.phase)
        assert.equals('uncertain', state.result.kind)
        assert.is_nil(state.result.binding)
        assert.same({}, model:dispatch({ type = 'close' }))
    end)

    it('accepts an exact retry after rejected proof and preserves copied exact cleanup evidence', function()
        local model = Model.new(context())
        local other = binding(); other.File = '/repo/other.md'
        reply(model, publish(model), { kind = 'confirmed', binding = other })
        assert.equals('uncertain', model:snapshot().result.kind)
        local retry = model:dispatch({ type = 'retry' })[1]
        assert.equals(context().AttachID, retry.request.AttachID)
        local proof = confirmed()
        reply(model, retry, proof)
        local state = model:snapshot()
        assert.equals('active', state.phase)
        assert.equals('confirmed', state.result.kind)
        assert.same(binding(), state.result.binding)
        state.result.binding.File = '/mutated-snapshot'
        proof.binding.BindingGeneration = string.rep('f', 32)
        local effects = model:dispatch({ type = 'detach' })
        assert.equals('unregister', effects[2].kind)
        assert.equals(binding().BindingGeneration, effects[2].request.Entries[1].BindingGeneration)
    end)

    it('ignores unissued witnesses even after retirement', function()
        local model = Model.new(context())
        publish(model)
        model:dispatch({ type = 'detach' })
        assert.same({}, reply(model, { witness = 999 }, confirmed()))
        assert.equals('retired', model:snapshot().phase)
    end)
    it('keeps the same attachment through reply and snapshot mutation', function()
        local model = Model.new(context())
        local result = confirmed()
        reply(model, publish(model), result)
        result.binding.BindingGeneration = string.rep('d', 32)
        local effects = model:dispatch({ type = 'detach' })
        assert.equals(binding().BindingGeneration, effects[2].request.Entries[1].BindingGeneration)
        effects[2].request.Entries[1].AttachID = '1'
        assert.equals(context().AttachID, model:snapshot().binding.AttachID)
        assert.same({}, model:dispatch({ type = 'detach' }))
    end)
    it('allows exact stale-witness cleanup only after retirement', function()
        local model = Model.new(context())
        local first = publish(model)
        reply(model, first, { kind = 'uncertain' })
        local second = model:dispatch({ type = 'retry' })[1]
        model:dispatch({ type = 'detach' })
        local cleanup = reply(model, second)
        assert.equals('unregister', cleanup[1].kind)
        assert.same({}, reply(model, first))
        assert.equals('retired', model:snapshot().phase)
    end)
    it('cannot erase a successor through cleanup after takeover', function()
        local model = Model.new(context())
        reply(model, publish(model))
        model:dispatch({ type = 'superseded', notice = notice() })
        local effects = model:dispatch({ type = 'close' })
        assert.equals('unregister', effects[1].kind)
        assert.equals(context().AttachID, effects[1].request.Entries[1].AttachID)
        assert.equals(binding().BindingGeneration, effects[1].request.Entries[1].BindingGeneration)
    end)
end)
