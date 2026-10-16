-- #356: where a cursor or a top line lands when the text under it is rewritten.
local view_map = require("parley.view_map")

local function lines(s) return vim.split(s, "\n", { plain = true }) end

describe("view_map.map", function()
    local old = lines("one\ntwo\nthree\nfour\nfive")

    it("keeps the position when the edit is below it", function()
        local new = lines("one\ntwo\nthree\nfour\nFIVE\nsix")
        assert.same({ 2, 1 }, view_map.map(old, new, { 2, 1 }))
    end)

    it("shifts by the lines an edit above it added or removed", function()
        local added = lines("zero\nzero2\none\ntwo\nthree\nfour\nfive")
        assert.same({ 6, 2 }, view_map.map(old, added, { 4, 2 }))
        local removed = lines("three\nfour\nfive")
        assert.same({ 2, 2 }, view_map.map(old, removed, { 4, 2 }))
    end)

    it("counts an insertion directly above the line as above it", function()
        local new = lines("one\ntwo\nNEW\nthree\nfour\nfive")
        assert.same({ 4, 0 }, view_map.map(old, new, { 3, 0 }))
    end)

    it("inside a rewritten line, follows the text around the column", function()
        local o = lines("a\nthe quick brown fox jumps over the lazy dog\nz")
        local n = lines("a\nnote: the quick brown fox jumps over the lazy dog!\nz")
        -- the cursor sat on "fox" (0-based col 16); the line gained "note: " in front
        assert.same({ 2, 22 }, view_map.map(o, n, { 2, 16 }))
    end)

    it("inside a rewritten hunk, finds the text on whichever new line holds it", function()
        local o = lines("a\nalpha beta gamma\nz")
        local n = lines("a\nintro line\nalpha beta gamma delta\nz")
        assert.same({ 3, 6 }, view_map.map(o, n, { 2, 6 }))
    end)

    it("falls back to the text before the cursor when the text after it changed", function()
        local o = lines("a\nkeep this part|old tail\nz")
        local n = lines("a\nkeep this part|brand new ending here\nz")
        assert.same({ 2, 14 }, view_map.map(o, n, { 2, 14 }))
    end)

    it("with no text to follow, goes to the hunk's new start, column 0", function()
        local o = lines("a\nqqq\nz")
        local n = lines("a\nentirely\ndifferent\nz")
        assert.same({ 2, 0 }, view_map.map(o, n, { 2, 2 }))
    end)

    it("on a deleted line, goes to the line after the deletion, clamped", function()
        local o = lines("a\nb\nc")
        assert.same({ 2, 0 }, view_map.map(o, lines("a\nc"), { 2, 0 }))
        assert.same({ 2, 0 }, view_map.map(o, lines("a\nb"), { 3, 0 }))
    end)

    it("leaves an unchanged text as it is", function()
        assert.same({ 3, 4 }, view_map.map(old, old, { 3, 4 }))
    end)
end)

describe("view_map.map_line", function()
    it("maps a top line without searching text", function()
        local o = lines("1\n2\n3\n4\n5\n6")
        assert.equals(5, view_map.map_line(o, lines("0\n00\n1\n2\n3\n4\n5\n6"), 3))
        assert.equals(3, view_map.map_line(o, lines("1\n2\n3\n4\n5\nX"), 3))
        assert.equals(2, view_map.map_line(o, lines("1\nnew\n4\n5\n6"), 3))
    end)
end)
