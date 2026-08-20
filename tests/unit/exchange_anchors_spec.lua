local anchors = require("parley.exchange_anchors")

describe("exchange_anchors", function()
    local buf

    before_each(function()
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "header", "💬: q1", "a1", "a2", "💬: q2", "b1", "b2", "💬: q3", "c1",
        })
    end)

    after_each(function()
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    it("spans an exchange from its own anchor to just before the next", function()
        anchors.set(buf, { 1, 4, 7 })
        assert.same({ 1, 3 }, { anchors.span(buf, 1, 3) })
        assert.same({ 4, 6 }, { anchors.span(buf, 2, 3) })
    end)

    it("runs the final exchange to the last line of the buffer", function()
        anchors.set(buf, { 1, 4, 7 })
        assert.same({ 7, 8 }, { anchors.span(buf, 3, 3) })
    end)

    -- The point of the extmark: it travels with edits, so a span stays correct
    -- when a model's remembered rows have gone stale.
    it("tracks its exchange across an insertion above it", function()
        anchors.set(buf, { 1, 4, 7 })
        vim.api.nvim_buf_set_lines(buf, 1, 1, false, { "inserted", "lines" })
        assert.same({ 6, 8 }, { anchors.span(buf, 2, 3) })
    end)

    it("tracks its exchange across a deletion above it", function()
        anchors.set(buf, { 1, 4, 7 })
        vim.api.nvim_buf_set_lines(buf, 2, 4, false, {})
        assert.same({ 2, 4 }, { anchors.span(buf, 2, 3) })
    end)

    -- Guards. Each of these is a way anchors could themselves alias.
    it("refuses when the model's exchange count disagrees with the anchors", function()
        anchors.set(buf, { 1, 4, 7 })
        assert.is_nil(anchors.span(buf, 2, 4))
    end)

    it("refuses when the anchor's own line was deleted", function()
        anchors.set(buf, { 1, 4, 7 })
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, {})
        assert.is_nil(anchors.span(buf, 2, 3))
    end)

    it("refuses when the NEXT anchor's line was deleted, rather than over-extending", function()
        anchors.set(buf, { 1, 4, 7 })
        vim.api.nvim_buf_set_lines(buf, 7, 8, false, {})
        assert.is_nil(anchors.span(buf, 2, 3))
    end)

    it("refuses when nothing has been anchored", function()
        assert.is_nil(anchors.span(buf, 1, 3))
    end)

    it("drops previous anchors when re-set", function()
        anchors.set(buf, { 1, 4, 7 })
        anchors.set(buf, { 1, 7 })
        assert.same({ 1, 6 }, { anchors.span(buf, 1, 2) })
        assert.is_nil(anchors.span(buf, 3, 3))
    end)

    it("forgets a buffer on clear", function()
        anchors.set(buf, { 1, 4, 7 })
        anchors.clear(buf)
        assert.is_nil(anchors.span(buf, 1, 3))
    end)
end)
