-- Pure v2 migration reducer. The dispatcher alone persists these snapshots.
-- initial accepts op_id/id/new, stable operation generation, document_generation,
-- document/orphan/side/parent {before,after} witness pairs (false = no-op except
-- document), and <=512 children {id,before,after}. Witnesses contain hashes/inode
-- descriptions, never file bytes; the IO boundary validates their meaning.
-- All events carry kind/op_id/generation. observed additionally carries phase,
-- proof ('before'/'after'/'unknown'), exact witness, and child_id for children.
-- editor_synced carries document_generation; saved carries a strictly newer
-- document_generation and witness; metadata_reply carries ok/id/new.
-- journal_saved and effect_failed (phase/reason) complete the move protocol.
-- In complete, finalization_started captures exact protection/hash intent;
-- finalization_authorized and finalization_released prove handoff -> protection
-- -> retire. Only then may cleanup_done retire a protected operation.
-- step returns a detached snapshot plus {kind,phase,...}: advanced, effect,
-- pending, ignored or done. An effect is a request, never proof of publication.
-- In editor/metadata/complete, observed before with the current document witness
-- requests synchronization/registry rename/cleanup respectively. Only their
-- explicit completion event can advance. Recovery must reobserve IO/editor
-- identities before requesting metadata; restoring a checkpoint is not IO proof.
local M = {}
local phases = { prepared = 1, orphan = 2, document = 3, side = 4, children = 5,
    parent = 6, editor = 7, metadata = 8, complete = 9, retired = 10 }
local successors = { prepared = 'orphan', orphan = 'document', document = 'side',
    side = 'children', children = 'parent', parent = 'editor', editor = 'metadata',
    metadata = 'complete', complete = 'retired' }
local fields = { version = true, op_id = true, id = true, new = true, generation = true,
    document_generation = true, orphan = true, document = true, side = true, parent = true,
    children = true, phase = true, completed = true, editor_generation = true, document_witness = true, finalization = true }
local function integer(v) return type(v) == 'number' and v >= 1 and v <= 9007199254740991 and v % 1 == 0 end
local function text(v) return type(v) == 'string' and #v > 0 and #v <= 4096 and not v:find('%z') end
local function dense(t, limit)
    if type(t) ~= 'table' or getmetatable(t) then return false end
    local n = #t
    if n > limit then return false end
    for k in pairs(t) do if type(k) ~= 'number' or k % 1 ~= 0 or k < 1 or k > n then return false end end
    for i = 1, n do if t[i] == nil then return false end end
    return true
end
local function keys(t, allowed)
    if type(t) ~= 'table' or getmetatable(t) then return false end
    for k in pairs(t) do if not allowed[k] then return false end end
    return true
end
-- Bound total JSON size, depth and nodes before copying anything. No vim/IO API.
local function json(value)
    local active, count, size = {}, 0, 0
    local function string_size(v)
        local n = #v + 2
        for byte in v:gmatch('.') do
            local code = byte:byte()
            if code < 32 then n = n + 5
            elseif byte == '\\' or byte == '"' then n = n + 1 end
        end
        return n
    end
    local function walk(v, depth)
        count = count + 1
        if count > 16384 or depth > 12 then return false end
        local kind = type(v)
        if kind == 'string' then size = size + string_size(v)
        elseif kind == 'boolean' then size = size + 5
        elseif kind == 'number' then
            if v ~= v or v == math.huge or v == -math.huge then return false end
            size = size + 32
        elseif kind == 'table' then
            if active[v] or getmetatable(v) then return false end
            active[v] = true
            local array, object = false, false
            size = size + 2
            for k, entry in pairs(v) do
                size = size + 1
                if type(k) == 'number' then array = true
                elseif type(k) == 'string' then object = true; size = size + string_size(k) + 1
                else return false end
                if array and object or not walk(entry, depth + 1) then return false end
            end
            if array and not dense(v, 16384) then return false end
            active[v] = nil
        else return false end
        return size <= 262144
    end
    return walk(value, 0)
end
local function copy(v)
    if type(v) ~= 'table' then return v end
    local result = {}
    for k, item in pairs(v) do result[k] = copy(item) end
    return result
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function pair(p, optional)
    return optional and p == false or keys(p, { before = true, after = true })
        and p.before ~= nil and p.after ~= nil
