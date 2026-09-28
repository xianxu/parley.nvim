-- #293: tests.helpers.await.until_progress tells a slow convergence from a
-- stuck one. A fake clock drives it: each wait advances time by the slice it
-- was given and runs one step of the simulated work, so the cases are exact.
local Await = require("tests.helpers.await")

-- step(t) runs once per wait slice at fake time t (ms).
local function fake(step)
    local t = 0
    return {
        now = function() return t end,
        wait = function(ms, predicate)
            t = t + ms
            step(t)
            return predicate()
        end,
    }, function() return t end
end

describe("await.until_progress (#293)", function()
    it("settles past the stall window while progress keeps moving", function()
        local n = 0
        local env, clock = fake(function() n = n + 1 end)
        local ok, why = Await.until_progress(function() return n >= 30 end, function() return n end, 100, 10000, env)
        assert.is_true(ok, tostring(why))
        assert.is_true(clock() > 100, "settled only after outlasting one stall window")
    end)

    it("fails as stalled one window after progress stops", function()
        local n = 0
        local env, clock = fake(function() if n < 5 then n = n + 1 end end)
        local ok, why = Await.until_progress(function() return false end, function() return n end, 100, 10000, env)
        assert.is_false(ok)
        assert.equals("stalled", why)
        -- progress last moved on the 5th slice (t=250); stalled 100ms later
        assert.equals(350, clock())
    end)

    it("fails at the ceiling even while progress keeps moving", function()
        local n = 0
        local env, clock = fake(function() n = n + 1 end)
        local ok, why = Await.until_progress(function() return false end, function() return n end, 100, 300, env)
        assert.is_false(ok)
        assert.equals("ceiling", why)
        assert.equals(300, clock())
    end)

    it("a wait with no progress at all gets exactly the stall window", function()
        local env, clock = fake(function() end)
        local ok, why = Await.until_progress(function() return false end, function() return 0 end, 5000, 40000, env)
        assert.is_false(ok)
        assert.equals("stalled", why)
        assert.equals(5000, clock())
    end)
end)
