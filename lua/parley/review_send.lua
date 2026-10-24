-- Alt+Return submits Couch documents through S1's registered coordinator.
-- Outside Couch, request the existing local review without standing instructions.
-- This module owns no peer transport, payload builder or diff baseline.

local frontmatter = require("parley.frontmatter")
local instruction = require("parley.skills.review.instruction")

local M = {}

M.KEY = "process-instruction"

local function notify(msg, level)
	vim.notify("review: " .. msg, level or vim.log.levels.INFO)
end

local function modes()
	local dir = (vim.api.nvim_get_runtime_file("lua/parley/skills/review/modes", false) or {})[1]
	return dir and require("parley.skills.review.mode").list(dir) or {}
end

--- <M-CR> in a markdown buffer.
M.submit = function(buf)
	if require("parley.agentic_document").submit(buf) then return end
	if require("parley.session_sync").is_session_sync(buf) then
		require("parley.session_sync").submit(buf)
		return
	end
	if vim.api.nvim_buf_get_name(buf) == "" then
		notify("save the file first: the agent reads it from disk", vim.log.levels.ERROR)
		return
	end
	notify("local review requested")
	require("parley.skills.review").run_via_invoke(buf, {})
end

--------------------------------------------------------------------------------
-- `[` completion in the process-instruction value
--------------------------------------------------------------------------------

local LINE = "^[Pp]rocess%-instruction:%s*"

--- The 1-based column where a mode name starts, when the text before the
--- cursor is the value's run of `[name]`s ending in an open `[`; else nil. PURE.
M.completion_start = function(before)
	local head = before:match(LINE .. '"?')
	if not head then
		return nil
	end
	local run = before:sub(#head + 1)
	if run:sub(-1) ~= "[" or run:sub(1, -2):gsub("%[[^%]]*%]", "") ~= "" then
		return nil
	end
	return #before + 1
end

--- The line once completion ended: the value quoted when it needs it (an
--- opened, unclosed quote gets its closing one), and the cursor column
--- (0-based) on the same text. PURE.
M.requote = function(line, col)
	local head = line:match(LINE)
	if not head then
		return nil
	end
	local opened = line:sub(#head + 1, #head + 1)
	if opened:match("[\"']") then
		if frontmatter.quoted_span(line:sub(#head + 1)) then
			return nil
		end
		return line .. opened, col
	end
	local value = line:sub(#head + 1)
	if not frontmatter.needs_quote(value) then
		return nil
	end
	local before = line:sub(#head + 1, col)
	local escaped = before:gsub("\\", "\\\\"):gsub('"', '\\"')
	return M.KEY .. ": " .. frontmatter.quote(value), #(M.KEY .. ": ") + 1 + #escaped
end

local function in_frontmatter(buf, row)
	local fm = frontmatter.parse(vim.api.nvim_buf_get_lines(buf, 0, 60, false))
	return fm ~= nil and row > 1 and row < fm.close
end

--- TextChangedI: offer the mode names after an `[` in the value.
M.on_text_changed = function(buf)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	local start = M.completion_start(line:sub(1, col))
	if not start or not in_frontmatter(buf, row) then
		return
	end
	vim.b[buf].parley_instruction_completing = true
	vim.fn.complete(start, instruction.complete(modes()))
end

--- CompleteDone: quote the value a strict YAML reader would reject.
M.on_complete_done = function(buf)
	if not vim.b[buf].parley_instruction_completing then
		return
	end
	vim.b[buf].parley_instruction_completing = false
	vim.schedule(function()
		if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_get_current_buf() ~= buf then
			return
		end
		local row, col = unpack(vim.api.nvim_win_get_cursor(0))
		local line, new_col = M.requote(vim.api.nvim_get_current_line(), col)
		if line then
			-- Cosmetic requoting; a refusal is quiet and leaves the line as typed (#265).
			if require("parley.buffer_edit").edit_user_lines("ReviewSend", buf, row - 1, row, { line },
				{ quiet = true }) then
				vim.api.nvim_win_set_cursor(0, { row, new_col })
			end
		end
	end)
end

--- Install the completion autocmds on a markdown buffer. Idempotent.
M.attach = function(buf)
	local group = vim.api.nvim_create_augroup("ParleyReviewSend" .. buf, { clear = true })
	vim.api.nvim_create_autocmd("TextChangedI", {
		group = group,
		buffer = buf,
		callback = function()
			M.on_text_changed(buf)
		end,
	})
	vim.api.nvim_create_autocmd("CompleteDone", {
		group = group,
		buffer = buf,
		callback = function()
			M.on_complete_done(buf)
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		buffer = buf,
		callback = function()
			pcall(vim.api.nvim_del_augroup_by_id, group)
		end,
	})
end

return M
