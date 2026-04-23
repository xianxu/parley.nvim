-- Copy commands: code fences, file locations, and context to clipboard.
-- Pure utility module — no parley module dependencies.

local M = {}

--- Copy the content of the code fence surrounding the cursor to the system clipboard.
function M.copy_code_fence()
	local buf = vim.api.nvim_get_current_buf()
	local cursor_row = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed
	local line_count = vim.api.nvim_buf_line_count(buf)

	-- Scan up for opening ```
	local fence_start = nil
	for i = cursor_row, 1, -1 do
		local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
		if line:match("^%s*```") then
			fence_start = i
			break
		end
	end

	if not fence_start then
		vim.notify("Not inside a code fence", vim.log.levels.WARN)
		return
	end

	-- The opening ``` must be above or at cursor; if cursor is ON the opening line,
	-- content starts on the next line. Scan down for closing ```.
	local fence_end = nil
	for i = fence_start + 1, line_count do
		local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
		if line:match("^%s*```") then
			fence_end = i
			break
		end
	end

	if not fence_end then
		vim.notify("No closing ``` found for code fence", vim.log.levels.WARN)
		return
	end

	-- Cursor must be between the fences (inclusive of delimiter lines)
	if cursor_row < fence_start or cursor_row > fence_end then
		vim.notify("Not inside a code fence", vim.log.levels.WARN)
		return
	end

	-- Extract content between the delimiters (exclusive)
	local content_lines = vim.api.nvim_buf_get_lines(buf, fence_start, fence_end - 1, false)
	local text = table.concat(content_lines, "\n")
	vim.fn.setreg("+", text)
	vim.notify(#content_lines .. " line(s) copied from code fence", vim.log.levels.INFO)
end

--- Copy filename:line (normal) or filename:range (visual) to system clipboard.
function M.copy_location()
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then
		local filename = vim.fn.expand("%:p")
		local start_line = vim.fn.line("v")
		local end_line = vim.fn.line(".")
		if start_line > end_line then
			start_line, end_line = end_line, start_line
		end
		vim.fn.setreg("+", string.format("%s:%d-%d", filename, start_line, end_line))
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
	else
		vim.fn.setreg("+", vim.fn.expand("%:p") .. ":" .. vim.fn.line("."))
	end
end

--- Copy filename:line + content (normal) or filename:range + content (visual) to system clipboard.
function M.copy_location_content()
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then
		local filename = vim.fn.expand("%:p")
		local start_line = vim.fn.line("v")
		local end_line = vim.fn.line(".")
		if start_line > end_line then
			start_line, end_line = end_line, start_line
		end
		local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
		local output = string.format("%s:%d-%d\n%s", filename, start_line, end_line, table.concat(lines, "\n"))
		vim.fn.setreg("+", output)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
	else
		local filename = vim.fn.expand("%:p")
		local line_num = vim.fn.line(".")
		local line_content = vim.fn.getline(".")
		vim.fn.setreg("+", string.format("%s:%d\n%s", filename, line_num, line_content))
		vim.notify("Copied: " .. filename .. ":" .. line_num, vim.log.levels.INFO)
	end
end

--- Copy location + selected text query + surrounding context to clipboard.
--- @param before integer lines of context before cursor/selection
--- @param after integer lines of context after cursor/selection
function M.copy_context(before, after)
	local buf = vim.api.nvim_get_current_buf()
	local filename = vim.fn.expand("%:p")
	local line_count = vim.api.nvim_buf_line_count(buf)
	local mode = vim.fn.mode()

	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1], cursor[2]

	local function context_lines(from, to)
		local start = math.max(1, from - before)
		local finish = math.min(line_count, to + after)
		return vim.api.nvim_buf_get_lines(buf, start - 1, finish, false), start
	end

	if mode == "v" or mode == "V" or mode == "\22" then
		local start_line = vim.fn.line("v")
		local end_line = vim.fn.line(".")
		if start_line > end_line then
			start_line, end_line = end_line, start_line
		end
		local sel_lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
		local selection = table.concat(sel_lines, "\n")
		local ctx, ctx_start = context_lines(start_line, end_line)

		local parts = {
			string.format("%s:%d:%d", filename, row, col + 1),
			"",
			string.format("tell me more about `%s`", selection),
			"",
		}
		for i, line in ipairs(ctx) do
			table.insert(parts, string.format("%d: %s", ctx_start + i - 1, line))
		end

		vim.fn.setreg("+", table.concat(parts, "\n"))
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
	else
		local ctx, ctx_start = context_lines(row, row)
		local parts = {
			string.format("%s:%d:%d", filename, row, col + 1),
			"",
		}
		for i, line in ipairs(ctx) do
			table.insert(parts, string.format("%d: %s", ctx_start + i - 1, line))
		end

		vim.fn.setreg("+", table.concat(parts, "\n"))
	end
	vim.notify("Context copied to clipboard", vim.log.levels.INFO)
end

return M
