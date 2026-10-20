-- #395: the #294 exemption's classification, pinned without needing real load.
local Oracle = require("tests.helpers.jit_oracle")

describe("jit trace oracle", function()
    it("names LuaJIT's own mcode-allocation error text", function()
        assert.is_true(vim.tbl_contains(require("jit.vmdef").traceerr, Oracle.MCODE_ERROR))
    end)

    it("blames the mcode defect only for a zero with at least one mcode abort", function()
        local ordinary = { "inner loop in root trace", "leaving loop in root trace", "loop unroll limit reached" }
        -- The mcode error among ordinary recording aborts: the defect.
        assert.is_true(Oracle.mcode_blocked(0, vim.list_extend({ Oracle.MCODE_ERROR }, ordinary)))
        assert.is_true(Oracle.mcode_blocked(0, { Oracle.MCODE_ERROR }))
        -- Ordinary aborts alone, or none: a real failure.
        assert.is_false(Oracle.mcode_blocked(0, ordinary))
        assert.is_false(Oracle.mcode_blocked(0, {}))
        assert.is_false(Oracle.mcode_blocked(0, nil))
        -- A completed trace needs no explanation.
        assert.is_false(Oracle.mcode_blocked(1, { Oracle.MCODE_ERROR }))
    end)
end)