end
local function finalization(record, document_witness)
    local allowed = { stage = true, old_lock_before = true, new_lock_before = true, new_lock_after = true,
        document_hash = true, editor_hash = true }
    local function lock(value) return value == false or type(value) == 'string' and #value <= 65536 end
    return json(record) and keys(record, allowed)
        and (record.stage == 'handoff' or record.stage == 'protection' or record.stage == 'retire')
        and lock(record.old_lock_before) and lock(record.new_lock_before) and lock(record.new_lock_after)
        and (record.new_lock_after == false or record.new_lock_after == record.new_lock_before)
        and text(record.document_hash) and equal(record.document_hash, document_witness) and text(record.editor_hash)
end
function M.validate_finalization(record, document_witness)
    if not finalization(record, document_witness) then return nil, 'invalid finalization record' end
    return copy(record)
end
function M.finalization_step(record, kind, intent_record, document_witness)
    if kind == 'finalization_started' then
        if record ~= nil and record ~= false then return nil, 'finalization already started' end
        if not finalization(intent_record, document_witness) or intent_record.stage ~= 'handoff' then
            return nil, 'invalid finalization intent'
        end
        return copy(intent_record)
    end
    local expected = kind == 'finalization_authorized' and 'handoff'
        or kind == 'finalization_released' and 'protection'
    if not expected or not finalization(record, document_witness) or record.stage ~= expected then
        return nil, 'finalization step out of order'
    end
    local next_record = copy(record)
    next_record.stage = expected == 'handoff' and 'protection' or 'retire'
    return next_record
end
local function validate(s)
    if not json(s) or not keys(s, fields) or s.version ~= 2 or not phases[s.phase]
        or not text(s.op_id) or not text(s.id) or not text(s.new)
        or not integer(s.generation) or not integer(s.document_generation)
        or not pair(s.document, false) or not pair(s.orphan, true)
        or not pair(s.side, true) or not pair(s.parent, true)
        or not dense(s.children, 512) or not dense(s.completed, 512)
        or s.document_witness == nil then return nil, 'invalid v2 migration record' end
    local children, done = {}, {}
    for _, child in ipairs(s.children) do
        if not keys(child, { id = true, before = true, after = true }) or not text(child.id)
            or child.before == nil or child.after == nil or children[child.id] then
            return nil, 'invalid child witnesses'
        end
        children[child.id] = true
    end
    for _, id in ipairs(s.completed) do
        if not children[id] or done[id] then return nil, 'invalid completed child identity' end
        done[id] = true
    end
    local phase = phases[s.phase]
    if phase < phases.children and #s.completed > 0
        or phase == phases.children and #s.children > 0 and #s.completed == #s.children
        or phase > phases.children and #s.completed ~= #s.children then
        return nil, 'child progress disagrees with phase'
    end
    if phase < phases.metadata then
        if s.editor_generation ~= false then return nil, 'editor acknowledged before synchronization' end
        local expected = s.document.before
        if phase > phases.document then expected = s.document.after end
        if phase > phases.parent and s.parent ~= false then expected = s.parent.after end
        if not equal(s.document_witness, expected) then return nil, 'document witness disagrees with phase' end
    elseif s.editor_generation ~= s.document_generation then
        return nil, 'editor generation disagrees with document generation'
    end
    if s.finalization ~= nil and s.finalization ~= false
        and (phase < phases.complete or not finalization(s.finalization, s.document_witness)) then
        return nil, 'finalization disagrees with completed document generation'
    end
    return true
end
function M.restore(record)
    local valid, err = validate(record)
    if not valid then return nil, err end
    local restored = copy(record)
    if restored.finalization == nil then restored.finalization = false end
    return restored
end
function M.initial(intent)
    local allowed = { op_id = true, id = true, new = true, generation = true, document_generation = true,
        document = true, orphan = true, side = true, parent = true, children = true }
    if not json(intent) or not keys(intent, allowed) then return nil, 'invalid move intent' end
    local state = copy(intent)
    state.version, state.phase, state.completed, state.editor_generation = 2, 'prepared', {}, false
    state.finalization = false
    if type(state.document) ~= 'table' then return nil, 'missing document witnesses' end
    state.document_witness = copy(state.document.before)
    return M.restore(state)
