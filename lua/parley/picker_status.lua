local M = {}

M.new = function(dependencies)
    dependencies = dependencies or {}
    local uv = vim.uv or vim.loop
    local frame = dependencies.frame or require("parley.progress").frame
    local new_timer = dependencies.new_timer or function() return uv.new_timer() end
    local schedule = dependencies.schedule or vim.schedule

    local timer
    local tick = 0
    local message
    local on_render
    local active = false
    local current
    local controller = {}

    local function render()
        if not active then
            return
        end
        current = " " .. frame(tick) .. " " .. message
        on_render(current)
    end

    controller.stop = function()
        if not active then
            return
        end
        active = false
        current = nil
        if timer then
            pcall(timer.stop, timer)
            pcall(timer.close, timer)
            timer = nil
        end
    end

    controller.start = function(_, initial_message, render_callback)
        controller.stop()
        assert(type(initial_message) == "string", "status message must be a string")
        assert(type(render_callback) == "function", "status render callback is required")
        tick = 0
        message = initial_message
        on_render = render_callback
        active = true
        render()
        timer = new_timer()
        timer:start(120, 120, function()
            schedule(function()
                if active then
                    tick = tick + 1
                    render()
                end
            end)
        end)
    end

    controller.set = function(_, next_message)
        assert(type(next_message) == "string", "status message must be a string")
        message = next_message
        render()
    end

    controller.current = function()
        return current
    end

    return controller
end

return M
