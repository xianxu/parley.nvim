-- Where a new, empty question goes -- as a value.
--
-- Pure: takes a parsed chat and a line array, never a buffer, so every rule
-- below is unit-testable without nvim state (ARCH-PURE). The insertion point
-- and the blank-line seam are NOT decided here: they come from
-- exchange_clipboard, which already owns "where does this exchange end" for
-- <C-g>V (ARCH-DRY). One definition means a pasted exchange and a new
-- question land with identical spacing.
--
-- Post-condition, in both branches: after the shell applies the returned plan,
-- the line at `row` is the user prefix followed by a space. That is what makes
-- `startinsert!` at end-of-line produce `💬: text` rather than `💬:text`.
local clipboard = require("parley.exchange_clipboard")

local M = {}

--- An unanswered question whose body is blank.
--- `user_prefix` is OPERATOR CONFIG: compared with sub(), never interpolated
--- into a pattern, so a prefix containing `%`, `.` or `-` behaves like any
--- other string (ARCH-SECURE; cf. init.lua's #214 BR-34 comment).
function M.is_empty_question(lines, exchange, user_prefix)
	if not exchange or not exchange.question or exchange.answer then
		return false
	end
	local first = exchange.question.line_start
	local last = exchange.question.line_end or first
	local head = lines[first]
	if not head or head:sub(1, #user_prefix) ~= user_prefix then
		return false
	end
	if head:sub(#user_prefix + 1):match("^%s*$") == nil then
		return false
	end
	for i = first + 1, last do
		if lines[i] and lines[i]:match("^%s*$") == nil then
			return false
		end
	end
	return true
end

--- The exchange containing `cursor_line`, or nil when the cursor is outside
--- every exchange. The SCAN belongs to exchange_clipboard, which already had
--- it inside get_paste_line; re-deriving it here was the second finding in the
--- same ARCH-DRY family in one review round (#263 close round 2).
local function exchange_at(parsed_chat, cursor_line, total_lines)
	local at = clipboard.exchange_index_at(parsed_chat, cursor_line, total_lines)
	return at and parsed_chat.exchanges[at] or nil
end

--- @return table plan
---   { kind = "insert", after = N, lines = {…}, row = R } -- insert after line N
---   { kind = "focus",  lines = {…}|nil,        row = R } -- replace row, or nothing
function M.plan(parsed_chat, lines, cursor_line, header_end, user_prefix)
	local total = #lines
	local question = user_prefix .. " "

	local current = exchange_at(parsed_chat, cursor_line, total)
	if M.is_empty_question(lines, current, user_prefix) then
		local row = current.question.line_start
		-- Already `💬: ` or `💬:   ` -- nothing to write, just go there.
		-- The test is "prefix then a SPACE", not "prefix then anything": a
		-- `💬:\t` line is whitespace-only to is_empty_question but would leave
		-- startinsert! producing `💬:\thello`. A tab is not the separator the
		-- post-condition promises.
		if lines[row]:sub(#user_prefix + 1, #user_prefix + 1) == " " then
			return { kind = "focus", row = row }
		end
		-- Bare `💬:`, or `💬:` followed by some other whitespace -- normalize to
		-- the one shape the post-condition names.
		return { kind = "focus", row = row, lines = { question } }
	end

	local after = clipboard.get_paste_line(parsed_chat, cursor_line, header_end, total)
	local insert = clipboard.build_paste_lines(lines, after, { question }, total)
	local row
	for i, l in ipairs(insert) do
		if l == question then
			row = after + i
			break
		end
	end
	return { kind = "insert", after = after, lines = insert, row = row }
end

return M
