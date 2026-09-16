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
