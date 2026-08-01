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

    it("leaves real headroom, not a one-second coincidence", function()
        local total = 0
        for _, sec in pairs(cliproxy._repair_budget_sec) do
            total = total + sec
        end
        assert.is_true(dispatcher.recovery_timeout_ms - (total * 1000) >= 5000,
            "less than 5s of headroom between the repair and its backstop")
    end)
end)
