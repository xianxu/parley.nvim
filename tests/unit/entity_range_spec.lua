local entity_range = require("parley.entity_range")
local chat_parser = require("parley.chat_parser")
local exchange_clipboard = require("parley.exchange_clipboard")
local cfg = require("parley.config")

local function parse(lines)
	return chat_parser.parse_chat(lines, chat_parser.find_header_end(lines), cfg)
end

describe("entity_range paragraph", function()
	it("takes the blank-delimited run plus its trailing blanks", function()
		local lines = { "alpha one", "alpha two", "", "beta one", "" }
		local r = entity_range.range(nil, lines, 1)
		assert.equals("paragraph", r.kind)
		assert.equals(1, r.first)
		assert.equals(3, r.last)
	end)

	it("stops at end of buffer without inventing a trailing blank", function()
		local r = entity_range.range(nil, { "alpha", "", "omega" }, 3)
		assert.equals(3, r.first)
		assert.equals(3, r.last)
	end)

	it("absorbs a multi-blank run", function()
		local r = entity_range.range(nil, { "alpha", "", "", "", "beta" }, 1)
		assert.equals(1, r.first)
		assert.equals(4, r.last)
	end)

	it("does not walk back over a heading with no blank between", function()
		local lines = { "## Sub", "body b", "", "next" }
		local r = entity_range.range(nil, lines, 2)
		assert.equals("paragraph", r.kind)
		assert.equals(2, r.first)
		assert.equals(3, r.last)
	end)

	it("does not walk back over a structural marker", function()
		local lines = { "💬: q", "body", "", "x" }
		local r = entity_range.range(nil, lines, 2)
		assert.equals(2, r.first)
	end)

	it("does not walk forward over a heading", function()
		local lines = { "body", "## Next", "more" }
		local r = entity_range.range(nil, lines, 1)
		assert.equals(1, r.first)
		assert.equals(1, r.last)
	end)

	it("inner drops the trailing blanks", function()
		local lines = { "alpha one", "alpha two", "", "beta" }
		local r = entity_range.range(nil, lines, 1, { inner = true })
		assert.equals(1, r.first)
		assert.equals(2, r.last)
	end)

	it("returns nil on a blank line", function()
		assert.is_nil(entity_range.range(nil, { "alpha", "", "", "beta" }, 2))
	end)
end)

describe("entity_range section", function()
	local lines = {
		"# Top",      -- 1
		"body a",     -- 2
		"",           -- 3
		"## Sub",     -- 4
		"body b",     -- 5
		"",           -- 6
		"### Deep",   -- 7
		"body c",     -- 8
		"",           -- 9
		"## Sibling", -- 10
		"body d",     -- 11
	}

	it("ends before the next same-or-higher heading", function()
		local r = entity_range.range(nil, lines, 4)
		assert.equals("section", r.kind)
		assert.equals(4, r.first)
		assert.equals(9, r.last)
	end)

	it("runs to end of buffer when nothing outranks it", function()
		local r = entity_range.range(nil, lines, 1)
		assert.equals(1, r.first)
		assert.equals(11, r.last)
	end)

	it("runs to end of buffer for the last section", function()
		local r = entity_range.range(nil, lines, 10)
		assert.equals(10, r.first)
		assert.equals(11, r.last)
	end)

	it("handles a heading with no body", function()
		local r = entity_range.range(nil, { "# A", "# B" }, 1)
		assert.equals(1, r.first)
		assert.equals(1, r.last)
	end)

	it("inner drops the heading line and trailing blanks", function()
		local r = entity_range.range(nil, lines, 4, { inner = true })
		assert.equals(5, r.first)
		assert.equals(8, r.last)
	end)

	it("returns nil for inner on a heading with no body", function()
		assert.is_nil(entity_range.range(nil, { "# A", "# B" }, 1, { inner = true }))
	end)

	it("treats a non-heading line as a paragraph, not its section", function()
		local r = entity_range.range(nil, lines, 5)
		assert.equals("paragraph", r.kind)
		assert.equals(5, r.first)
		assert.equals(6, r.last)
	end)
end)

