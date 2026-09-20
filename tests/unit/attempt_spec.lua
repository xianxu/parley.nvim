local attempt = require("parley.attempt")

describe("attempt reducer", function()
    it("matches independent exit/drain oracle for every evidence combination", function()
        for exit = 0, 1 do
            for stdout = 0, 1 do
                for stderr = 0, 1 do
                    for _, observation in ipairs({ "alive", "missing", "unknown" }) do
                        local state = attempt.new({ attempt_id = "a" })
                        state = attempt.transition(state, { type = "spawned", pid = 42 })
                        state = attempt.transition(state, { type = "stop_requested" })
                        state = attempt.transition(state, { type = "observation", observation = observation })
                        if exit == 1 then state = attempt.transition(state, { type = "exit" }) end
                        if stdout == 1 then state = attempt.transition(state, { type = "stdout_eof" }) end
                        if stderr == 1 then state = attempt.transition(state, { type = "stderr_eof" }) end
                        local complete = exit + stdout + stderr == 3
                        assert.equals(complete, attempt.can_deliver_terminal(state))
                        assert.equals(not complete, attempt.is_unresolved(state))
                    end
                end
            end
        end
    end)

    it("delivers once under all reordered and duplicate completion evidence", function()
        local orders = {
            { "exit", "stdout_eof", "stderr_eof" },
            { "exit", "stderr_eof", "stdout_eof" },
            { "stdout_eof", "exit", "stderr_eof" },
            { "stdout_eof", "stderr_eof", "exit" },
            { "stderr_eof", "stdout_eof", "exit" },
            { "stderr_eof", "exit", "stdout_eof" },
        }
        for _, order in ipairs(orders) do
            local initial = attempt.new({ attempt_id = "a" })
            local state = initial
            local deliveries = 0
            for _, kind in ipairs(order) do
                for _ = 1, 2 do
                    state = attempt.transition(state, { type = kind })
                    if attempt.can_deliver_terminal(state) then
                        deliveries = deliveries + 1
                        state = attempt.transition(state, { type = "delivered" })
                    end
                end
            end
            assert.equals(1, deliveries)
            assert.is_true(attempt.is_unresolved(initial))
            assert.is_nil(initial.exited)
        end
    end)

    -- #261 M3: the stop window. TERM at the stop, KILL at stop+2000 while the
    -- attempt is unresolved, visible at stop+5000. `drive` ticks exactly when the
    -- reducer asks to be ticked, as tasker's timer does, and returns the time of
    -- each effect.
    local function drive(state, until_ms, events)
        local seen = { escalate = {}, unresolved = {} }
        events = events or {}
        local pending = {}
        for _, e in ipairs(events) do pending[#pending + 1] = e end
        table.sort(pending, function(a, b) return a.now < b.now end)
        while true do
            local next_event = pending[1]
            local due = state.reconcile_due
            if next_event and (not due or next_event.now <= due) then
                table.remove(pending, 1)
                state = attempt.transition(state, next_event)
            elseif due and due <= until_ms then
                local effects
                state, effects = attempt.transition(state, { type = "reconcile_tick", now = due })
                if effects.escalate then seen.escalate[#seen.escalate + 1] = due end
                if effects.unresolved then seen.unresolved[#seen.unresolved + 1] = due end
            else
                return state, seen
            end
        end
    end
    local function spawned()
        return attempt.transition(attempt.new({ attempt_id = "a" }), { type = "spawned", pid = 42 })
    end

    describe("stop escalation", function()
        it("live + stop: KILL is due at exactly stop+2000, then visible at stop+5000", function()
            local state, effects = attempt.transition(spawned(), { type = "stop_requested", now = 1000 })
            assert.is_true(effects.opened)
            assert.equals(3000, state.kill_due)
            assert.equals("stop", state.stop_cause)
            local _, seen = drive(state, 10000)
            assert.same({ 3000 }, seen.escalate)
            assert.same({ 6000 }, seen.unresolved)
        end)

        it("live + deadline: the same window, with cause deadline", function()
            local state = attempt.transition(spawned(), { type = "stop_requested", now = 0, cause = "deadline" })
            assert.equals(2000, state.kill_due)
            assert.equals("deadline", state.stop_cause)
            assert.is_true(state.stop_requested)
            local _, seen = drive(state, 10000)
            assert.same({ 2000 }, seen.escalate)
        end)

        it("stopping + stop or deadline again: kill_due and the cause are kept", function()
            local state = attempt.transition(spawned(), { type = "stop_requested", now = 0 })
            local effects
            state, effects = attempt.transition(state, { type = "stop_requested", now = 1500 })
            assert.equals(2000, state.kill_due)
            assert.is_false(effects.opened)
            state = attempt.transition(state, { type = "stop_requested", now = 1800, cause = "deadline" })
            assert.equals(2000, state.kill_due)
            assert.equals("stop", state.stop_cause)
            local _, seen = drive(state, 10000)
            assert.same({ 2000 }, seen.escalate)
        end)

        it("stopping + exit and both EOFs before KILL: no escalate", function()
            local state = attempt.transition(spawned(), { type = "stop_requested", now = 0 })
            local _, seen = drive(state, 10000, {
                { type = "exit", now = 1000 }, { type = "stdout_eof", now = 1000 }, { type = "stderr_eof", now = 1000 },
            })
            assert.same({}, seen.escalate)
            assert.same({}, seen.unresolved)
        end)

        it("exited without EOF, then a late stop: the stop opens its own window", function()
            -- The grandchild case: the parent exits holding nothing, a grandchild
            -- keeps the pipe open, and the exit opens a probe-only window.
            local state = attempt.transition(spawned(), { type = "exit", now = 100 })
            state = attempt.transition(state, { type = "reconcile_requested", now = 100 })
            assert.is_nil(state.kill_due)
            local seen
            state, seen = drive(state, 10000, { { type = "stop_requested", now = 3000 } })
            assert.same({ 5000 }, seen.escalate)
            assert.same({ 8000 }, seen.unresolved)
        end)

        it("a stop after the exit window went visible reopens the window", function()
            local state = attempt.transition(spawned(), { type = "exit", now = 0 })
            state = attempt.transition(state, { type = "reconcile_requested", now = 0 })
            local seen
            state, seen = drive(state, 6000)
            assert.same({ 5000 }, seen.unresolved)
            assert.same({}, seen.escalate, "an exit window never kills")
            state, seen = drive(state, 20000, { { type = "stop_requested", now = 7000 } })
            assert.same({ 9000 }, seen.escalate)
            assert.same({ 12000 }, seen.unresolved)
        end)

        it("unresolved-visible after a KILL: another stop kills again at +2000", function()
            local state = attempt.transition(spawned(), { type = "stop_requested", now = 0 })
            local seen
            state, seen = drive(state, 6000)
            assert.same({ 2000 }, seen.escalate)
            assert.same({ 5000 }, seen.unresolved)
            state, seen = drive(state, 20000, { { type = "stop_requested", now = 8000, cause = "leave" } })
            assert.same({ 10000 }, seen.escalate)
            assert.same({ 13000 }, seen.unresolved)
            assert.equals("leave", state.stop_cause)
        end)

        it("escalates once per window", function()
            local state = attempt.transition(spawned(), { type = "stop_requested", now = 0 })
            local _, seen = drive(state, 4999)
            assert.same({ 2000 }, seen.escalate)
        end)

        it("names the cause of a kill it signalled, and of no other end", function()
            local state = attempt.transition(spawned(), { type = "stop_requested", now = 0 })
            state = attempt.transition(state, { type = "signal_observation", observation = "accepted", signal = 15 })
            state = attempt.transition(state, { type = "exit", signal = 15 })
            assert.equals("stop", attempt.kill_cause(state))
            -- The parent exited; the signal reached the grandchild holding the pipe.
            local grandchild = attempt.transition(spawned(), { type = "exit", code = 0 })
            grandchild = attempt.transition(grandchild, { type = "stop_requested", now = 0, cause = "leave" })
            grandchild = attempt.transition(grandchild, { type = "signal_observation", observation = "accepted", signal = 9 })
            assert.equals("leave", attempt.kill_cause(grandchild))
            -- The group was already gone: nothing was killed.
            local gone = attempt.transition(spawned(), { type = "stop_requested", now = 0 })
            gone = attempt.transition(gone, { type = "signal_observation", observation = "missing", signal = 15 })
            assert.is_nil(attempt.kill_cause(gone))
            assert.is_nil(attempt.kill_cause(attempt.transition(spawned(), { type = "exit", code = 0 })))
        end)
    end)

    it("confirmed launch failure needs no exit or pipe evidence", function()
        local state = attempt.transition(attempt.new(), { type = "spawn_failed" })
        assert.is_false(attempt.is_unresolved(state))
        assert.is_true(attempt.can_deliver_terminal(state))
        state = attempt.transition(state, { type = "delivered" })
        assert.is_false(attempt.can_deliver_terminal(state))
    end)
end)