end
function M.step(record, event)
    local state, err = M.restore(record)
    if not state then return nil, { kind = 'refused', reason = err } end
    local function result(kind, reason, extra)
        local outcome = { kind = kind, phase = state.phase, reason = reason }
        for k, v in pairs(extra or {}) do outcome[k] = copy(v) end
        return state, outcome
    end
    if not json(event) or type(event) ~= 'table' then return result('pending', 'invalid event') end
    if state.phase == 'retired' or event.op_id ~= state.op_id or event.generation ~= state.generation then
        return result('ignored', 'stale operation event')
    end
    local function advance()
        state.phase = successors[state.phase]
        return result(state.phase == 'retired' and 'done' or 'advanced')
    end
    local function effect(child_id)
        return result('effect', nil, { op_id = state.op_id, generation = state.generation,
            document_generation = state.document_generation, child_id = child_id })
    end
    if event.kind == 'saved' then
        if state.phase ~= 'metadata' then return result('pending', 'editor synchronization required before save') end
        if not integer(event.document_generation) or event.document_generation <= state.document_generation
            or event.witness == nil then return result('ignored', 'stale document save') end
        state.document_generation, state.editor_generation = event.document_generation, event.document_generation
        state.document_witness = copy(event.witness)
        local valid = validate(state)
        if not valid then return M.restore(record), { kind = 'pending', phase = record.phase, reason = 'invalid saved witness' } end
        return result('advanced')
    end
    if event.phase and event.phase ~= state.phase then return result('ignored', 'stale phase event') end
    if event.kind == 'effect_failed' then return result('pending', event.reason or 'effect failed') end
    if event.kind == 'journal_saved' then
        if state.phase ~= 'prepared' then return result('ignored', 'journal already admitted') end
        return advance()
    end
    if event.kind == 'editor_synced' then
        if state.phase ~= 'editor' then return result('ignored', 'stale editor event') end
        if event.document_generation ~= state.document_generation then return result('ignored', 'stale editor generation') end
        state.editor_generation = state.document_generation
        return advance()
    end
    if event.kind == 'metadata_reply' then
        if state.phase ~= 'metadata' then return result('ignored', 'stale metadata event') end
        if event.ok ~= true or event.id ~= state.id or event.new ~= state.new then
            return result('pending', 'metadata identity not confirmed')
        end
        return advance()
    end
    if event.kind == 'finalization_started' or event.kind == 'finalization_authorized' or event.kind == 'finalization_released' then
        if state.phase ~= 'complete' then return result('pending', 'metadata acknowledgement required before finalization') end
        local next_record, finalization_err = M.finalization_step(state.finalization, event.kind, event.finalization, state.document_witness)
        if not next_record then return result('pending', finalization_err) end
        state.finalization = next_record
        return result('advanced')
    end
    if event.kind == 'cleanup_done' then
        if state.phase ~= 'complete' then return result('ignored', 'stale cleanup event') end
        if state.finalization and state.finalization.stage ~= 'retire' then return result('pending', 'protection finalization incomplete') end
        return advance()
    end
    if event.kind ~= 'observed' then return result('pending', 'unknown event') end
    if event.phase ~= state.phase then return result('ignored', 'missing observation phase') end
    if event.proof ~= 'before' and event.proof ~= 'after' then return result('pending', 'unknown publication proof') end
    if state.phase == 'prepared' then return result('pending', 'journal persistence required') end
    if state.phase == 'editor' or state.phase == 'metadata' or state.phase == 'complete' then
        if event.proof == 'before' and equal(event.witness, state.document_witness) then return effect() end
        return result('pending', 'explicit completion required')
    end
    local witnesses = state[state.phase]
    if state.phase == 'children' then
        witnesses = nil
        for _, child in ipairs(state.children) do if child.id == event.child_id then witnesses = child; break end end
        if not witnesses then
            if #state.children == 0 and event.child_id == nil and event.proof == 'after' and event.witness == false then
                return advance()
            end
            return result('pending', 'unknown child identity')
        end
        for _, id in ipairs(state.completed) do if id == event.child_id then return result('ignored', 'child already proven') end end
    end
    local expected = false
    if witnesses ~= false then expected = witnesses[event.proof] end
    if not equal(event.witness, expected) then return result('pending', 'witness mismatch') end
    if event.proof == 'before' then
        if witnesses == false then return result('pending', 'no-op requires after observation') end
        return effect(event.child_id)
    end
    if state.phase == 'document' then state.document_witness = copy(state.document.after) end
    if state.phase == 'parent' and state.parent ~= false then state.document_witness = copy(state.parent.after) end
    if state.phase == 'children' then
        state.completed[#state.completed + 1] = event.child_id
        if #state.completed < #state.children then return result('advanced') end
    end
    return advance()
end
return M
