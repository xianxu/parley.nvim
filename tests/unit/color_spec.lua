-- Unit tests for lua/parley/color.lua (#387): the pure blend behind the edit tints.
local color = require("parley.color")

describe("color.blend", function()
    it("alpha 0 is the base, alpha 1 the tint", function()
        assert.equals(0x123456, color.blend(0x123456, 0xabcdef, 0))
        assert.equals(0xabcdef, color.blend(0x123456, 0xabcdef, 1))
    end)
    it("mixes each channel independently, rounded", function()
        -- 0x00 → 0xff at 0.5 is 127.5 → 128 per channel
        assert.equals(0x808080, color.blend(0x000000, 0xffffff, 0.5))
        assert.equals(0x1a0000, color.blend(0x000000, 0xff0000, 0.1)) -- 25.5 → 26
        assert.equals(0x00ff00, color.blend(0x00ff00, 0x00ff00, 0.3))
    end)
    it("moves a dark and a light base toward the tint by the same fraction", function()
        assert.equals(0x262626, color.blend(0x000000, 0xffffff, 0.15)) -- 38.25 → 38
        assert.equals(0xd9d9d9, color.blend(0xffffff, 0x000000, 0.15)) -- 216.75 → 217
    end)
end)
