local timezone_diagnostics = require("parley.timezone_diagnostics")

describe("timezone_diagnostics.build_diagnostics", function()
    it("builds a deterministic local-time diagnostic for strict UTC timestamps", function()
        local seen_epoch = nil
        local diagnostics = timezone_diagnostics.build_diagnostics({
            "Meet at 2026-04-18T00:00:00Z before standup",
        }, {
            to_local = function(epoch)
                seen_epoch = epoch
                return {
                    year = 2026,
                    month = 4,
                    day = 17,
                    hour = 17,
                    min = 0,
                    sec = 0,
                }
            end,
        })

        assert.equals(1776470400, seen_epoch)
        assert.equals(1, #diagnostics)
        assert.equals(0, diagnostics[1].lnum)
        assert.equals(8, diagnostics[1].col)
        assert.equals(28, diagnostics[1].end_col)
        assert.equals("2026-04-18T00:00:00Z", diagnostics[1].utc)
        assert.is_true(diagnostics[1].message:find("2026-04-18T00:00:00Z", 1, true) ~= nil)
        assert.is_true(diagnostics[1].message:find("2026-04-17 17:00:00", 1, true) ~= nil)
    end)

    it("rejects invalid calendar dates", function()
        local diagnostics = timezone_diagnostics.build_diagnostics({
            "bad date 2026-02-30T00:00:00Z",
        }, {
            to_local = function()
                error("invalid dates must not be localized")
            end,
        })

        assert.equals(0, #diagnostics)
    end)

    it("ignores non-UTC offset timestamps", function()
        local diagnostics = timezone_diagnostics.build_diagnostics({
            "offset 2026-04-18T00:00:00+02:00",
        }, {
            to_local = function()
                error("non-UTC offsets are out of scope")
            end,
        })

        assert.equals(0, #diagnostics)
    end)
end)
