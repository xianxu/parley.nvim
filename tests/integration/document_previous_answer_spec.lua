-- #261/#255: the coordinator's prev_answer slot. One case per coordinator-owned
-- row of the ARCH-ORDER table in
-- workshop/plans/000261-transcript-is-the-whole-truth-plan.md: a slot is held
-- while its generation holds a live grant on the exchange, read as absent once
-- revoked or once the exchange's marker is gone, and removed when the
-- generation finishes and on reload or detach.
local D = require('parley.document')
local Fake = require('tests.helpers.fake_document_editor')

local nextbuf = 94000
local VALUE = { answer = { content = 'old one' } }

local function attach(lines)
    nextbuf = nextbuf + 1
    local fake = Fake.new(lines or { '💬: q', '', '🤖: answer', '' })
    local doc = D.attach(nextbuf, { driver = fake.driver, schedule = false })
    assert.equals('idle', D.drain(doc, 1000).status)
    return doc, fake
end
-- A regenerating generation: the 💬: row is the entity; the grant covers the
-- output after it, as response_target admits it.
local function regenerate(doc, question_row, last_byte)
    local marker = D.query(doc, question_row, question_row + 1)[1]
    local g = D.transition(doc, { kind = 'register_generation' }).generation
    local acquired = D.transition(doc, { kind = 'acquire', generation = g, regions = { {
        entity = marker.handle, marker_revision = 1, revision = 1,
        first = marker.end_byte - 1, last = last_byte or (D.size(doc).bytes - 1), confirmed = true } } })
    assert.is_true(acquired.ok, tostring(acquired.reason))
    return g, marker.handle, acquired.grants[1]
end
local function set(doc, g, entity, epoch)
    return D.set_previous_answer(doc, { epoch = epoch or D.snapshot(doc).epoch, entity = entity,
        generation = g, value = VALUE })
end

describe('document prev_answer slot', function()
    it('lists a slot set while its generation holds a live grant', function()
        local doc = attach(); local g, entity = regenerate(doc, 0)
        assert.is_true(set(doc, g, entity))
        assert.same({ { row = 0, generation = g, value = VALUE } }, D.previous_answers(doc))
        D.detach(doc)
    end)

    it('refuses a slot without a grant, or from a stale epoch', function()
        local doc = attach()
        local entity = D.query(doc, 0, 1)[1].handle
        local g = D.transition(doc, { kind = 'register_generation' }).generation
        assert.is_false(set(doc, g, entity))
        local g2, e2 = regenerate(doc, 0)
        assert.is_false(set(doc, g2, e2, 'stale-epoch'))
        assert.same({}, D.previous_answers(doc))
        D.detach(doc)
    end)

    it('reads a revoked slot as absent and removes it', function()
        local doc = attach(); local g, entity, grant = regenerate(doc, 0)
        set(doc, g, entity)
        D.transition(doc, { kind = 'revoke', grant = grant })
        assert.same({}, D.previous_answers(doc))
        assert.equals(0, D._previous_count(doc))
        D.detach(doc)
    end)

    it('removes the slot when its generation finishes', function()
        local doc = attach(); local g, entity = regenerate(doc, 0)
        set(doc, g, entity)
        D.transition(doc, { kind = 'finish_generation', generation = g })
        assert.equals(0, D._previous_count(doc))
    end)

    it('keeps a later generation\'s slot when an earlier revoked one finishes', function()
        local doc = attach(); local g, entity, grant = regenerate(doc, 0)
        set(doc, g, entity)
        D.transition(doc, { kind = 'revoke', grant = grant })
        local g2 = regenerate(doc, 0)
        assert.is_true(set(doc, g2, entity))
        D.transition(doc, { kind = 'finish_generation', generation = g })
        assert.same({ { row = 0, generation = g2, value = VALUE } }, D.previous_answers(doc))
        D.detach(doc)
    end)

    it('reads a slot whose question marker was deleted as absent', function()
        local doc, fake = attach(); local g, entity = regenerate(doc, 0)
        set(doc, g, entity)
        fake:edit(0, 0, 0, 3, { '' })
        D.drain(doc, 1000)
        assert.same({}, D.previous_answers(doc))
        D.detach(doc)
    end)

    it('removes every slot on reload and on detach', function()
        local doc, fake = attach(); local g, entity = regenerate(doc, 0)
        set(doc, g, entity)
        fake:reload({ '💬: q', '', '🤖: answer', '' })
        assert.equals(0, D._previous_count(doc))
        local doc2 = attach(); local g2, e2 = regenerate(doc2, 0)
        set(doc2, g2, e2)
        D.detach(doc2)
        assert.equals(0, D._previous_count(doc2))
        D.detach(doc)
    end)

    it('keeps each exchange\'s slot apart', function()
        local doc = attach({ '💬: one', '', '🤖: a1', '', '💬: two', '', '🤖: a2', '' })
        local q2 = D.query(doc, 4, 5)[1]
        local g1, e1 = regenerate(doc, 0, q2.start_byte - 2)
        local g2, e2 = regenerate(doc, 4)
        local v2 = { answer = { content = 'old two' } }
        set(doc, g1, e1)
        assert.is_true(D.set_previous_answer(doc, { epoch = D.snapshot(doc).epoch, entity = e2, generation = g2, value = v2 }))
        local listed = D.previous_answers(doc)
        table.sort(listed, function(a, b) return a.row < b.row end)
        assert.same({ { row = 0, generation = g1, value = VALUE }, { row = 4, generation = g2, value = v2 } }, listed)
        D.detach(doc)
    end)
end)
