-- Integration tests for the review-diagnostic inline display toggle (#133 M6).

local dd = require("parley.skills.review.diag_display")

local function ns_cfg()
    return vim.diagnostic.config(nil, vim.api.nvim_create_namespace("parley_skill"))
end

describe("review.diag_display", function()
    after_each(function()
        dd.set(true) -- restore default for other specs
    end)

    it("toggles the enabled state", function()
        dd.set(true)
        assert.is_true(dd.is_enabled())
        assert.is_false(dd.toggle())
        assert.is_false(dd.is_enabled())
        assert.is_true(dd.toggle())
        assert.is_true(dd.is_enabled())
    end)

    it("configures virtual_lines current_line on parley's namespace when on; off when disabled", function()
        dd.set(true)
        local on = ns_cfg()
        assert.is_truthy(on.virtual_lines) -- { current_line = true }
        assert.is_false(on.virtual_text) -- inline single-line is never used
        dd.set(false)
        assert.is_false(ns_cfg().virtual_lines)
    end)
end)
