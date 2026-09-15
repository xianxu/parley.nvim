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

    it("confirmed launch failure needs no exit or pipe evidence", function()
        local state = attempt.transition(attempt.new(), { type = "spawn_failed" })
        assert.is_false(attempt.is_unresolved(state))
        assert.is_true(attempt.can_deliver_terminal(state))
        state = attempt.transition(state, { type = "delivered" })
        assert.is_false(attempt.can_deliver_terminal(state))
    end)
end)
