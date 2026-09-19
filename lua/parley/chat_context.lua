-- The sequence every chat entry point runs before it can act: is this buffer a
-- chat, where does its header end, and what does the body parse to.
--
-- ONE owner for the sequence; the CALLER owns the reporting. This returns a
-- typed error and never speaks. init.lua's keystroke commands log a warning
-- naming the command and abort. chat_respond's entry points pass the reason to
-- `refuse`, which words it through parley.refusal (#261 M5): `respond` and
-- `respond_all` both warn, and both still return `nil, reason` to their
-- callers.
--
-- TWO PHASES, because respond_all interleaves its own precondition (is a batch
-- already running?) between the chat check and the parse. A single monolithic
-- resolve would reorder its messages -- a chat with no `---` AND an active
-- batch would start reporting the header instead of the batch.
--
-- #263 close round 3: this is the third finding in the
-- `duplicated-command-preamble` family. The first extraction stopped at
-- init.lua and the family came back; the rule now is that the sequence has one
-- owner reachable from any module, and `not_chat -> find_header_end ->
-- parse_chat` is not written out anywhere else. `delete_entity_range` is the
-- one deliberate exclusion: it classifies through `entity_textobj.parsed_for`
-- so the text objects and the :ParleyDelete* commands cannot disagree.
local M = {}

--- Phase 1: is this a chat buffer?
--- @return table|nil handle, string|nil reason
---   handle = { buf, win, file_name }
function M.chat_buffer(opts)
	opts = opts or {}
	local parley = opts.parley or require("parley")
	local buf = opts.buf or vim.api.nvim_get_current_buf()
	local win = opts.win or vim.api.nvim_get_current_win()
	local file_name = vim.api.nvim_buf_get_name(buf)

	local reason = parley.not_chat(buf, file_name)
	if reason then return nil, reason end
	return { buf = buf, win = win, file_name = file_name }
end

--- Phase 2: read, find the header, parse, and note the cursor.
--- @return table|nil ctx, string|nil reason  (reason is "no_header")
function M.parse(handle, opts)
	local parley = (opts and opts.parley) or require("parley")
	local lines = vim.api.nvim_buf_get_lines(handle.buf, 0, -1, false)
	local header_end = parley.chat_parser.find_header_end(lines)
	if not header_end then return nil, "no_header" end

	return {
		buf = handle.buf,
		win = handle.win,
		file_name = handle.file_name,
		lines = lines,
		header_end = header_end,
		parsed_chat = parley.parse_chat(lines, header_end),
		cursor_line = vim.api.nvim_win_get_cursor(handle.win)[1],
	}
end

--- Both phases, for the common case that has nothing to interleave.
--- @return table|nil ctx, string|nil reason, string|nil kind
---   kind is "not_chat" or "no_header", so a caller can phrase each one.
function M.resolve(opts)
	local handle, reason = M.chat_buffer(opts)
	if not handle then return nil, reason, "not_chat" end
	local ctx, why = M.parse(handle, opts)
	if not ctx then return nil, why, "no_header" end
	return ctx
end

return M
