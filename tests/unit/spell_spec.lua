-- Unit tests for the pure core of parley.spell (word_at_cursor, cr_keys).
-- No vim runtime behavior is exercised here — these are deterministic
-- string/boolean functions.

local spell = require("parley.spell")

describe("parley.spell", function()
	describe("word_at_cursor", function()
		-- col is the 0-indexed byte position of the cursor (vim.fn.col('.') - 1).
		it("returns the word ending at the cursor", function()
			local start, word = spell.word_at_cursor("hello teh", 9)
			assert.equals(7, start)
			assert.equals("teh", word)
		end)

		it("handles a word at the start of the line", function()
			local start, word = spell.word_at_cursor("teh", 3)
			assert.equals(1, start)
			assert.equals("teh", word)
		end)

		it("returns nil at column 0 (nothing typed yet)", function()
			assert.is_nil(spell.word_at_cursor("teh", 0))
		end)

		it("returns nil when the cursor sits inside a word (mid-word edit)", function()
			-- cursor between 't' and 'e' → char at cursor is alphabetic → bail
			assert.is_nil(spell.word_at_cursor("teh", 1))
		end)

		it("stops the word at non-word punctuation", function()
			local start, word = spell.word_at_cursor("(teh", 4)
			assert.equals(2, start)
			assert.equals("teh", word)
		end)

		it("treats an apostrophe as part of the word", function()
			local start, word = spell.word_at_cursor("ab'cd", 5)
			assert.equals(1, start)
			assert.equals("ab'cd", word)
		end)

		it("returns nil when the cursor follows a non-word char (no word)", function()
			-- line "teh " with cursor after the space → empty word
			assert.is_nil(spell.word_at_cursor("teh ", 4))
		end)
	end)

	describe("cr_keys", function()
		it("plain newline when no popup", function()
			assert.equals("<CR>", spell.cr_keys(false, false))
			assert.equals("<CR>", spell.cr_keys(false, true))
		end)

		it("accepts the highlighted item when a selection exists", function()
			assert.equals("<C-y>", spell.cr_keys(true, true))
		end)

		it("dismisses the menu then inserts a newline when nothing selected", function()
			assert.equals("<C-e><CR>", spell.cr_keys(true, false))
		end)

		it("feeds the injected base when no popup (interview timestamp case)", function()
			assert.equals("<CR><CR>:05min ", spell.cr_keys(false, false, "<CR><CR>:05min "))
		end)

		it("dismisses the menu then feeds the injected base when nothing selected", function()
			assert.equals("<C-e><CR><CR>:05min ", spell.cr_keys(true, false, "<CR><CR>:05min "))
		end)

		it("accepts the selection regardless of base", function()
			assert.equals("<C-y>", spell.cr_keys(true, true, "<CR><CR>:05min "))
		end)
	end)
end)
