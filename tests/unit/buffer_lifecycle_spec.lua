local buffer_lifecycle = require("parley.buffer_lifecycle")

describe("buffer lifecycle", function()
    local function clear(items)
        for i = #items, 1, -1 do items[i] = nil end
    end

    local function subject()
        local handlers = {}
        local calls = {}
        local lifecycle = buffer_lifecycle._new({
            is_valid = function(buf) return buf == 4 end,
            create_autocmd = function(events, callback)
                for _, event in ipairs(events) do handlers[event] = callback end
            end,
            diagnostics = {
                refresh = function(buf) table.insert(calls, "diagnostics:" .. buf) end,
                clear = function(buf) table.insert(calls, "clear-diagnostics:" .. buf) end,
            },
            structure = {
                rebuild = function(buf) table.insert(calls, "structure:" .. buf) end,
                clear = function(buf) table.insert(calls, "clear-structure:" .. buf) end,
            },
        })
        return lifecycle, handlers, calls
    end

    it("registers named convergence events once and never TextChangedI", function()
        local lifecycle, handlers = subject()
        lifecycle.setup(4)
        lifecycle.setup(4)
        for _, event in ipairs({ "InsertLeave", "TextChanged", "BufWritePost", "BufEnter", "WinEnter" }) do
            assert.is_function(handlers[event], event)
        end
        assert.is_nil(handlers.TextChangedI)
    end)

    it("converges diagnostics then structure exactly once per event", function()
        local lifecycle, handlers, calls = subject()
        lifecycle.setup(4)
        clear(calls)
        handlers.InsertLeave({ buf = 4, event = "InsertLeave" })
        assert.are.same({ "diagnostics:4", "structure:4" }, calls)
    end)

    it("uses the same convergence entry for stream finalization", function()
        local lifecycle, _, calls = subject()
        lifecycle.setup(4)
        clear(calls)
        lifecycle.finalize_mutated_api_leg(4, false)
        lifecycle.finalize_mutated_api_leg(4, true)
        assert.are.same({ "diagnostics:4", "structure:4" }, calls)
    end)

    it("tears down consumers independently and ignores later events", function()
        local lifecycle, handlers, calls = subject()
        lifecycle.setup(4)
        clear(calls)
        handlers.BufUnload({ buf = 4, event = "BufUnload" })
        assert.are.same({ "clear-diagnostics:4", "clear-structure:4" }, calls)
        clear(calls)
        handlers.TextChanged({ buf = 4, event = "TextChanged" })
        assert.are.same({}, calls)
    end)

    it("propagates structure convergence failures after notifying", function()
        local notified
        local lifecycle = buffer_lifecycle._new({
            is_valid = function() return true end,
            create_autocmd = function() end,
            diagnostics = { refresh = function() end, clear = function() end },
            structure = {
                rebuild = function() return nil, "candidate failed" end,
                clear = function() end,
            },
            notify = function(err) notified = err end,
        })
        local ok, err = pcall(lifecycle.setup, 4)
        assert.is_false(ok)
        assert.matches("candidate failed", err)
        assert.equals("candidate failed", notified)
    end)

    it("rolls back initial ownership so setup can retry after convergence failure", function()
        local attempts = 0
        local clears = {}
        local lifecycle = buffer_lifecycle._new({
            is_valid = function() return true end,
            create_autocmd = function() end,
            diagnostics = {
                refresh = function() end,
                clear = function() clears[#clears + 1] = "diagnostics" end,
            },
            structure = {
                rebuild = function()
                    attempts = attempts + 1
                    if attempts == 1 then return nil, "first build failed" end
                    return {}
                end,
                clear = function() clears[#clears + 1] = "structure" end,
            },
        })
        assert.is_false(pcall(lifecycle.setup, 4))
        assert.are.same({ "diagnostics", "structure" }, clears)
        assert.has_no.errors(function() lifecycle.setup(4) end)
        assert.equals(2, attempts)
    end)
end)
