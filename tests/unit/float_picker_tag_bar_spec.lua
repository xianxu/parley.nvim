local compute_layout = require("parley.float_picker").compute_layout

describe("float_picker facet bar geometry", function()
    it("adds numeric facet content height and two border rows to the visible stack", function()
        local win_w, win_h, row, col, tag_bar_row, prompt_row, facet_h =
            compute_layout(50, 10, { width = 100, height = 40 }, 3)

        assert.are.same({ 50, 10, 10, 25 }, { win_w, win_h, row, col })
        assert.equals(22, tag_bar_row)
        assert.equals(3, facet_h)
        assert.equals(tag_bar_row + facet_h + 2, prompt_row)
    end)

    it("shrinks results for the facet stack without going below one row", function()
        local _, shrunk_h = compute_layout(50, 50, { width = 100, height = 20 }, 3)
        local _, minimum_h, _, _, _, _, facet_h =
            compute_layout(50, 50, { width = 100, height = 15 }, 99)

        assert.equals(4, shrunk_h)
        assert.equals(1, minimum_h)
        assert.equals(1, facet_h)
    end)

    it("caps excessive facet height after reserving margins, prompt, borders, and results", function()
        local _, win_h, row, _, tag_bar_row, prompt_row, facet_h =
            compute_layout(50, 50, { width = 100, height = 18 }, 99)

        assert.equals(4, facet_h)
        assert.equals(1, win_h)
        assert.equals(3, row)
        assert.equals(6, tag_bar_row)
        assert.equals(12, prompt_row)
    end)

    it("keeps false and nil on the exact historical non-faceted geometry", function()
        local expected = { 70, 6, 6, 5, nil, 14, 0 }

        assert.are.same(expected, { compute_layout(70, 6, { width = 80, height = 24 }, false) })
        assert.are.same(expected, { compute_layout(70, 6, { width = 80, height = 24 }, nil) })
    end)

    it("treats true as the legacy one-row facet height", function()
        local legacy = { compute_layout(50, 10, { width = 100, height = 40 }, true) }
        local numeric = { compute_layout(50, 10, { width = 100, height = 40 }, 1) }

        assert.are.same(numeric, legacy)
        assert.equals(1, legacy[7])
    end)
end)
