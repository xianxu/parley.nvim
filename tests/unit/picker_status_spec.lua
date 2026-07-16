local picker_status = require("parley.picker_status")

local function timer_fake()
    local state = { start_count = 0, stop_count = 0, close_count = 0 }
    local timer = {}
    timer.start = function(_, delay, interval, callback)
        state.start_count = state.start_count + 1
        state.delay = delay
        state.interval = interval
        state.callback = callback
    end
    timer.stop = function()
        state.stop_count = state.stop_count + 1
    end
    timer.close = function()
        state.close_count = state.close_count + 1
    end
    return timer, state
end

describe("picker status controller", function()
    it("renders immediately and advances canonical frames every 120ms", function()
        local timer, timer_state = timer_fake()
        local rendered = {}
        local controller = picker_status.new({
            frame = function(tick) return "frame-" .. tick end,
            new_timer = function() return timer end,
            schedule = function(callback) callback() end,
        })

        controller:start("scanning…", function(line)
            rendered[#rendered + 1] = line
        end)
        timer_state.callback()
        timer_state.callback()

        assert.equals(120, timer_state.delay)
        assert.equals(120, timer_state.interval)
        assert.same({
            " frame-0 scanning…",
            " frame-1 scanning…",
            " frame-2 scanning…",
        }, rendered)
        assert.equals(" frame-2 scanning…", controller:current())
    end)

    it("updates the message without replacing the timer", function()
        local timer, timer_state = timer_fake()
        local current
        local controller = picker_status.new({
            frame = function(tick) return "f" .. tick end,
            new_timer = function() return timer end,
            schedule = function(callback) callback() end,
        })

        controller:start("scanning…", function(line) current = line end)
        controller:set("still scanning…")

        assert.equals(" f0 still scanning…", current)
        assert.equals(1, timer_state.start_count)
    end)

    it("stops and closes its timer exactly once", function()
        local timer, timer_state = timer_fake()
        local controller = picker_status.new({
            frame = function() return "f" end,
            new_timer = function() return timer end,
            schedule = function(callback) callback() end,
        })
        controller:start("scanning…", function() end)

        controller:stop()
        controller:stop()
        if timer_state.callback then
            timer_state.callback()
        end

        assert.equals(1, timer_state.stop_count)
        assert.equals(1, timer_state.close_count)
        assert.is_nil(controller:current())
    end)
end)
