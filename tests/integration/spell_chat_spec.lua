-- Integration tests for parley.spell — exercises the live IO seam (attach +
-- suggest) in a real Neovim buffer/window: the spell option wiring, the
-- TextChangedI/P autocmd + <CR> keymap, and a real spellsuggest() popup.

local spell = require("parley.spell")

-- Fresh buffer displayed in the current window (window-local `spell` needs the
-- buffer shown to take effect on the right window).
local function make_buf()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, buf)
	return buf
end

-- True iff buffer `buf` has an insert-mode <CR> mapping carrying our desc.
local function has_cr_map(buf)
	for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "i")) do
		if m.desc and m.desc:match("spell suggestion") then
			return true
		end
	end
	return false
end

-- Count of our typeahead autocmds on `buf` (queried by event+buffer so it works
-- even when the augroup was never created, i.e. typeahead disabled).
local function typeahead_autocmds(buf)
	local n = 0
	for _, a in ipairs(vim.api.nvim_get_autocmds({ event = { "TextChangedI", "TextChangedP" }, buffer = buf })) do
		if a.desc and a.desc:match("spell%-suggestion typeahead") then
			n = n + 1
		end
	end
	return n
end

describe("parley.spell integration", function()
	after_each(function()
		pcall(vim.cmd, "stopinsert")
	end)

	describe("attach", function()
		it("turns on spell + spelllang when enabled", function()
			local buf = make_buf()
			spell.attach(buf, { enable = true, typeahead = true, spelllang = "en_us" })
			assert.is_true(vim.wo[0].spell)
			assert.equals("en_us", vim.bo[buf].spelllang)
		end)

		it("sets spelllang but not spell in typeahead-only mode", function()
			local buf = make_buf()
			vim.wo[0].spell = false
			spell.attach(buf, { enable = false, typeahead = true, spelllang = "en_us" })
			assert.is_false(vim.wo[0].spell)
			assert.equals("en_us", vim.bo[buf].spelllang)
		end)

		it("registers the typeahead autocmd + <CR> map", function()
			local buf = make_buf()
			spell.attach(buf, { enable = true, typeahead = true })
			assert.is_true(typeahead_autocmds(buf) > 0)
			assert.is_true(has_cr_map(buf))
		end)

		it("skips the <CR> map for prompt buffers", function()
			local buf = make_buf()
			spell.attach(buf, { enable = true, typeahead = true, prompt_buf_type = true })
			assert.is_false(has_cr_map(buf))
		end)

		-- The buffer-local <CR> map shadows interview's global <CR> map; it must
		-- still produce the injected base_cr (interview timestamp) when no popup
		-- is up, else interview-mode timestamps silently break in chat buffers (#134).
		it("CR map feeds the injected base_cr when no popup is up", function()
			local buf = make_buf()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
			spell.attach(buf, { enable = true, typeahead = true, base_cr = function() return "TS" end })
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<CR>", true, false, true), "x", true)
			assert.equals("TS", table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
		end)

		it("CR map inserts a plain newline with no base_cr and no popup", function()
			local buf = make_buf()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab" })
			spell.attach(buf, { enable = true, typeahead = true })
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A<CR>", true, false, true), "x", true)
			assert.equals(2, #vim.api.nvim_buf_get_lines(buf, 0, -1, false))
		end)

		it("does not wire typeahead when typeahead=false (squiggles only)", function()
			local buf = make_buf()
			spell.attach(buf, { enable = true, typeahead = false })
			assert.equals(0, typeahead_autocmds(buf))
			assert.is_false(has_cr_map(buf))
		end)
	end)

	describe("suggest", function()
		-- Drive suggest() from inside insert mode (complete() is Insert-mode only):
		-- map <F2> to call it, then `A<F2>` appends at end-of-line and fires it.
		-- The popup must be inspected INSIDE the callback — feedkeys' "x" flag
		-- appends an <Esc> that tears the menu down once it returns.
		local function suggest_at_eol(buf, opts)
			local result = {}
			vim.keymap.set("i", "<F2>", function()
				result.ok = spell.suggest(opts)
				result.items = vim.fn.complete_info({ "items" }).items
			end, { buffer = buf })
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A<F2>", true, false, true), "x", true)
			return result
		end

		it("pops a spellsuggest menu for a misspelled word", function()
			local buf = make_buf()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "recieve" })
			local result = suggest_at_eol(buf, { min_word = 4, max_suggest = 9 })
			assert.is_true(result.ok)
			assert.is_true(#result.items > 0)
			local words = {}
			for _, it in ipairs(result.items) do
				words[it.word] = true
			end
			assert.is_true(words["receive"] ~= nil, "expected 'receive' among suggestions")
		end)

		it("does nothing for a correctly spelled word", function()
			local buf = make_buf()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "receive" })
			local result = suggest_at_eol(buf, { min_word = 4 })
			assert.is_nil(result.ok)
			assert.equals(0, #result.items)
		end)

		it("does nothing for a word shorter than min_word", function()
			local buf = make_buf()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "teh" })
			local result = suggest_at_eol(buf, { min_word = 4 })
			assert.is_nil(result.ok)
		end)
	end)
end)
