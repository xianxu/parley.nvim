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
    elseif event.type == "stop_requested" then
        state.stop_requested = true
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
    return state, { terminal_ready = M.can_deliver_terminal(state) }
end

return M
