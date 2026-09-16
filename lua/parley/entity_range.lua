-- The structural unit under the cursor, as a value.
--
-- Pure: takes a parsed chat and a line array, never a buffer, so every rule
-- below is unit-testable without nvim state (ARCH-PURE). Two surfaces consume
-- it — the ae/ie/aE text objects and the :ParleyDelete* commands — and a
-- parity test pins them to identical results, which is only possible because
-- the range (including its blank-line policy) is decided here rather than in
-- either surface.
--
-- Five rules, each stated once:
--   1. Bounds     — one exchange-span definition: exchange_clipboard's.
--   2. Dispatch   — question anchor > heading line > paragraph, by line CLASS
--                   (not containment: every line of a chat is inside some
--                   exchange, so containment would make 2 and 3 unreachable).
--   3. Walk stops — a paragraph stops at blanks, headings AND structural
--                   markers, so it cannot swallow the 💬: line above it.
--   4. Blanks     — an outer range absorbs its trailing blank run (dap
--                   semantics); an inner range trims them. This is what makes
--                   the seam clean with no post-pass, which is what lets a
--                   native `d` and a programmatic delete agree byte-for-byte.
--   5. 📝 trim    — an EDGE trim only, and only when the question survives.
local heading = require("parley.markdown_heading")

local M = {}

--- The structural marker prefixes, read from config rather than hardcoded so
--- a configured chat_user_prefix keeps working (document.lexical owns the
--- vocabulary; this is the same set chat_parser calls structural).
local function structural_prefixes(config)
	local lexical = require("parley.document.lexical")
	local p = lexical.patterns(config or require("parley.config"))
	return {
		p.user_prefix, p.assistant_prefix, p.summary_prefix, p.reasoning_prefix,
		p.tool_use_prefix, p.tool_result_prefix, p.branch_prefix, p.local_prefix,
	}
end

local function is_blank(line)
	return line == nil or line:match("^%s*$") ~= nil
end

--- A line the paragraph walk must not cross: blank, heading, or structural.
local function is_wall(line, prefixes)
	if is_blank(line) or heading.level(line) then
		return true
	end
	for _, prefix in ipairs(prefixes) do
		if prefix and #prefix > 0 and line:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

--- Blank/heading/marker-delimited paragraph containing `row`.
--- `bounds` clamps the walk to an enclosing exchange.
local function paragraph_range(lines, row, bounds, prefixes)
	local lo = (bounds and bounds.first) or 1
	local hi = (bounds and bounds.last) or #lines
	if row < lo or row > hi or is_wall(lines[row], prefixes) then
		return nil
	end
	local first, last = row, row
	while first > lo and not is_wall(lines[first - 1], prefixes) do
		first = first - 1
	end
	while last < hi and not is_wall(lines[last + 1], prefixes) do
		last = last + 1
	end
	return { kind = "paragraph", first = first, last = last }
end

--- Section owned by the heading on `row`, through the line before the next
--- heading of equal or higher rank (level number <= this one), bounded.
--- "#" (1) outranks "##" (2), so a deeper heading is swallowed.
local function section_range(lines, row, bounds)
	local level = heading.level(lines[row])
	if not level then
		return nil
	end
	local hi = (bounds and bounds.last) or #lines
	local last = row
	for i = row + 1, hi do
		local other = heading.level(lines[i])
		if other and other <= level then
			break
		end
		last = i
	end
	return { kind = "section", first = row, last = last }
end

--- Extend over the blank run that follows, bounded (dap semantics).
local function absorb_trailing_blanks(range, lines, bounds)
	local hi = (bounds and bounds.last) or #lines
	while range.last < hi and is_blank(lines[range.last + 1]) do
		range.last = range.last + 1
	end
	return range
end

--- Inverse of absorb: pull back off trailing blanks (inner semantics).
local function trim_trailing_blanks(range, lines)
	while range.last > range.first and is_blank(lines[range.last]) do
		range.last = range.last - 1
	end
	return range
end

