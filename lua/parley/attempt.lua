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

function M.transition(previous, event)
    local state = M.new(previous)
    if event.type == "spawned" then
        state.pid = event.pid
    elseif event.type == "spawn_failed" then
        state.spawn_failed = true
    elseif event.type == "stop_requested" or event.type == "reconcile_requested" then
        if event.type == "stop_requested" then state.stop_requested = true end
        if event.now and not state.reconcile_started then
            state.reconcile_started=event.now;state.reconcile_due=event.now+50;state.reconcile_delay=50
        end
    elseif event.type == "reconcile_tick" and state.reconcile_due and event.now>=state.reconcile_due then
        if event.now-state.reconcile_started>=5000 then
            state.unresolved_visible=true;state.reconcile_due=nil
        else
            state.reconcile_probes=(state.reconcile_probes or 0)+1
            state.reconcile_delay=math.min(state.reconcile_delay*2,1000)
            state.reconcile_due=math.min(event.now+state.reconcile_delay,state.reconcile_started+5000)
        end
    elseif event.type == "observation" then
        state.observation = event.observation
    elseif event.type == "signal_observation" then
        state.signal_observation = event.observation
        if event.observation == "accepted" then state.accepted_signal = event.signal end
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
    return state, { terminal_ready = M.can_deliver_terminal(state),
        probe=(state.reconcile_probes or 0)>(previous.reconcile_probes or 0),
        unresolved=state.unresolved_visible and not previous.unresolved_visible or false }
end

return M
