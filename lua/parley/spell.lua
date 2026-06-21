-- parley/spell.lua — as-you-type spell-suggestion typeahead for chat buffers.
--
-- Ported (single concern) from pair/nvim/init.lua's `spell_complete`: when the
-- user types a misspelled word, pop a completion menu of `spellsuggest()`
-- results so a word you can't spell precisely is one Tab away. Plugin-free —
-- built on Neovim's built-in `spellbadword`/`spellsuggest`, which work even
-- with the `spell` option off (so the typeahead and the visible squiggles are
-- independently gateable; see config.chat_spell).
--
-- Pure core (no vim deps): word_at_cursor, cr_keys — unit-tested directly.
-- IO seam (require vim): suggest, attach — exercised by an integration test.

local helper = require("parley.helper")

local M = {}

--------------------------------------------------------------------------------
-- Pure core
--------------------------------------------------------------------------------

-- The alphabetic word ending at the cursor, or nil when there's nothing to
-- complete. `col` is the 0-indexed byte position of the cursor (i.e.
-- `vim.fn.col(".") - 1`): the count of bytes to the left of the insertion point.
--
-- Returns `start, word` where `start` is the 1-indexed byte column at which the
-- word begins — the span `complete()` will replace. We bail (return nil) when:
--   * the cursor is at column 0 (no word yet), or
--   * the char *at* the cursor is alphabetic — the cursor sits inside a word, and
--     replacing start..cursor would strand the tail, mangling a mid-word edit.
-- A word char is `[%a']` (letters + apostrophe), matching how the spellchecker
-- bounds words (so "don't", "wasn't" stay whole).
---@param line string # the current line text
---@param col number # 0-indexed byte position of the cursor
---@return number|nil start # 1-indexed start column of the word
---@return string|nil word # the word ending at the cursor
function M.word_at_cursor(line, col)
	if col == 0 then
		return nil
	end
	-- Char at the cursor (1-indexed col+1). Alphabetic ⇒ mid-word ⇒ bail.
	if line:sub(col + 1, col + 1):match("[%a']") then
		return nil
	end
	local start = col + 1
	while start > 1 and line:sub(start - 1, start - 1):match("[%a']") do
		start = start - 1
	end
	local word = line:sub(start, col)
	if word == "" then
		return nil
	end
	return start, word
end

-- What <CR> should feed in insert mode given the completion-popup state. Pure
-- (two booleans + a base string → a key string) so it's unit-testable without a
-- live popup. Under `completeopt=noselect` nothing is ever auto-highlighted, so
-- the common case is "menu up, nothing picked" — and there a bare <CR> only
-- closes the menu, swallowing the newline. <C-e> cancels completion (keeping
-- exactly what was typed) so the `base` that follows is processed normally.
--   no popup            → base         the normal newline (see `base`)
--   popup + selection   → <C-y>        accept the highlighted item
--   popup, no selection → <C-e>base    dismiss the menu, THEN the normal newline
-- `base` is what <CR> would do absent any popup — `<CR>` by default, but the
-- buffer-local map injects an interview-aware base (a timestamped newline) so
-- that shadowing the global interview <CR> map doesn't drop timestamps (#134).
---@param visible boolean # is the completion popup showing
---@param has_selection boolean # is an item highlighted
---@param base string|nil # no-popup keys (default "<CR>")
---@return string # keys to feed
function M.cr_keys(visible, has_selection, base)
	base = base or "<CR>"
	if not visible then
		return base
	end
	if has_selection then
		return "<C-y>"
	end
	return "<C-e>" .. base
end

--------------------------------------------------------------------------------
-- IO seam
--------------------------------------------------------------------------------

-- Per-keystroke handler (TextChangedI/P). Pops a spell-suggestion menu for the
-- misspelled word being typed in the current buffer, or does nothing. Returns
-- true iff it opened a menu (handy for tests / composing with other completers).
---@param opts table|nil # { min_word, max_suggest }
---@return boolean|nil
function M.suggest(opts)
	opts = opts or {}
	local min_word = opts.min_word or 4
	local max_suggest = opts.max_suggest or 9

	local line = vim.api.nvim_get_current_line()
	local col = vim.fn.col(".") - 1
	local start, word = M.word_at_cursor(line, col)
	if not word or #word < min_word then
		return
	end

	local bad = vim.fn.spellbadword(word)
	if not bad or bad[1] == "" then
		return -- correctly spelled → nothing to suggest
	end

	local suggestions = vim.fn.spellsuggest(word, max_suggest)
	if not suggestions or #suggestions == 0 then
		return
	end

	helper.complete_noselect(start, suggestions)
	return true
end

-- Wire spell support onto a chat buffer. `opts` is config.chat_spell:
--   enable          → turn on visible spell underlines (window-local `spell`)
--   typeahead       → attach the as-you-type suggestion menu + <CR> handling
--   spelllang       → spell language (default en_us)
--   min_word        → min misspelled-word length before suggesting
--   max_suggest     → max suggestions in the menu
--   prompt_buf_type → buffer uses 'prompt' type (<CR> is owned by respond); when
--                     set, skip the <CR> map so we don't shadow the prompt.
--   base_cr         → function returning the no-popup <CR> keys (injected by the
--                     caller so this module stays decoupled from interview mode).
-- `enable` is opt-in, `typeahead` is opt-out (nil ⇒ on) — matching the defaults-on
-- config; a partial `chat_spell = { enable = true }` still gets typeahead.
-- spelllang is set unconditionally because spellsuggest()/spellbadword() read it
-- even when `spell` is off (typeahead-only mode still needs a language).
---@param buf number # buffer handle
---@param opts table|nil
function M.attach(buf, opts)
	opts = opts or {}
	local lang = opts.spelllang or "en_us"

	vim.api.nvim_buf_call(buf, function()
		vim.cmd("setlocal spelllang=" .. lang)
		if opts.enable then
			vim.cmd("setlocal spell")
		end
	end)

	if opts.typeahead == false then
		return
	end

	local group = vim.api.nvim_create_augroup("ParleySpell_" .. buf, { clear = true })
	vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
		group = group,
		buffer = buf,
		callback = function()
			M.suggest(opts)
		end,
		desc = "parley: spell-suggestion typeahead",
	})

	-- A bare <CR> over a no-selection menu swallows the newline (completeopt
	-- noselect). Route it through cr_keys. The no-popup base defers to the
	-- injected base_cr (interview-aware) so this buffer-local map — which shadows
	-- interview's global <CR> map — preserves timestamp insertion (#134). Skipped
	-- for prompt buffers where <CR> already triggers respond.
	local base_cr = opts.base_cr
	if not opts.prompt_buf_type then
		vim.keymap.set("i", "<CR>", function()
			local visible = vim.fn.pumvisible() == 1
			local has_selection = vim.fn.complete_info({ "selected" }).selected ~= -1
			local base = base_cr and base_cr() or "<CR>"
			return M.cr_keys(visible, has_selection, base)
		end, { buffer = buf, expr = true, silent = true, desc = "parley: accept spell suggestion / newline" })
	end
end

return M