--- Exchange index + its span for `row`. ONE span definition (rule 1):
--- get_exchange_line_range. find_exchange_at_line bounds an exchange at
--- answer.line_end, so a row in the trailing gap between that and the next
--- question needs the fallback scan, or it escapes into an unbounded walk.
local function exchange_at(parsed, lines, row)
	if not parsed or not parsed.exchanges then
		return nil
	end
	local exchange_clipboard = require("parley.exchange_clipboard")
	local idx = require("parley.chat_parser").find_exchange_at_line(parsed, row)
	if not idx then
		for i in ipairs(parsed.exchanges) do
			local s, e = exchange_clipboard.get_exchange_line_range(parsed, i, #lines)
			if s and e and row >= s and row <= e then
				idx = i
				break
			end
		end
	end
	if not idx then
		return nil
	end
	local first, last = exchange_clipboard.get_exchange_line_range(parsed, idx, #lines)
	if not first or not last then
		return nil
	end
	return idx, { first = first, last = last }
end

--- True when `row` is the question's own anchor: the 💬: line or its preface.
local function on_question_line(parsed, idx, row)
	local ex = parsed.exchanges[idx]
	if not ex or not ex.question then
		return false
	end
	local start = require("parley.question_tags").semantic_start(ex)
	return row >= start and row <= ex.question.line_end
end

--- Rule 5. Runs AFTER absorption, never before.
local function summary_trim(range, parsed, idx, lines)
	if not idx or range.kind == "question" then
		return range
	end
	local summary = parsed.exchanges[idx] and parsed.exchanges[idx].summary
	if not summary or not summary.line then
		return range
	end
	local sl = summary.line
	-- Edge trim only. `sl > range.first` keeps the range from inverting when
	-- the cursor is ON the summary line; the all-blank tail is what makes this
	-- an edge trim rather than an interior skip (a stock `d` over a text
	-- object cannot skip an interior line, so an interior 📝 goes).
	if sl <= range.first or sl > range.last then
		return range
	end
	for i = sl + 1, range.last do
		if not is_blank(lines[i]) then
			return range
		end
	end
	range.last = sl - 1
	return range
end

--- The structural unit under the cursor.
--- @param parsed table|nil  parsed chat, or nil for a plain markdown buffer
--- @param lines table       1-based array of buffer lines
--- @param row number        1-based cursor row
--- @param opts table|nil    { scope = "entity"|"to_end", inner = boolean,
---                             config = merged parley config (defaults used
---                             when absent, so a caller with a configured
---                             chat_user_prefix must pass it) }
--- @return table|nil        { kind, first, last }, or nil for "no entity here"
function M.range(parsed, lines, row, opts)
	opts = opts or {}
	if type(lines) ~= "table" or #lines == 0 then
		return nil
	end
	if type(row) ~= "number" or row < 1 or row > #lines then
		return nil
	end

	local idx, bounds = exchange_at(parsed, lines, row)
	local found

	if idx and on_question_line(parsed, idx, row) then
		found = { kind = "question", first = bounds.first, last = bounds.last }
		if opts.inner then
			found.last = parsed.exchanges[idx].question.line_end
		end
		-- A question range already spans to the next exchange; absorbing or
		-- trimming would either overrun it or eat its own trailing blank.
		if found.first > found.last then
			return nil
		end
		return found
	end

	found = section_range(lines, row, bounds)
	if found and opts.inner then
		found.first = found.first + 1
		if found.first > found.last then
			return nil
		end
		trim_trailing_blanks(found, lines)
	end

	if not found then
		found = paragraph_range(lines, row, bounds, structural_prefixes(opts.config))
		if not found then
			return nil
		end
		if opts.inner then
			trim_trailing_blanks(found, lines)
		end
	end

	if not opts.inner then
		absorb_trailing_blanks(found, lines, bounds)
	end

	if opts.scope == "to_end" then
		found.last = (bounds and bounds.last) or found.last
		if not bounds then
			-- Outside any exchange: the enclosing section's end, else EOF.
			local section = nil
			for i = found.first, 1, -1 do
				if heading.level(lines[i]) then
					section = section_range(lines, i, nil)
					break
				end
			end
			found.last = (section and section.last) or #lines
		end
	end

	summary_trim(found, parsed, idx, lines)

	if found.first > found.last or found.first < 1 or found.last > #lines then
		return nil
	end
	return found
end

return M
