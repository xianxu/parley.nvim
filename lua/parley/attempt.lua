-- Pure transport lifecycle. Observations never substitute for exit and drain.
local M = {}

function M.new(meta)
    local state = {}
    for key, value in pairs(meta or {}) do state[key] = value end
    return state
end

function M.can_deliver_terminal(state)
    return not state.delivered and (state.spawn_failed
        or (state.exited and state.stdout_eof and state.stderr_eof)) == true
end

function M.is_unresolved(state)
    return not state.spawn_failed and not (state.exited and state.stdout_eof and state.stderr_eof)
end

local KILL_AFTER, VISIBLE_AFTER = 2000, 5000

-- A stop opens its own window unless one is already running: TERM now, KILL at
-- `kill_due` while unresolved, visible at +5000. Its cause is `stop`, `deadline`
-- or `leave`. A window an exit opened only probes, so a later stop replaces it;
-- so does a stop after a window went visible (#261 M3).
local function open_stop_window(state, now, cause)
    state.stop_requested = true
    if not now or (state.kill_due and not state.unresolved_visible) then return end
    state.stop_cause, state.stop_window = cause, (state.stop_window or 0) + 1
    state.kill_due, state.escalated, state.unresolved_visible = now + KILL_AFTER, nil, nil
    state.reconcile_started, state.reconcile_due, state.reconcile_delay = now, now + 50, 50
end

function M.transition(previous, event)
    local state = M.new(previous)
    if event.type == "spawned" then
        state.pid = event.pid
    elseif event.type == "spawn_failed" then
        state.spawn_failed = true
    elseif event.type == "stop_requested" then
        open_stop_window(state, event.now, event.cause or "stop")
    elseif event.type == "reconcile_requested" then
        if event.now and not state.reconcile_started then
            state.reconcile_started=event.now;state.reconcile_due=event.now+50;state.reconcile_delay=50
        end
    elseif event.type == "reconcile_tick" and state.reconcile_due and event.now>=state.reconcile_due then
        if state.kill_due and not state.escalated and event.now >= state.kill_due then state.escalated = true end
        if event.now-state.reconcile_started>=VISIBLE_AFTER then
            state.unresolved_visible=true;state.reconcile_due=nil
        else
            state.reconcile_probes=(state.reconcile_probes or 0)+1
            state.reconcile_delay=math.min(state.reconcile_delay*2,1000)
            state.reconcile_due=math.min(event.now+state.reconcile_delay,state.reconcile_started+VISIBLE_AFTER)
            -- Clamped, so KILL lands at kill_due rather than the next back-off tick.
            if not state.escalated then state.reconcile_due = math.min(state.reconcile_due, state.kill_due or math.huge) end
        end
    elseif event.type == "observation" then
        state.observation = event.observation
    elseif event.type == "signal_observation" then
        state.signal_observation = event.observation
        if event.observation == "accepted" then state.accepted_signal, state.signalled = event.signal, true end
    elseif event.type == "exit" then
        state.exited = true
        state.code = event.code
        state.signal = event.signal
    elseif event.type == "stdout_eof" then
        state.stdout_eof = true
    elseif event.type == "stderr_eof" then
        state.stderr_eof = true
    elseif event.type == "delivered" and M.can_deliver_terminal(state) then
        state.delivered = true
    end
    -- A resolved attempt has nothing left to probe or kill.
    if not M.is_unresolved(state) then state.reconcile_due = nil end
    return state, { terminal_ready = M.can_deliver_terminal(state),
        probe=(state.reconcile_probes or 0)>(previous.reconcile_probes or 0),
        opened=state.stop_window ~= previous.stop_window,
        escalate=state.escalated == true and not previous.escalated,
        unresolved=state.unresolved_visible and not previous.unresolved_visible or false }
end

-- Why Parley killed this attempt, when it did: a signal it sent was accepted
-- while the attempt was unresolved, so its output may be cut — even when the
-- parent had exited and the signal reached a grandchild holding the pipe. Nil
-- for an attempt that ended on its own.
function M.kill_cause(state)
    return state.signalled and state.stop_cause or nil
end

return M
