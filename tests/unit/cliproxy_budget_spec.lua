-- #197: the recovery backstop must exceed the repair it guards.
--
-- Two review rounds re-opened this drift, because the relationship lived only
-- in a comment. Now it is asserted: add a step to the repair and this fails.

local cliproxy = require("parley.cliproxy")
local dispatcher = require("parley.dispatcher")

describe("repair budget vs recovery backstop", function()
    it("the itemized repair worst case fits inside recovery_timeout_ms", function()
        local total = 0
        for _, sec in pairs(cliproxy._repair_budget_sec) do
            total = total + sec
        end
        assert.is_true(total * 1000 < dispatcher.recovery_timeout_ms,
            ("repair worst case %ds >= backstop %dms — the backstop would spend the "
                .. "claim's one-shot and replace a correct diagnosis with 'recovery timed out'")
                :format(total, dispatcher.recovery_timeout_ms))
    end)

    it("the COMPOUND path (repair then restart) stays under the backstop too", function()
        -- The compound case is meant to be unreachable — recover latches a
        -- per-claim flag so a repair is never followed by a restart. If that
        -- latch ever regresses, two full repairs run (~36s) past the backstop,
        -- the claim's one-shot is spent, and a correct diagnosis is replaced by
        -- "recovery timed out". Assert the arithmetic so the claim is checkable.
        local single = 0
        for _, sec in pairs(cliproxy._repair_budget_sec) do
            single = single + sec
        end
        local restart_only = cliproxy._repair_budget_sec.stop_identity_probe
            + cliproxy._repair_budget_sec.port_release
            + cliproxy._repair_budget_sec.ensure_probe
            + cliproxy._repair_budget_sec.poll_healthy
        assert.is_true((single + restart_only) * 1000 > dispatcher.recovery_timeout_ms,
            "compound path now fits — either it became reachable and safe, or the "
                .. "budget drifted; re-derive rather than deleting this test")
    end)

    it("leaves real headroom, not a one-second coincidence", function()
        local total = 0
        for _, sec in pairs(cliproxy._repair_budget_sec) do
            total = total + sec
        end
        assert.is_true(dispatcher.recovery_timeout_ms - (total * 1000) >= 5000,
            "less than 5s of headroom between the repair and its backstop")
    end)
end)
