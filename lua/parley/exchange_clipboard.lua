--------------------------------------------------------------------------------
-- exchange_clipboard.lua: pure functions for cutting and pasting chat exchanges.
--
-- An "exchange" is a question + answer pair. Its line range extends from
-- question.line_start through the last line before the next exchange starts
-- (including trailing blank lines and branch markers).
--------------------------------------------------------------------------------

local M = {}

--- Get the inclusive line range for a single exchange, including trailing
--- whitespace/branch lines that belong to it.
--- @param parsed_chat table  parsed chat from chat_parser.parse_chat
--- @param exchange_idx number  1-based exchange index
--- @param total_lines number  total line count in the buffer
--- @return number, number  start_line, end_line (1-based, inclusive)
M.get_exchange_line_range = function(parsed_chat, exchange_idx, total_lines)
	local ex = parsed_chat.exchanges[exchange_idx]
	if not ex then
		return nil, nil
	end

	local start_line = ex.question.line_start

	-- End line: if there's a next exchange, go up to (but not including) its question start.
	-- Otherwise, go to the end of the file.
	local next_ex = parsed_chat.exchanges[exchange_idx + 1]
	local end_line
	if next_ex then
		end_line = next_ex.question.line_start - 1
	else
		end_line = total_lines
	end

	return start_line, end_line
end

--- Find all exchange indices whose line ranges overlap [sel_start, sel_end].
--- @param parsed_chat table
--- @param sel_start number  1-based line number
--- @param sel_end number  1-based line number
--- @param total_lines number
--- @return table  sorted list of exchange indices
M.get_exchanges_for_range = function(parsed_chat, sel_start, sel_end, total_lines)
	local result = {}
	for i, ex in ipairs(parsed_chat.exchanges) do
		local ex_start = ex.question.line_start
		local ex_end
		local next_ex = parsed_chat.exchanges[i + 1]
		if next_ex then
			ex_end = next_ex.question.line_start - 1
		else
			ex_end = total_lines
		end

		-- Overlap check: ranges overlap if start <= other_end and end >= other_start
		if sel_start <= ex_end and sel_end >= ex_start then
			table.insert(result, i)
		end
	end
	return result
end

--- Get the line number after which to insert pasted exchanges.
--- Returns the end of the exchange the cursor is on, or (if cursor is before
--- all exchanges) the header_end line, or (if after all) total_lines.
--- @param parsed_chat table
--- @param cursor_line number  1-based cursor line
--- @param header_end number  header separator line
--- @param total_lines number
--- @return number  line number to insert after (0-based nvim_buf_set_lines start)
M.get_paste_line = function(parsed_chat, cursor_line, header_end, total_lines)
	-- Find the exchange the cursor is on
	for i, ex in ipairs(parsed_chat.exchanges) do
		local ex_start = ex.question.line_start
		local ex_end
		local next_ex = parsed_chat.exchanges[i + 1]
		if next_ex then
			ex_end = next_ex.question.line_start - 1
		else
			ex_end = total_lines
		end

		if cursor_line >= ex_start and cursor_line <= ex_end then
			return ex_end
		end
	end

	-- Cursor is not on any exchange — find nearest exchange before cursor
	local best_end = header_end
	for i, ex in ipairs(parsed_chat.exchanges) do
		local ex_end
		local next_ex = parsed_chat.exchanges[i + 1]
		if next_ex then
			ex_end = next_ex.question.line_start - 1
		else
			ex_end = total_lines
		end

		if ex.question.line_start <= cursor_line then
			best_end = ex_end
		end
	end
	return best_end
end

--- Extract lines for a contiguous range of exchanges.
--- Strips leading and trailing blank lines from the extracted content so that
--- the caller can re-insert with consistent spacing.
--- @param lines table  all buffer lines
--- @param parsed_chat table
--- @param exchange_indices table  sorted list of exchange indices
--- @param total_lines number
--- @return table extracted_lines, number start_line, number end_line (the full range deleted, including blanks)
M.extract_exchange_lines = function(lines, parsed_chat, exchange_indices, total_lines)
	if #exchange_indices == 0 then
		return {}, nil, nil
	end

	local first_start, _ = M.get_exchange_line_range(parsed_chat, exchange_indices[1], total_lines)
	local _, last_end = M.get_exchange_line_range(parsed_chat, exchange_indices[#exchange_indices], total_lines)

	-- The full range to delete includes trailing blanks
	local delete_end = last_end

	-- Strip trailing empty lines from extracted content
	local content_end = last_end
	while content_end > first_start and (lines[content_end] == nil or lines[content_end]:match("^%s*$")) do
		content_end = content_end - 1
	end

	-- Strip leading empty lines from extracted content
	local content_start = first_start
	while content_start < content_end and (lines[content_start] == nil or lines[content_start]:match("^%s*$")) do
		content_start = content_start + 1
	end

	local extracted = {}
	for i = content_start, content_end do
		table.insert(extracted, lines[i])
	end
	return extracted, first_start, delete_end
end

--- Compute the lines to insert at a paste point, ensuring exactly one blank line
--- separator before and after the pasted content.
--- @param buffer_lines table  current buffer lines
--- @param paste_after number  1-based line after which to insert
--- @param clipboard table  lines to paste (stripped of leading/trailing blanks)
--- @param total_lines number
--- @return table lines_to_insert
M.build_paste_lines = function(buffer_lines, paste_after, clipboard, total_lines)
	if #clipboard == 0 then
		return {}
	end

	-- Check if the line before insertion point is already blank
	local prev_blank = paste_after < 1
		or (buffer_lines[paste_after] and buffer_lines[paste_after]:match("^%s*$"))
	-- Check if the line after insertion point is blank or end of file
	local next_line = paste_after + 1
	local next_blank = next_line > total_lines
		or (buffer_lines[next_line] and buffer_lines[next_line]:match("^%s*$"))

	local result = {}

	-- Add blank separator before if needed
	if not prev_blank then
		table.insert(result, "")
	end

	-- Add the clipboard content
	for _, l in ipairs(clipboard) do
		table.insert(result, l)
	end

	-- Add blank separator after if needed (and there's content after)
	if next_line <= total_lines and not next_blank then
		table.insert(result, "")
	end

	return result
end

--- After cutting lines from a buffer, clean up consecutive blank lines at the
--- cut point. Returns the replacement lines for the seam region.
--- @param buffer_lines table  buffer lines AFTER the cut
--- @param cut_point number  1-based line where the cut happened (first line after deleted range)
--- @param total_lines number  total lines after cut
--- @return number seam_start, number seam_end, table replacement (1-based inclusive range to replace)
M.compute_cut_cleanup = function(buffer_lines, cut_point, total_lines)
	if total_lines == 0 then
		return nil, nil, nil
	end

	-- Find the run of blank lines around the cut point
	local blank_start = cut_point
	while blank_start > 1 and buffer_lines[blank_start - 1] and buffer_lines[blank_start - 1]:match("^%s*$") do
		blank_start = blank_start - 1
	end

	local blank_end = cut_point - 1
	while blank_end + 1 <= total_lines and buffer_lines[blank_end + 1] and buffer_lines[blank_end + 1]:match("^%s*$") do
		blank_end = blank_end + 1
	end

	local blank_count = blank_end - blank_start + 1
	if blank_count <= 1 then
		return nil, nil, nil -- already clean
	end

	-- Keep exactly one blank line
	return blank_start, blank_end, { "" }
end

return M
