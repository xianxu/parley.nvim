-- #293: tests.helpers.await.until_progress tells a slow convergence from a
-- stuck one. Each case drives progress from a real timer, so the wait's own
-- event-loop turns are what advance it.
local Await = require("tests.helpers.await")

describe("await.until_progress (#293)", function()
    local timer
    local function tick_every(ms, fn)
        timer = vim.uv.new_timer()
        timer:start(ms, ms, vim.schedule_wrap(fn))
    end
    after_each(function()
        if timer then timer:stop(); timer:close(); timer = nil end
    end)

    it("settles past the stall window while progress keeps moving", function()
        local n = 0
        tick_every(10, function() n = n + 1 end)
        local ok, why = Await.until_progress(function() return n >= 30 end, function() return n end, 100)
        assert.is_true(ok, tostring(why))
    end)

    it("fails as stalled when progress stops before the predicate holds", function()
        local n = 0
        tick_every(10, function() if n < 5 then n = n + 1 end end)
        local start = vim.uv.now()
        local ok, why = Await.until_progress(function() return false end, function() return n end, 100)
        assert.is_false(ok)
        assert.equals("stalled", why)
        assert.is_true(vim.uv.now() - start < 1000, "a stall fails near its window, not at the ceiling")
    end)

    it("fails at the ceiling even while progress keeps moving", function()
        local n = 0
        tick_every(5, function() n = n + 1 end)
        local ok, why = Await.until_progress(function() return false end, function() return n end, 100, 300)
        assert.is_false(ok)
        assert.equals("ceiling", why)
    end)
end)
