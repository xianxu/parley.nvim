-- Unit tests for lua/parley/define.lua (pure core).
-- See workshop/issues/000161-inline-term-definition.md and its plan.

local define = require("parley.define")

describe("define.slice_selection", function()
    local lines = { "the quick brown", "fox jumps over", "the lazy dog" }

    it("extracts a single-line span", function()
        -- select "quick" on line 1: 0-based cols [4,8] (inclusive end)
        assert.equals("quick", define.slice_selection(lines, 1, 4, 1, 8))
    end)

    it("extracts a multi-line span joined with newline", function()
        -- "brown" .. "\n" .. "fox"
        assert.equals("brown\nfox", define.slice_selection(lines, 1, 10, 2, 2))
    end)

    it("clamps an end column past line length", function()
        assert.equals("dog", define.slice_selection(lines, 3, 9, 3, 999))
    end)

    it("returns empty string for a reversed/empty span", function()
        assert.equals("", define.slice_selection(lines, 1, 5, 1, 4))
    end)
end)
