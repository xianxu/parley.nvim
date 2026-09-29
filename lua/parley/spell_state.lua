-- Pure spelling admission and acceptance. Targets use zero-based byte columns.
local M = {}
local identity = { 'buf', 'win', 'row', 'start_col', 'end_col', 'word' }
local exact = { 'tick', 'col', 'mode', 'generation' }

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function matches(left, right, keys)
    if not left or not right then return false end
    for _, key in ipairs(keys) do
        if left[key] ~= right[key] then return false end
    end
    return true
end

function M.target_at(line, col, mode, spans)
    if (mode ~= 'n' and mode ~= 'i') or #line > 16384 or col < 0 then return nil end
    for _, span in ipairs(spans) do
        local first, last = span.start_col, span.end_col
        if first >= 0 and last <= #line and last > first and last - first <= 128
            and col >= first and (col < last or (mode == 'i' and col == last)) then
            return { start_col = first, end_col = last, word = line:sub(first + 1, last) }
        end
    end
end

function M.same_target(left, right)
    return matches(left, right, identity)
end

function M.accepts(evidence, live)
    return M.same_target(evidence, live) and matches(evidence, live, exact)
end

function M.new()
    return { phase = 'idle', generation = 0 }
end

-- Every returned value is independent of input state, event and effect tables.
-- Controller effects describe resource work; only the reducer authorizes tickets.
function M.transition(state, event)
    local next_state, effects = copy(state), {}
    local function emit(kind, fields)
        local effect = copy(fields or {})
        effect.kind = kind
        effects[#effects + 1] = effect
    end
    local function revoke()
        next_state.generation = next_state.generation + 1
        next_state.target, next_state.ticket = nil, nil
        emit('cancel')
        emit('hide')
        emit('release')
    end
    local function ticket()
        next_state.ticket = copy(next_state.target)
        next_state.ticket.generation = next_state.generation
        emit('show', { evidence = next_state.ticket, generation = next_state.generation })
    end
    local kind = event.kind
    if kind == 'attach' then
        if state.phase == 'detached' then next_state.phase = 'idle' end
    elseif kind == 'detach' then
        revoke()
        next_state.phase, next_state.dismissed = 'detached', nil
    elseif state.phase == 'detached' then
        return next_state, effects
    elseif kind == 'invalidate' then
        revoke()
        next_state.phase = next_state.dismissed and 'dismissed' or 'idle'
    elseif kind == 'observe' or kind == 'request' then
        local target = event.target
        if kind == 'observe' and M.same_target(next_state.dismissed, target) then
            next_state.target, next_state.phase = copy(target), 'dismissed'
        elseif kind == 'observe' and M.accepts(next_state.target, target) then
            -- Hide alone cannot re-arm an unchanged observation.
            return next_state, effects
        else
            revoke()
            next_state.dismissed = nil
            next_state.target = copy(target)
            next_state.phase = target and 'pending' or 'idle'
            if target then
                if kind == 'request' then ticket()
                else emit('schedule', { generation = next_state.generation }) end
            end
        end
    elseif kind == 'timer' then
        if next_state.phase == 'pending' and not next_state.ticket
            and event.generation == next_state.generation then ticket() end
    elseif kind == 'source_request' then
        local live = copy(event.target)
        if live then live.generation = live.generation or next_state.generation end
        if M.accepts(next_state.ticket, live) then
            emit('admitted', { evidence = next_state.ticket })
        end
    elseif kind == 'shown' then
        if next_state.ticket and event.generation == next_state.generation then
            next_state.phase = 'open'
            emit('lease')
        end
    elseif kind == 'dismiss' then
        local dismissed = copy(next_state.target or next_state.dismissed)
        revoke()
        next_state.dismissed = dismissed
        next_state.phase = dismissed and 'dismissed' or 'idle'
    elseif kind == 'hidden' then
        if next_state.phase ~= 'dismissed' then next_state.phase = 'idle' end
        emit('release')
    elseif kind == 'consume' then
        if M.accepts(next_state.ticket, event.evidence) and M.accepts(event.evidence, event.live) then
            next_state.ticket, next_state.phase = nil, 'idle'
            emit('release')
            emit('consumed')
        end
    end
    return next_state, effects
end

return M
