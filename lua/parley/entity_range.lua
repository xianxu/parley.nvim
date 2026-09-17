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
--   6. Header floor — nothing at or above the transcript's `---` is an entity.
--                   `# topic:` is a valid level-1 heading that nothing
--                   outranks, so without this a section from line 1 runs to
--                   EOF and `dae` empties the file. The floor is derived from
--                   the DOCUMENT'S OWN SHAPE, never from how the buffer was
--                   classified: not_chat rejects for five reasons unrelated to
--                   shape (name not timestamped, under 5 lines, no topic
--                   header, ...), and a transcript that fails any of them is
--                   still a transcript whose header must not be deleted.
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

--- A line the paragraph walk must not cross: blank, heading, structural, or a
--- CODE FENCE. The fence is the same class of wall as a heading and for the
--- same reason the issue gave for rejecting strict `dap` parity: without it,
--- `dae` on a fence opener takes the opener and its first stanza and leaves a
--- bare closing fence behind, after which every following line of the
--- transcript renders as code.
local function is_wall(line, prefixes)
	if is_blank(line) or heading.level(line) then
		return true
	end
	-- ONE fence predicate, the same one code_block_memo itself uses. An earlier
	-- fix used fence.open_len here, which sees only column-zero backticks while
	-- the memo also sees ~~~ and indented fences -- so the wall and the
	-- in-block test disagreed and tilde fences still broke.
	if require("parley.document.lexical").is_fence_delim(line, true) then
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
--- `bounds` clamps the walk to an enclosing exchange; `floor` keeps it out of
--- the transcript header when there is no exchange to clamp against.
local function paragraph_range(lines, row, bounds, prefixes, floor)
	local lo = (bounds and bounds.first) or floor or 1
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
--- `in_code[i]` must gate EVERY heading read, not just the dispatch: a `# x`
--- inside a fenced code sample is not a heading, so it must not terminate a
--- section either -- otherwise the range ends ON the opening fence.
--- The effective heading level at `row`: nil inside a fenced block, because a
--- `# x` in a code sample is content. Stated ONCE -- it was spelled three
--- different ways, two of them behind a nil-guard no caller could reach.
local function heading_level_at(lines, row, in_code)
	if in_code[row] then
		return nil
	end
	return heading.level(lines[row])
end

local function section_range(lines, row, bounds, in_code)
	local level = heading_level_at(lines, row, in_code)
	if not level then
		return nil
	end
	-- No floor check here: M.range's row guard has already returned nil for
	-- anything above it, so a second test could not change the outcome.
	local hi = (bounds and bounds.last) or #lines
	local last = row
	for i = row + 1, hi do
		local other = heading_level_at(lines, i, in_code)
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

--- Rule 7 -- the fence post-condition, stated as BLOCK COVERAGE rather than
--- delimiter parity. Parity is the wrong property: a range holding one block's
--- closer and the next block's opener has an even count and splits both. The
--- real rule is that a range which touches any fence delimiter must contain
--- whole blocks -- it may not begin part-way into a block, nor end part-way
--- into one. A range entirely INSIDE a block (a paragraph in a code sample)
--- touches no delimiter and is fine.
---
--- Checked over the FINAL range at M.range's single exit, so it covers every
--- path -- the paragraph wall, the section scans, the question span, and
--- to_end's overwrite of `last` from the exchange bound long after the wall
--- has had its say. Three rounds of this bug were three walls at three call
--- sites; this is the one statement instead.
local function confine_to_blocks(range, lines, in_code, patterns)
	local is_fence = require("parley.document.lexical").is_fence_delim
	local touches = false
	for i = range.first, range.last do
		if is_fence(lines[i], true) then
			touches = true
			break
		end
	end
	if not touches then
		return range
	end
	-- Ends part-way into a block ONLY if that block is closed by a fence
	-- delimiter beyond the range. code_block_memo also resets at a partition
	-- (💬:/🤖:), so a block the next exchange closes is already whole -- and
	-- pulling back there truncated a whole-exchange delete and stranded answer
	-- content instead of protecting anything.
	local lexical = require("parley.document.lexical")
	local closed_beyond = false
	for i = range.last + 1, #lines do
		if lexical.is_partition(lines[i], patterns) then
			break
		end
		if is_fence(lines[i], true) then
			closed_beyond = true
			break
		end
	end
	if closed_beyond then
		while range.last >= range.first and in_code[range.last] do
			range.last = range.last - 1
		end
	end
	-- begins part-way into a block: the first row is inside one and is not its
	-- opener (an opener has in_code true with false on the line before it).
	-- Advance past that block's CLOSING delimiter -- walking only while the row
	-- is in_code stops ON the closer, which then gets deleted and strands the
	-- opener above the range (BR-37).
	if range.first <= range.last
		and in_code[range.first] and in_code[range.first - 1] then
		local closer = nil
		for i = range.first, range.last do
			if is_fence(lines[i], true) then
				closer = i
				break
			end
		end
		range.first = closer and (closer + 1) or (range.last + 1)
	end
	return range
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

	-- Rule 6. Everything at or above the `---` belongs to the header, which is
	-- metadata, not an entity -- and `# topic:` would otherwise be a level-1
	-- heading that swallows the whole transcript. Falling back to the document
	-- shape (not just `parsed`) is what makes this hold for a transcript the
	-- buffer classifier did NOT call a chat.
	local header_end = parsed and parsed.header_end
		or require("parley.chat_parser").transcript_header_end(lines)
	local floor = (header_end or 0) + 1
	if row < floor then
		return nil
	end

	-- A heading INSIDE a fenced block is content, not structure -- the same
	-- ruling outline.lua:32 already makes. Without this, `dae` on a `# x` in a
	-- code sample builds a section that runs past the closing fence, which is
	-- the fence bug again one level up (is_wall only guards the paragraph
	-- walk). Reuses highlight_structure's memo rather than re-scanning fences.
	local patterns = require("parley.document.lexical").patterns(
		opts.config or require("parley.config"))
	local in_code = require("parley.highlight_structure").code_block_memo(lines, patterns, true)

	local idx, bounds = exchange_at(parsed, lines, row)
	local found

	if idx and on_question_line(parsed, idx, row) then
		found = { kind = "question", first = bounds.first, last = bounds.last }
		if opts.inner then
			found.last = parsed.exchanges[idx].question.line_end
		end
		-- A question range already spans to the next exchange; absorbing or
		-- trimming would either overrun it or eat its own trailing blank. It
		-- still takes the fence post-condition below -- an exchange bound can
		-- fall inside an unterminated block.
		if found.first > found.last then
			return nil
		end
		confine_to_blocks(found, lines, in_code, patterns)
		return (found.first <= found.last) and found or nil
	end

	found = section_range(lines, row, bounds, in_code)
	if found and opts.inner then
		found.first = found.first + 1
		if found.first > found.last then
			return nil
		end
		trim_trailing_blanks(found, lines)
	end

	if not found then
		found = paragraph_range(lines, row, bounds, structural_prefixes(opts.config), floor)
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
			for i = found.first, floor, -1 do
				if heading_level_at(lines, i, in_code) then
					section = section_range(lines, i, nil, in_code)
					break
				end
			end
			found.last = (section and section.last) or #lines
		end
	end

	summary_trim(found, parsed, idx, lines)
	confine_to_blocks(found, lines, in_code, patterns)

	if found.first > found.last or found.first < floor or found.last > #lines then
		return nil
	end
	return found
end

return M
