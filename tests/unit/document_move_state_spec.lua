local model
local function intent()
    return { op_id = 'operation-7', id = 'document-7', new = '/repo/new.md', generation = 1, document_generation = 1,
        orphan = { before = { inode = 10 }, after = { inode = 10, at = 'suffix' } },
        document = { before = { inode = 20 }, after = { inode = 20, at = 'new' } },
        side = { before = { inode = 30 }, after = { inode = 30, at = 'new-side' } },
        parent = { before = 'old-hash', after = 'rewritten-hash' },
        children = { { id = 'a', before = 'a-old', after = 'a-new' },
            { id = 'b', before = 'b-old', after = 'b-new' } } }
end
local function event(state, kind, fields)
    local result = { kind = kind, op_id = state.op_id, generation = state.generation }
    for key, value in pairs(fields or {}) do result[key] = value end
    return result
end
local function observed(state, proof, child)
    local pair = child or state[state.phase]
    local witness = false
    if pair ~= false then witness = pair[proof] end
    return event(state, 'observed', { phase = state.phase, proof = proof,
        witness = witness, child_id = child and child.id })
end
local function through(state, target)
    for _ = 1, 20 do
        if state.phase == target then return state end
        local e
        if state.phase == 'prepared' then e = event(state, 'journal_saved')
        elseif state.phase == 'children' then
            local next_child
            for _, child in ipairs(state.children) do
                local done = false
                for _, id in ipairs(state.completed) do if id == child.id then done = true end end
                if not done then next_child = child; break end
            end
            e = next_child and observed(state, 'after', next_child)
                or event(state, 'observed', { phase = 'children', proof = 'after', witness = false })
        elseif state.phase == 'editor' then e = event(state, 'editor_synced', { document_generation = state.document_generation })
        elseif state.phase == 'metadata' then
            e = event(state, 'metadata_reply', { ok = true, id = state.id, new = state.new })
        elseif state.phase == 'complete' then e = event(state, 'cleanup_done')
        else e = observed(state, 'after') end
        state = assert(model.step(state, e))
    end
    error('target phase not reached: ' .. target)
end

