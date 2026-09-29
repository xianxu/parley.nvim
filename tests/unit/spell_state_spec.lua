local state = require('parley.spell_state')

local function copy(value, overrides)
    local result = {}
    for key, item in pairs(value) do result[key] = item end
    for key, item in pairs(overrides or {}) do result[key] = item end
    return result
end

local target = { buf = 1, win = 2, row = 1, start_col = 4, end_col = 7,
    word = 'teh', tick = 3, col = 5, mode = 'n' }
local function step(current, kind, args)
    return state.transition(current, copy(args or {}, { kind = kind }))
end
local function ready()
    local current = step(state.new(), 'observe', { target = target })
    return step(current, 'timer', { generation = current.generation })
end
local function has(effects, kind)
    for _, effect in ipairs(effects) do if effect.kind == kind then return effect end end
end

describe('spell_state target selection', function()
    it('uses whole byte spans for all interior positions and Insert word ends', function()
        for _, word in ipairs({ 'teh', 'élève', "can’t", "isn't" }) do
            local line = '日 ' .. word .. ' .'
            local span = { start_col = 4, end_col = 4 + #word }
            for col = span.start_col, span.end_col - 1 do
                assert.same({start_col = 4, end_col = span.end_col, word = word},
                    state.target_at(line, col, 'n', { span }))
            end
            assert.is_nil(state.target_at(line, span.end_col, 'n', {span}))
            assert.equals(word, state.target_at(line, span.end_col, 'i', {span}).word)
            assert.is_nil(state.target_at(line, span.end_col + 1, 'i', {span}))
            assert.is_nil(state.target_at(line, 0, 'n', {span}))
            assert.is_nil(state.target_at(line, 4, 'v', {span}))
        end
    end)

    it('rejects oversized and malformed inputs at the pure boundary', function()
        assert.is_nil(state.target_at(string.rep('x', 16385), 0, 'n', {{start_col=0,end_col=3}}))
        assert.is_nil(state.target_at(string.rep('x', 129), 0, 'n', {{start_col=0,end_col=129}}))
        assert.is_nil(state.target_at('teh', 0, 'n', {{start_col=-1,end_col=3}}))
        assert.is_nil(state.target_at('teh', 0, 'n', {{start_col=0,end_col=4}}))
    end)

    it('separates word identity from exact acceptance evidence', function()
        assert.is_true(state.same_target(target, copy(target, {col=6,mode='i',tick=4})))
        assert.is_false(state.same_target(target, copy(target, {word='the'})))
        assert.is_false(state.same_target(nil, nil))
        local evidence = copy(target, {generation=1})
        assert.is_true(state.accepts(evidence, copy(evidence)))
        for _, key in ipairs({'buf','win','row','start_col','end_col','word','tick','col','mode','generation'}) do
            assert.is_false(state.accepts(evidence, copy(evidence, {[key]='changed'})), key)
        end
        assert.is_false(state.accepts(nil, evidence))
    end)
end)

describe('spell_state transitions', function()
    it('admits native requests only after the matching debounce and does not mutate inputs', function()
        local initial = state.new()
        local pending, effects = step(initial, 'observe', {target=target})
        assert.same({phase='idle',generation=0}, initial)
        assert.equals('pending', pending.phase)
        assert.is_not_nil(has(effects, 'schedule'))
        local _, denied = step(pending, 'source_request', {target=target})
        assert.is_nil(has(denied, 'admitted'))
        local stale, stale_effects = step(pending, 'timer', {generation=0})
        assert.same(pending, stale)
        assert.same({}, stale_effects)
        local admitted, show = step(pending, 'timer', {generation=pending.generation})
        assert.is_nil(pending.ticket)
        assert.is_not_nil(has(show, 'show'))
        local _, response = step(admitted, 'source_request', {target=target})
        assert.same(admitted.ticket, has(response, 'admitted').evidence)
        local _, wrong = step(admitted, 'source_request', {target=copy(target,{col=6})})
        assert.is_nil(has(wrong, 'admitted'))
    end)

    it('preserves a ticket across hide-before-execute and consumes it once', function()
        local current = ready()
        local evidence = copy(current.ticket)
        current = step(current, 'shown', {generation=current.generation})
        local hidden, effects = step(current, 'hidden')
        assert.equals('idle', hidden.phase)
        assert.is_not_nil(has(effects, 'release'))
        assert.same(evidence, hidden.ticket)
        local consumed, accepted = step(hidden, 'consume', {evidence=evidence,live=evidence})
        assert.is_not_nil(has(accepted, 'consumed'))
        assert.is_nil(consumed.ticket)
        local _, duplicate = step(consumed, 'consume', {evidence=evidence,live=evidence})
        assert.same({}, duplicate)
        local _, reopen = step(hidden, 'observe', {target=target})
        assert.is_nil(has(reopen, 'schedule'))
    end)

    it('retains dismissal through within-word motion and mode changes, until leave or explicit request', function()
        local current = step(ready(), 'dismiss')
        for col = 4, 6 do
            current = step(current, 'invalidate')
            local effects
            current, effects = step(current, 'observe', {target=copy(target,{col=col,mode='i',tick=9})})
            assert.equals('dismissed', current.phase)
            assert.is_nil(has(effects, 'schedule'))
            local _, response = step(current, 'source_request', {target=target})
            assert.same({}, response)
        end
        local requested, effects = step(current, 'request', {target=target})
        assert.is_not_nil(requested.ticket)
        assert.is_not_nil(has(effects, 'show'))
        current = step(current, 'observe', {})
        current, effects = step(current, 'observe', {target=target})
        assert.is_not_nil(has(effects, 'schedule'))
    end)

    it('rejects stale callbacks across generated invalidation and completion orders', function()
        for seed = 1, 60 do
            local current = ready()
            local old = copy(current.ticket)
            local generation = current.generation
            for _ = 1, (seed % 5) + 1 do current = step(current, 'invalidate') end
            current = step(current, 'observe', {target=target})
            local events = {'timer','shown','source_request','consume'}
            for offset = 1, #events do
                local kind = events[((seed + offset) % #events) + 1]
                local effects
                current, effects = step(current, kind, {generation=generation,target=target,evidence=old,live=old})
                assert.is_nil(has(effects, 'consumed'))
                assert.is_nil(has(effects, 'admitted'))
                assert.is_nil(has(effects, 'lease'))
                assert.is_nil(has(effects, 'show'))
            end
            current = step(current, 'detach')
            assert.equals('detached', current.phase)
            assert.is_nil(current.ticket)
            local _, late = step(current, 'timer', {generation=current.generation})
            assert.same({}, late)
        end
    end)
end)
