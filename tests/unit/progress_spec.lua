-- Unit tests for the pure parts of lua/parley/progress.lua (#133 M7).

local progress = require("parley.progress")

describe("progress (pure)", function()
    it("frame cycles spinner glyphs and wraps", function()
        assert.is_string(progress.frame(3))
        assert.are_not.equal(progress.frame(0), progress.frame(1))
        assert.are.equal(progress.frame(0), progress.frame(10)) -- 10 glyphs → wraps
    end)

    it("format renders spinner + message + elapsed seconds", function()
        local s = progress.format("X", "review running", 28)
        assert.is_truthy(s:find("X", 1, true))
        assert.is_truthy(s:find("review running", 1, true))
        assert.is_truthy(s:find("28", 1, true))
    end)
end)