describe("entity_range question", function()
	local lines = {
		"# topic: t",    -- 1
		"- file: t.md",  -- 2
		"---",           -- 3
		"",              -- 4
		"@@tag@@",       -- 5
		"💬: first q",   -- 6
		"",              -- 7
		"🤖: [A]",       -- 8
		"answer para",   -- 9
		"",              -- 10
		"## In answer",  -- 11
		"under heading", -- 12
		"",              -- 13
		"💬: second q",  -- 14
		"",              -- 15
		"🤖: [A]",       -- 16
		"second answer", -- 17
	}
	local parsed = parse(lines)

	it("takes the whole exchange from the question line", function()
		local r = entity_range.range(parsed, lines, 6)
		local es, ee = exchange_clipboard.get_exchange_line_range(parsed, 1, #lines)
		assert.equals("question", r.kind)
		assert.equals(es, r.first)
		assert.equals(ee, r.last)
	end)

	it("takes the whole exchange from the preface line", function()
		local r = entity_range.range(parsed, lines, 5)
		assert.equals("question", r.kind)
		assert.equals(5, r.first)
	end)

	it("takes a paragraph inside an answer, clamped to the exchange", function()
		local r = entity_range.range(parsed, lines, 9)
		assert.equals("paragraph", r.kind)
		assert.equals(9, r.first)
		assert.equals(10, r.last)
	end)

	it("takes a section inside an answer, clamped to the exchange", function()
		local r = entity_range.range(parsed, lines, 11)
		assert.equals("section", r.kind)
		assert.equals(11, r.first)
		assert.equals(13, r.last)
	end)

	it("inner question drops the answer", function()
		local r = entity_range.range(parsed, lines, 6, { inner = true })
		assert.equals(5, r.first)
		assert.equals(6, r.last)
	end)

	it("never returns a question kind in the header", function()
		local r = entity_range.range(parsed, lines, 1)
		assert.is_true(r == nil or r.kind ~= "question")
	end)
end)

describe("entity_range to_end", function()
	local lines = {
		"# topic: t",   -- 1
		"- file: t.md", -- 2
		"---",          -- 3
		"",             -- 4
		"💬: q one",    -- 5
		"",             -- 6
		"🤖: [A]",      -- 7
		"para one",     -- 8
		"",             -- 9
		"para two",     -- 10
		"",             -- 11
		"📝: summary",  -- 12
		"",             -- 13
		"💬: q two",    -- 14
		"",             -- 15
		"🤖: [A]",      -- 16
		"tail",         -- 17
	}
	local parsed = parse(lines)

	it("runs from the paragraph start to the summary edge", function()
		local r = entity_range.range(parsed, lines, 8, { scope = "to_end" })
		assert.equals(8, r.first)
		assert.equals(11, r.last)
	end)

	it("never crosses the next question", function()
		local r = entity_range.range(parsed, lines, 10, { scope = "to_end" })
		assert.equals(10, r.first)
		assert.is_true(r.last < 14)
	end)

	it("degenerates to the whole exchange on the question line", function()
		local a = entity_range.range(parsed, lines, 5, { scope = "to_end" })
		local b = entity_range.range(parsed, lines, 5)
		assert.same(b, a)
		assert.equals(13, a.last)
	end)

	it("does not invert when the cursor is on the summary line", function()
		local r = entity_range.range(parsed, lines, 12, { scope = "to_end" })
		assert.is_true(r == nil or r.first <= r.last)
		if r then assert.is_true(r.first >= 12) end
	end)

	it("takes an interior summary with the range", function()
		local mid = {
			"# topic: t", "- file: t.md", "---", "",
			"💬: q",       -- 5
			"",            -- 6
			"🤖: [A]",     -- 7
			"para A",      -- 8
			"📝: summary", -- 9
			"para B",      -- 10
		}
		local p2 = parse(mid)
		local r = entity_range.range(p2, mid, 8, { scope = "to_end" })
		assert.is_true(r.last >= 10)
	end)

	it("falls back to the enclosing section outside any exchange", function()
		-- # A is level 1 and ## B is level 2, so ## B is INSIDE A's section:
		-- "to end of the enclosing section" correctly runs to EOF here.
		local plain = { "# A", "body", "", "## B", "more" }
		local r = entity_range.range(nil, plain, 2, { scope = "to_end" })
		assert.equals(2, r.first)
		assert.equals(5, r.last)
	end)

	it("stops at the innermost enclosing section's end", function()
		local plain = {
			"# A",     -- 1
			"## B",    -- 2
			"body",    -- 3
			"",        -- 4
			"## C",    -- 5
			"more",    -- 6
		}
		local r = entity_range.range(nil, plain, 3, { scope = "to_end" })
		assert.equals(3, r.first)
		assert.equals(4, r.last)   -- ## B ends before ## C
	end)
end)

describe("entity_range header floor", function()
	-- `# topic:` is a valid level-1 heading that nothing outranks, so without a
	-- floor a section from line 1 runs to EOF and `dae` empties the file.
	local lines = {
		"# topic: t",   -- 1
		"- file: t.md", -- 2
		"---",          -- 3
		"",             -- 4
		"💬: q",        -- 5
		"",             -- 6
		"🤖: [A]",      -- 7
		"body",         -- 8
	}
	local parsed = parse(lines)

	it("returns nil for every header row", function()
		for row = 1, 3 do
			assert.is_nil(entity_range.range(parsed, lines, row),
				("row %d is header metadata, not an entity"):format(row))
			assert.is_nil(entity_range.range(parsed, lines, row, { scope = "to_end" }))
		end
	end)

	it("never returns a range that reaches into the header", function()
		for row = 1, #lines do
			for _, scope in ipairs({ "entity", "to_end" }) do
				local r = entity_range.range(parsed, lines, row, { scope = scope })
				if r then
					assert.is_true(r.first > parsed.header_end,
						("row %d/%s escaped into the header"):format(row, scope))
				end
			end
		end
	end)

	it("still has no floor above line 1 in a plain markdown buffer", function()
		local plain = { "# A", "body" }
		local r = entity_range.range(nil, plain, 1)
		assert.equals(1, r.first)
	end)

	-- The CLASS the first fix missed: the floor came from `parsed`, which is
	-- nil whenever the buffer was not classified a chat -- and not_chat rejects
	-- for five reasons unrelated to document shape (name not timestamped, under
	-- 5 lines, no topic header...). A transcript is still a transcript.
	it("floors an unparsed transcript from its own shape", function()
		for row = 1, 3 do
			assert.is_nil(entity_range.range(nil, lines, row),
				("row %d must be floored even with parsed = nil"):format(row))
		end
		local r = entity_range.range(nil, lines, 8)
		assert.is_true(r.first > 3, "a range below the header must not reach into it")
	end)

	it("does not floor a thematic break in a genuine markdown note", function()
		-- `---` here is a horizontal rule, not a transcript header: flooring on
		-- any `---` would make the section above it undeletable.
		local note = { "# My Note", "prose", "---", "more prose" }
		local r = entity_range.range(nil, note, 1)
		assert.equals(1, r.first)
	end)

	-- The previous case exits at the line-1 shape guard and so never reaches
	-- the terminator scan. THIS one is title-shaped like a transcript and must
	-- still not be floored: the terminator has to close a contiguous run of
	-- header-shaped lines, not just appear somewhere below a matching title.
	it("does not floor a note whose title happens to look like a header", function()
		local note = {
			"# topic: how to cook", -- 1  transcript-shaped title
			"",                     -- 2
			"Intro paragraph.",     -- 3  <- not header-shaped: disqualifies
			"",                     -- 4
			"## Step one",          -- 5
			"prep",                 -- 6
			"",                     -- 7
			"---",                  -- 8  thematic break, NOT a header end
			"",                     -- 9
			"## Step two",          -- 10
			"cook",                 -- 11
		}
		assert.is_nil(require("parley.chat_parser").transcript_header_end(note))
		for _, row in ipairs({ 1, 3, 5, 10 }) do
			assert.is_not_nil(entity_range.range(nil, note, row),
				("row %d must stay editable in a genuine note"):format(row))
		end
	end)

	-- THE RULE (3rd finding in this family, so the enumeration is the
	-- deliverable, not the instance): the header floor's predicate may never be
	-- stricter than the writer it must accept. Every template Parley can write
	-- must yield a terminator, rendered through the REAL renderer and through
	-- new_chat's markdown underscore-escaping -- which is what turned the
	-- always-present `system_prompt:` key into `system\_prompt:` and silently
	-- removed the floor from every long-template chat.
	it("accepts every header shape Parley itself writes", function()
		local defaults = require("parley.defaults")
		local render = require("parley.render")
		local chat_parser = require("parley.chat_parser")

		local substitutions = {
			["{{filename}}"] = "2026-03-01-probe.md",
			["{{optional_headers}}"] = "model: claude\nprovider: anthropic\n"
				.. "system_prompt: You are helpful.\n",
			["{{user_prefix}}"] = "💬:",
			["{{respond_shortcut}}"] = "<C-g><C-g>",
			["{{cmd_prefix}}"] = "Parley",
			["{{stop_shortcut}}"] = "<C-g>x",
			["{{delete_shortcut}}"] = "<C-g>d",
			["{{new_shortcut}}"] = "<C-g>c",
		}

		for _, name in ipairs({ "chat_template", "short_chat_template" }) do
			local rendered = render.template(defaults[name], substitutions)
			rendered = rendered:gsub("_", "\\_")          -- new_chat's markdown escape
			rendered = rendered:gsub("^%s*(.-)%s*$", "%1") .. "\n"
			local rendered_lines = vim.split(rendered, "\n")
			assert.is_not_nil(chat_parser.transcript_header_end(rendered_lines),
				name .. " must yield a header terminator, or its chats lose the floor")
			assert.is_nil(entity_range.range(nil, rendered_lines, 1),
				name .. " line 1 must be floored")
		end
	end)

	-- The negative side of the same rule: being permissive inside a fence must
	-- not make a genuine note's sections undeletable.
	it("does not floor a note whose title merely contains a colon", function()
		local note = { "# Recipe: soup", "", "---", "", "## Two", "y" }
		assert.is_nil(require("parley.chat_parser").transcript_header_end(note))
		assert.is_not_nil(entity_range.range(nil, note, 1))
	end)

	it("still floors a real transcript header", function()
		local chat_parser = require("parley.chat_parser")
		assert.equals(3, chat_parser.transcript_header_end(lines))
		-- front-matter form too
		assert.equals(4, chat_parser.transcript_header_end(
			{ "---", "topic: t", "file: t.md", "---", "", "💬: q" }))
	end)
end)

describe("entity_range code fences", function()
	-- A fence is a wall for the same reason a heading is: the issue ruled that
	-- strict `dap` parity is a BUG in a transcript. Without this, dae on a
	-- fence opener deletes the opener plus its first stanza and leaves a bare
	-- closing fence, after which the rest of the transcript renders as code.
	local lines = {
		"# topic: t",   -- 1
		"- file: t.md", -- 2
		"---",          -- 3
		"",             -- 4
		"💬: q",        -- 5
		"",             -- 6
		"🤖: [A]",      -- 7
		"prose",        -- 8
		"",             -- 9
		"```lua",       -- 10
		"local a = 1",  -- 11
		"",             -- 12
		"local b = 2",  -- 13
		"```",          -- 14
		"after",        -- 15
	}
	local parsed = parse(lines)

	it("treats a fence line as a wall, not as paragraph content", function()
		assert.is_nil(entity_range.range(parsed, lines, 10),
			"the opener is a wall: dae on it must be a no-op")
		assert.is_nil(entity_range.range(parsed, lines, 14),
			"the closer is a wall too")
	end)

	it("keeps a range inside the fence from swallowing the fence", function()
		local r = entity_range.range(parsed, lines, 11)
		assert.equals(11, r.first)
		assert.is_true(r.last < 14, "must not reach the closing fence")
		assert.is_true(r.first > 10, "must not reach the opening fence")
	end)

	it("does not let a paragraph above the fence absorb it", function()
		local r = entity_range.range(parsed, lines, 8)
		assert.equals(8, r.first)
		assert.is_true(r.last < 10, "prose must stop before the opener")
	end)

	it("treats a heading inside a fence as content, not a section", function()
		-- Same ruling outline.lua:32 makes. Without it, dae on the `# not a
		-- heading` line builds a section that runs past the closing fence.
		local fenced = {
			"# topic: t", "- file: t.md", "---", "",
			"💬: q",              -- 5
			"", "🤖: [A]",        -- 6,7
			"```markdown",        -- 8
			"# not a heading",    -- 9
			"body",               -- 10
			"```",                -- 11
			"",                   -- 12
			"## real heading",    -- 13
			"tail",               -- 14
		}
		local p2 = parse(fenced)
		local r = entity_range.range(p2, fenced, 9)
		assert.is_true(r == nil or r.kind ~= "section",
			"a heading inside a fence must not be treated as a section")
		if r then assert.is_true(r.last < 11, "must not cross the closing fence") end
		-- the real heading outside the fence still works
		assert.equals("section", entity_range.range(p2, fenced, 13).kind)
	end)

	-- BR-26: the wall and code_block_memo must recognise the SAME fences, or a
	-- flavour the memo sees and the wall does not still reproduces the bug.
	it("walls every fence flavour the in-block test recognises", function()
		local lexical = require("parley.document.lexical")
		for _, delim in ipairs({ "```", "~~~", "  ```", "   ~~~~", "````json" }) do
			assert.is_not_nil(lexical.is_fence_delim(delim, true),
				("memo must see %q"):format(delim))
			local body = {
				"# topic: t", "- file: t.md", "---", "",
				"💬: q", "", "🤖: [A]",
				delim,        -- 8
				"payload",    -- 9
				delim:gsub("%S+$", ""):gsub("^%s*", "") ~= "" and "```" or delim, -- 10
			}
			body[10] = delim:match("~") and "~~~" or "```"
			local p2 = parse(body)
			assert.is_nil(entity_range.range(p2, body, 8),
				("fence %q must be a wall"):format(delim))
		end
	end)

	-- BR-30: gating only the DISPATCH leaves the scans inside section_range
	-- reading raw heading.level, so a `# x` in a code sample terminates the
	-- enclosing section early and the range ends ON the opening fence.
	it("a heading inside a fence does not terminate the section above it", function()
		local lines2 = {
			"# topic: t", "- file: t.md", "---", "",
			"💬: q", "", "🤖: [A]",
			"## real section",  -- 8
			"body",             -- 9
			"",                 -- 10
			"```md",            -- 11
			"# fake heading",   -- 12
			"still code",       -- 13
			"```",              -- 14
			"tail of section",  -- 15
		}
		local p2 = parse(lines2)
		local r = entity_range.range(p2, lines2, 8)
		assert.equals("section", r.kind)
		assert.equals(8, r.first)
		assert.is_true(r.last >= 15,
			("section must span the fenced sample, got last=%d"):format(r.last))
	end)

	it("to_end from inside a fence still stops at the exchange bound", function()
		local r = entity_range.range(parsed, lines, 11, { scope = "to_end" })
		assert.is_true(r.last <= #lines)
		assert.is_true(r.first >= 11)
	end)
end)

describe("entity_range invariants", function()
	local CORPUS = {
		{}, { "" }, { "   " }, { "# only" }, { "💬: q" },
		{ "# topic: t", "- file: t.md", "---" },
		{ "# topic: t", "- file: t.md", "---", "", "💬: q" },
		{ "# topic: t", "- file: t.md", "---", "", "💬: q", "🤖: [A]", "a", "📝: s" },
		{ "```", "# fenced heading", "```" },
		{ "#### deep", "body" },
	}

	it("never returns an out-of-range or inverted range", function()
		for _, lines in ipairs(CORPUS) do
			local ok, parsed = pcall(parse, lines)
			if not ok then parsed = nil end
			for row = 0, #lines + 2 do
				for _, scope in ipairs({ "entity", "to_end" }) do
					for _, inner in ipairs({ false, true }) do
						local got = entity_range.range(parsed, lines, row,
							{ scope = scope, inner = inner })
						if got then
							assert.is_true(got.first >= 1, "first >= 1")
							assert.is_true(got.last <= #lines, "last <= #lines")
							assert.is_true(got.first <= got.last, "first <= last")
						end
					end
				end
			end
		end
	end)
end)
