local tuning = require("tests.helpers.jit_tuning")

describe("jit tuning for arm64 macOS mcode placement (#294)", function()
    it("knows which LuaJIT builds carry the mcode placement fix", function()
        assert.is_true(tuning.has_mcode_fix("LuaJIT 2.1.1788856981"))
        assert.is_true(tuning.has_mcode_fix("LuaJIT 2.1." .. tuning.MCODE_FIX))
        assert.is_false(tuning.has_mcode_fix("LuaJIT 2.1." .. (tuning.MCODE_FIX - 1)))
        assert.is_false(tuning.has_mcode_fix("LuaJIT 2.1.1741730670")) -- Neovim 0.11.7
        assert.is_false(tuning.has_mcode_fix("LuaJIT 2.1.0-beta3"))
        assert.is_false(tuning.has_mcode_fix(nil))
    end)

    it("tunes only arm64 macOS with the fix, where a large area cannot thrash", function()
        assert.same(tuning.OPTIONS, tuning.options("LuaJIT 2.1.1788856981", "arm64", "OSX"))
        assert.is_nil(tuning.options("LuaJIT 2.1.1741730670", "arm64", "OSX"))
        assert.is_nil(tuning.options("LuaJIT 2.1.1788856981", "x64", "OSX"))
        assert.is_nil(tuning.options("LuaJIT 2.1.1788856981", "arm64", "Linux"))
    end)
end)