describe('pure document move state', function()
    before_each(function()
        local ok, module = pcall(require, 'parley.document_move_state')
        assert.is_true(ok, tostring(module)); model = module
    end)
    it('copies intent and round-trips a strict JSON record without IO', function()
        local input = intent()
        local state = assert(model.initial(input))
        assert.equals(2, state.version); assert.equals('prepared', state.phase)
        input.document.after.inode = 999
        assert.equals(20, state.document.after.inode)
        local encoded = vim.json.encode(state)
        local restored = assert(model.restore(vim.json.decode(encoded)))
        assert.same(state, restored)
        restored.document.after.inode = 777
        assert.equals(20, state.document.after.inode)
    end)
    it('requires durable admission and exact witnesses before each destructive effect', function()
        local state = assert(model.initial(intent()))
        local next_state, result = model.step(state, observed({ phase = 'orphan', orphan = state.orphan,
            op_id = state.op_id, generation = state.generation }, 'before'))
        assert.same(state, next_state); assert.equals('ignored', result.kind)
        state = assert(model.step(state, event(state, 'journal_saved')))
        for _, phase in ipairs({ 'orphan', 'document', 'side' }) do
            assert.equals(phase, state.phase)
            local before = vim.deepcopy(state)
            local unchanged, effect = model.step(state, observed(state, 'before'))
            assert.same(before, unchanged); assert.same(before, state)
            assert.equals('effect', effect.kind); assert.equals(phase, effect.phase)
            local invalid = observed(state, 'after'); invalid.witness = 'unrelated'
            local refused, pending = model.step(state, invalid)
            assert.same(state, refused); assert.equals('pending', pending.kind)
            state = assert(model.step(state, observed(state, 'after')))
        end
    end)
    it('bounds child completion by unique declared identities and requires every child before parent', function()
        local state = through(assert(model.initial(intent())), 'children')
        local unchanged, outcome = model.step(state, observed(state, 'after', { id = 'forged', after = 'a-new' }))
        assert.same(state, unchanged); assert.equals('pending', outcome.kind)
        state = assert(model.step(state, observed(state, 'after', state.children[2])))
        assert.equals('children', state.phase); assert.same({ 'b' }, state.completed)
        local again = assert(model.step(state, observed(state, 'after', state.children[2])))
        assert.same(state, again)
        local child_before = observed(state, 'before', state.children[1])
        local same, effect = model.step(state, child_before)
        assert.same(state, same); assert.equals('a', effect.child_id)
        state = assert(model.step(state, observed(state, 'after', state.children[1])))
        assert.equals('parent', state.phase); assert.equals(2, #state.completed)
    end)
    it('handles absent stages and empty children only through explicit after proofs', function()
        local input = intent(); input.orphan = false; input.side = false; input.parent = false; input.children = {}
        local state = through(assert(model.initial(input)), 'editor')
        assert.equals('editor', state.phase)
        assert.same({}, state.completed)
    end)
    it('retains unknown and failed publication for recovery without advancing', function()
        local state = through(assert(model.initial(intent())), 'parent')
        for _, e in ipairs({ event(state, 'observed', { phase = 'parent', proof = 'unknown', witness = false }),
            event(state, 'effect_failed', { phase = 'parent', reason = 'CAS failed' }) }) do
            local same, outcome = model.step(state, e)
            assert.same(state, same); assert.equals('pending', outcome.kind)
        end
        local restored = assert(model.restore(vim.json.decode(vim.json.encode(state))))
        assert.equals('editor', assert(model.step(restored, observed(restored, 'after'))).phase)
    end)
    it('adopts saves only after editor synchronization and never replays old parent bytes', function()
        local state = through(assert(model.initial(intent())), 'editor')
        local save = event(state, 'saved', { document_generation = 2, witness = 'operator-hash' })
        local same, pending = model.step(state, save)
        assert.same(state, same); assert.equals('pending', pending.kind)
        local wrong_editor = event(state, 'editor_synced', { document_generation = 99 })
        local unchanged = assert(model.step(state, wrong_editor))
        assert.same(state, unchanged)
        state = assert(model.step(state, event(state, 'editor_synced', { document_generation = state.document_generation })))
        local original_reply = event(state, 'metadata_reply', { ok = true, id = state.id, new = state.new })
        state = assert(model.step(state, save))
        assert.equals('metadata', state.phase); assert.equals(1, state.generation)
        assert.equals(2, state.document_generation)
        assert.equals(2, state.editor_generation); assert.equals('operator-hash', state.document_witness)
        local duplicate = assert(model.step(state, save))
        assert.same(state, duplicate)
        local ignored
        unchanged, ignored = model.step(state, event(state, 'observed', {
            phase = 'parent', proof = 'before', witness = state.parent.before }))
        assert.same(state, unchanged); assert.equals('ignored', ignored.kind)
        local current_reply = original_reply
        state = assert(model.step(state, current_reply)); assert.equals('complete', state.phase)
        state = assert(model.step(state, event(state, 'cleanup_done'))); assert.equals('retired', state.phase)
        unchanged, ignored = model.step(state, current_reply)
        assert.same(state, unchanged); assert.equals('ignored', ignored.kind)
    end)
    it('requires the exact metadata identity tuple and retains refused replies', function()
        local state = through(assert(model.initial(intent())), 'metadata')
        for _, fields in ipairs({ { ok = false, id = state.id, new = state.new },
            { ok = true, id = 'other', new = state.new }, { ok = true, id = state.id, new = '/other.md' } }) do
            local same, result = model.step(state, event(state, 'metadata_reply', fields))
            assert.same(state, same); assert.equals('pending', result.kind)
        end
    end)
    it('rejects forged or impossible persisted progress instead of inferring completion', function()
        local good = assert(model.initial(intent()))
        local corruptions = {
            function(s) s.version = 1 end, function(s) s.extra = true end,
            function(s) s.phase = 'mystery' end, function(s) s.phase = 'metadata' end,
            function(s) s.completed = { 'forged' } end, function(s) s.completed = { 'a', 'a' } end,
            function(s) s.completed = { 'a' } end, function(s) s.generation = -1 end,
            function(s) s.document.after = function() end end,
            function(s) s.document.extra = true end, function(s) s.children[2].id = 'a' end,
            function(s) s.children[4] = s.children[1] end,
        }
        for _, corrupt in ipairs(corruptions) do
            local record = vim.deepcopy(good); corrupt(record)
            local result, err = model.restore(record)
            assert.is_nil(result); assert.is_string(err)
        end
        local huge = intent(); huge.children = {}
        for i = 1, 513 do huge.children[i] = { id = tostring(i), before = 'x', after = 'y' } end
        assert.is_nil(model.initial(huge))
        huge.children[513] = nil
        assert.is_not_nil(model.initial(huge))
        local oversized = intent(); oversized.document.after = string.rep('x', 262144)
        assert.is_nil(model.initial(oversized))
        local cyclic = intent(); cyclic.document.after = cyclic
        assert.is_nil(model.initial(cyclic))
    end)
    it('preserves legal ordering under deterministic reordered duplicated and stale events', function()
        local phase_order = { prepared = 1, orphan = 2, document = 3, side = 4, children = 5,
            parent = 6, editor = 7, metadata = 8, complete = 9, retired = 10 }
        for seed = 1, 24 do
            local state = assert(model.initial(intent()))
            local random = seed
            local stale = {}
            for _ = 1, 80 do
                random = (random * 48271) % 2147483647
                local choice = random % 6
                local valid
                if state.phase == 'prepared' then valid = event(state, 'journal_saved')
                elseif state.phase == 'children' then
                    local child = state.children[1]
                    for _, id in ipairs(state.completed) do if id == child.id then child = state.children[2] end end
                    valid = observed(state, 'after', child)
                elseif state.phase == 'editor' then valid = event(state, 'editor_synced', { document_generation = state.document_generation })
                elseif state.phase == 'metadata' then valid = event(state, 'metadata_reply', { ok = true, id = state.id, new = state.new })
                elseif state.phase == 'complete' or state.phase == 'retired' then valid = event(state, 'cleanup_done')
                else valid = observed(state, 'after') end
                local e = vim.deepcopy(valid)
                if choice == 0 then e.op_id = 'other-operation'
                elseif choice == 1 then e.generation = random % 2 == 0 and 0 or state.generation + 20
                elseif choice == 2 and #stale > 0 then e = stale[(random % #stale) + 1]
                elseif choice == 3 then e = event(state, 'effect_failed', { phase = state.phase, reason = 'interruption' }) end
                local before = vim.deepcopy(state)
                local next_state, outcome = model.step(state, e)
                assert.same(before, state)
                assert.same(before.document, next_state.document)
                assert.same(before.parent, next_state.parent)
                assert.is_true(phase_order[next_state.phase] >= phase_order[state.phase])
                assert.is_true(phase_order[next_state.phase] <= phase_order[state.phase] + 1)
                if e.op_id ~= state.op_id or e.generation ~= state.generation or e.kind == 'effect_failed' then
                    assert.same(state, next_state); assert.is_false(outcome.kind == 'effect')
                end
                if phase_order[next_state.phase] >= phase_order.parent then assert.equals(2, #next_state.completed) end
                if phase_order[next_state.phase] >= phase_order.metadata then assert.equals(next_state.document_generation, next_state.editor_generation) end
                assert.is_not_nil(model.restore(vim.json.decode(vim.json.encode(next_state))))
                stale[#stale + 1] = valid; state = next_state
            end
            assert.equals('retired', through(state, 'retired').phase)
        end
    end)
end)
