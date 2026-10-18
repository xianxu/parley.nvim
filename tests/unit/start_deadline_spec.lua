-- #382: a deadline is measured from when it is started, not from the loop's
-- cached time. Without update_time, a 500 ms timer started after a 1 s
-- synchronous block fired 6 ms later (measured on 0.11.7 and 0.12.5).
local arrival = require("tests.helpers.arrival")
local helper = require("parley.helper")
local uv = vim.uv or vim.loop

describe("helper.start_deadline", function()
    it("measures the deadline from its start, after synchronous work", function()
        local fired_after
        vim.schedule(function()
            local t0 = uv.hrtime()
            while (uv.hrtime() - t0) < 600e6 do end -- block the loop 600 ms
            local started = uv.hrtime()
            local timer = uv.new_timer()
            helper.start_deadline(timer, 300, function()
                fired_after = (uv.hrtime() - started) / 1e6
                timer:close()
            end)
        end)
        assert.is_true(vim.wait(arrival.MS, function() return fired_after ~= nil end, 5))
        assert.is_true(fired_after >= 290, ("a 300 ms deadline fired after %.0f ms"):format(fired_after))
    end)

    it("uses an injected runtime's clock and tolerates one without update_time", function()
        local refreshed, started = 0, {}
        local timer = { start = function(_, ms, repeat_ms, cb) started = { ms, repeat_ms, cb } end }
        local cb = function() end
        helper.start_deadline(timer, 42, cb, { update_time = function() refreshed = refreshed + 1 end })
        assert.equals(1, refreshed)
        assert.same({ 42, 0, cb }, started)
        helper.start_deadline(timer, 7, cb, {})
        assert.same({ 7, 0, cb }, started)
    end)

    it("defer_deadline measures from its start too, and closes its timer", function()
        local fired_after, timer
        vim.schedule(function()
            local t0 = uv.hrtime()
            while (uv.hrtime() - t0) < 600e6 do end -- block the loop 600 ms
            local started = uv.hrtime()
            timer = helper.defer_deadline(function() fired_after = (uv.hrtime() - started) / 1e6 end, 300)
        end)
        assert.is_true(vim.wait(arrival.MS, function() return fired_after ~= nil end, 5))
        assert.is_true(fired_after >= 290, ("a 300 ms deadline fired after %.0f ms"):format(fired_after))
        assert.is_true(timer:is_closing())
    end)
end)
