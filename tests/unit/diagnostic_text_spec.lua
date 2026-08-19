local diagnostic_text = require("parley.diagnostic_text")

local function wrap(text, width)
    return diagnostic_text.wrap_rows(text, width, vim.fn.strdisplaywidth)
end

describe("diagnostic_text.wrap_rows", function()
    it("wraps semantic text at word boundaries by display width", function()
        assert.are.same({ "alpha beta", "gamma", "delta" }, wrap("alpha beta gamma delta", 10))
    end)

    it("preserves explicit semantic rows, including empty trailing rows", function()
        assert.are.same({ "alpha", "", "beta", "" }, wrap("alpha\n\nbeta\n", 20))
    end)

    it("normalizes horizontal display whitespace without joining semantic rows", function()
        assert.are.same({ "alpha beta", "gamma" }, wrap("  alpha\t  beta  \n gamma ", 20))
    end)

    it("measures wide characters in display cells", function()
        local rows = wrap("界界 界界", 5)
        assert.are.same({ "界界", "界界" }, rows)
        for _, row in ipairs(rows) do
            assert.is_true(vim.fn.strdisplaywidth(row) <= 5)
        end
    end)

    it("splits overlong UTF-8 tokens at valid accumulated-width boundaries", function()
        local combined = "e\204\129"
        local rows = wrap(combined .. combined .. combined, 2)
        assert.are.same({ combined .. combined, combined }, rows)
        assert.are.equal(combined .. combined .. combined, table.concat(rows))
        for _, row in ipairs(rows) do
            assert.is_true(vim.fn.strdisplaywidth(row) <= 2)
        end
    end)

    it("uses a minimum effective width of two display cells", function()
        assert.are.same({ "界", "界" }, wrap("界界", 0))
    end)
end)
