-- Unit tests for the draft-block scanner in highlighter.lua.
-- Covers the `=== <label> ===` / `=== end ===` convention used to mark
-- manuscript prose regions inside otherwise discussion-heavy markdown.

require("parley")
local highlighter = require("parley.highlighter")
local scan = highlighter._scan_draft_blocks

describe("scan_draft_blocks", function()
	it("matches a single block with markers + body", function()
		local blocks = scan({
			"before",
			"=== draft ===",
			"body 1",
			"body 2",
			"=== end ===",
			"after",
		})
		assert.equal(1, #blocks)
		assert.equal(1, blocks[1].open_row)
		assert.equal(4, blocks[1].close_row)
	end)

	it("ignores an unmatched closer", function()
		local blocks = scan({
			"before",
			"=== end ===",
			"after",
		})
		assert.equal(0, #blocks)
	end)

	it("extends an unmatched opener to EOF", function()
		local blocks = scan({
			"=== draft ===",
			"body",
		})
		assert.equal(1, #blocks)
		assert.equal(0, blocks[1].open_row)
		assert.equal(1, blocks[1].close_row)
	end)

	it("accepts arbitrary label names", function()
		local blocks = scan({
			"=== sketch ===",
			"body",
			"=== end ===",
		})
		assert.equal(1, #blocks)
		assert.equal(0, blocks[1].open_row)
		assert.equal(2, blocks[1].close_row)
	end)

	it("handles multiple sequential blocks", function()
		local blocks = scan({
			"=== a ===", "x", "=== end ===",
			"between",
			"=== b ===", "y", "=== end ===",
		})
		assert.equal(2, #blocks)
		assert.equal(0, blocks[1].open_row)
		assert.equal(2, blocks[1].close_row)
		assert.equal(4, blocks[2].open_row)
		assert.equal(6, blocks[2].close_row)
	end)

	it("does not nest — a second opener inside an open block is ignored", function()
		local blocks = scan({
			"=== draft ===",
			"=== sketch ===",
			"body",
			"=== end ===",
		})
		assert.equal(1, #blocks)
		assert.equal(0, blocks[1].open_row)
		assert.equal(3, blocks[1].close_row)
	end)

	it("requires exactly the === fence — does not match ==== or = ===", function()
		local blocks = scan({
			"==== draft ====",
			"body",
			"==== end ====",
		})
		assert.equal(0, #blocks)
	end)

	it("tolerates trailing whitespace on marker lines", function()
		local blocks = scan({
			"=== draft ===   ",
			"body",
			"=== end ===\t",
		})
		assert.equal(1, #blocks)
		assert.equal(0, blocks[1].open_row)
		assert.equal(2, blocks[1].close_row)
	end)

	it("returns empty for an empty buffer", function()
		assert.equal(0, #scan({}))
	end)
end)
