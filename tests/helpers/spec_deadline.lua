-- Pure supervisor policy. Clock values and validated progress events come from
-- the process adapter; the policy reads no clock, environment or editor state.
local M = {}
local records = setmetatable({}, {__mode="k"})

local function copy(value)
    local result = {}
    for key, item in pairs(value) do result[key] = item end
    return result
end

local function sealed(value)
    local state = {}
    records[state] = value
    return state
end

local function record(state)
    return assert(records[state], "invalid spec deadline state")
end

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function M.load_factor(load, ncpu)
    return math.min(4, math.max(1, load / math.max(1, ncpu)))
end

function M.new(base_ms, load, ncpu, now_ms)
    return sealed({status="running",completed=false,
        idle_ms=base_ms*M.load_factor(load,ncpu),absolute_ms=base_ms*4,
        started_at=now_ms,last_progress_at=now_ms,observed_at=now_ms,sequence=0})
end

function M.snapshot(state)
    return copy(record(state))
end

-- Each result is a new opaque state. In particular, neither caller edits nor
-- future transitions can mutate the predecessor's authoritative observation.
function M.transition(state, event)
    local next_state = copy(record(state))
    if next_state.status ~= "running" then return sealed(next_state) end
    if type(event) ~= "table" or not finite(event.now_ms)
        or event.now_ms < next_state.observed_at then return sealed(next_state) end
    local now = event.now_ms
    next_state.observed_at = now
    -- Expired work cannot revive itself by reporting progress or exit late.
    if now-next_state.started_at >= next_state.absolute_ms then
        next_state.status = "absolute-expired"
    elseif now-next_state.last_progress_at >= next_state.idle_ms then
        next_state.status = "stalled"
    elseif event.kind == "exit" then
        next_state.status, next_state.completed = "completed", true
    elseif event.kind == "progress" and finite(event.sequence)
        and event.sequence > 0 and event.sequence == math.floor(event.sequence)
        and event.sequence == next_state.sequence+1 then
        next_state.last_progress_at, next_state.sequence = now, event.sequence
    end
    return sealed(next_state)
end

return M
