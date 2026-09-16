-- Text-object surface over entity_range.
--
-- Selecting a linewise range and letting the native operator act on it is what
-- gives d/y/c/v/gq and dot-repeat from ONE range function, instead of a delete
-- command that every other verb would then have to duplicate.
--
-- Two pieces of editor state make this more than a one-liner. Both were found
-- by running them, and both are invisible to a test that only drives `dae` on
-- a flat buffer:
--
--   1. x-mode keeps its anchor. `V` inside an existing visual selection moves
--      only the cursor end, so `vae` would select from wherever the user
--      started rather than from the entity. Stock `vip` resets both ends; this
--      has to leave visual mode first. Same idiom as chat_exchange_cut.
--   2. `G` cannot enter a closed fold -- it snaps to the fold's first line,
--      silently widening the range. tool_folds closes 🔧:/📎: blocks in every
--      prepped chat buffer, so this is the ordinary case, not an edge one.
local M = {}

--- Parsed chat for `buf`, plus WHICH of the three cases we are in.
---
--- "not a chat" and "a chat that will not parse" must not collapse into one
--- nil: a plain markdown buffer legitimately has no exchanges, but a chat
--- whose header is mid-edit would silently lose its exchange clamp and start
--- taking ranges across 💬: boundaries with no log line. The caller refuses
--- the second case instead of degrading into markdown semantics.
---
--- Gates on the cheap _parley_bufs latch rather than not_chat(), which is
--- documented as sitting on keystroke paths.
--- @return table|nil parsed, string status  -- "markdown" | "chat" | "unparsable"
function M.parsed_for(buf, lines)
	local parley = require("parley")
	if not parley._parley_bufs or parley._parley_bufs[buf] ~= "chat" then
		return nil, "markdown"
	end
	local chat_parser = require("parley.chat_parser")
	local header_end = chat_parser.find_header_end(lines)
	if not header_end then
		return nil, "unparsable"
	end
	local ok, parsed = pcall(chat_parser.parse_chat, lines, header_end, parley.config)
	if not ok or not parsed then
		return nil, "unparsable"
	end
	return parsed, "chat"
end

--- Select the entity at the cursor as a linewise visual range.
--- @param scope string      "entity" | "to_end"
--- @param inner boolean|nil
function M.select(scope, inner)
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local parley = require("parley")
	local parsed, status = M.parsed_for(buf, lines)
	if status == "unparsable" then
		require("parley.logger").warning(
			"Parley: entity object needs a readable chat header (is the `---` separator intact?)")
		return
	end
	local range = require("parley.entity_range").range(parsed, lines, row, {
		scope = scope,
		inner = inner,
		config = parley.config,
	})
	if not range then
		return
	end
	if vim.fn.mode():match("^[vV\22]") then
		vim.cmd("normal! \27")
	end
	local foldenable = vim.wo.foldenable
	vim.wo.foldenable = false
	local ok, err = pcall(vim.cmd, ("normal! %dGV%dG"):format(range.first, range.last))
	vim.wo.foldenable = foldenable
	if not ok then
		error(err)
	end
end

return M
