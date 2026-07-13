local diagnostic_refresh = require("parley.diagnostic_refresh")

describe("diagnostic refresh", function()
    it("refreshes timezone before footnotes synchronously", function()
        local calls = {}
        local refresh = diagnostic_refresh._new({
            is_valid = function(buf) return buf == 7 end,
            timezone = { refresh_buffer = function() table.insert(calls, "timezone") end },
            footnotes = { refresh_footnote_diagnostics = function() table.insert(calls, "footnote") end },
        })

        refresh.refresh(7)
        assert.are.same({ "timezone", "footnote" }, calls)
    end)

    it("does nothing for an invalid buffer", function()
        local calls = 0
        local refresh = diagnostic_refresh._new({
            is_valid = function() return false end,
            timezone = { refresh_buffer = function() calls = calls + 1 end },
            footnotes = { refresh_footnote_diagnostics = function() calls = calls + 1 end },
        })
        refresh.refresh(99)
        refresh.clear(99)
        assert.equals(0, calls)
    end)

    it("clears timezone and only footnote-owned decorations", function()
        local calls = {}
        local refresh = diagnostic_refresh._new({
            is_valid = function() return true end,
            timezone = { clear = function() table.insert(calls, "timezone") end },
            footnotes = { clear_footnote_diagnostics = function() table.insert(calls, "footnote") end },
        })
        refresh.clear(3)
        assert.are.same({ "timezone", "footnote" }, calls)
    end)
end)
