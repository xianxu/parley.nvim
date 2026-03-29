-- Unit tests for exchange_clipboard.lua pure functions.

local ec = require("parley.exchange_clipboard")

describe("exchange_clipboard", function()
	-- Helper: build a minimal parsed_chat with given exchange line ranges.
	-- Each entry is { q_start, q_end, a_start, a_end } or { q_start, q_end } for no answer.
	local function make_parsed(exchange_ranges)
		local exchanges = {}
		for _, r in ipairs(exchange_ranges) do
			local ex = {
				question = { line_start = r[1], line_end = r[2], content = "" },
			}
			if r[3] then
				ex.answer = { line_start = r[3], line_end = r[4], content = "" }
			end
			table.insert(exchanges, ex)
		end
		return { exchanges = exchanges, headers = {}, branches = {} }
	end

	describe("Group A: get_exchange_line_range", function()
		it("A1: single exchange spans to end of file", function()
			local parsed = make_parsed({ { 5, 5, 7, 10 } })
			local s, e = ec.get_exchange_line_range(parsed, 1, 12)
			assert.equals(5, s)
			assert.equals(12, e)
		end)

		it("A2: first of two exchanges ends before second starts", function()
			local parsed = make_parsed({ { 5, 5, 7, 10 }, { 12, 12, 14, 18 } })
			local s, e = ec.get_exchange_line_range(parsed, 1, 20)
			assert.equals(5, s)
			assert.equals(11, e)
		end)

		it("A3: second exchange spans to end", function()
			local parsed = make_parsed({ { 5, 5, 7, 10 }, { 12, 12, 14, 18 } })
			local s, e = ec.get_exchange_line_range(parsed, 2, 20)
			assert.equals(12, s)
			assert.equals(20, e)
		end)

		it("A4: returns nil for out-of-range index", function()
			local parsed = make_parsed({ { 5, 5, 7, 10 } })
			local s, e = ec.get_exchange_line_range(parsed, 3, 12)
			assert.is_nil(s)
			assert.is_nil(e)
		end)
	end)

	describe("Group B: get_exchanges_for_range", function()
		it("B1: selection on single exchange", function()
			local parsed = make_parsed({ { 5, 5, 7, 10 }, { 12, 12, 14, 18 } })
			local result = ec.get_exchanges_for_range(parsed, 7, 9, 20)
			assert.same({ 1 }, result)
		end)

		it("B2: selection spanning two exchanges", function()
			local parsed = make_parsed({ { 5, 5, 7, 10 }, { 12, 12, 14, 18 } })
			local result = ec.get_exchanges_for_range(parsed, 9, 14, 20)
			assert.same({ 1, 2 }, result)
		end)

		it("B3: selection before all exchanges returns empty", function()
			local parsed = make_parsed({ { 5, 5, 7, 10 } })
			local result = ec.get_exchanges_for_range(parsed, 1, 3, 12)
			assert.same({}, result)
		end)

		it("B4: selection on gap between exchanges hits first", function()
			local parsed = make_parsed({ { 5, 5, 7, 10 }, { 12, 12, 14, 18 } })
			-- Line 11 is in exchange 1's trailing range (5-11)
			local result = ec.get_exchanges_for_range(parsed, 11, 11, 20)
			assert.same({ 1 }, result)
		end)
	end)

	describe("Group C: get_paste_line", function()
		it("C1: cursor on first exchange returns its end", function()
			local parsed = make_parsed({ { 5, 5, 7, 10 }, { 12, 12, 14, 18 } })
			local result = ec.get_paste_line(parsed, 8, 3, 20)
			assert.equals(11, result)
		end)

		it("C2: cursor on second exchange returns its end", function()
			local parsed = make_parsed({ { 5, 5, 7, 10 }, { 12, 12, 14, 18 } })
			local result = ec.get_paste_line(parsed, 15, 3, 20)
			assert.equals(20, result)
		end)

		it("C3: cursor before all exchanges returns header_end", function()
			local parsed = make_parsed({ { 5, 5, 7, 10 } })
			local result = ec.get_paste_line(parsed, 2, 3, 12)
			assert.equals(3, result)
		end)
	end)

	describe("Group D: extract_exchange_lines", function()
		it("D1: extracts single exchange lines, strips trailing blanks", function()
			local lines = {
				"header1", "header2", "---",            -- 1-3
				"",                                      -- 4
				"q: question",                           -- 5
				"",                                      -- 6
				"a: answer line 1",                      -- 7
				"a: answer line 2",                      -- 8
				"",                                      -- 9
				"",                                      -- 10
			}
			local parsed = make_parsed({ { 5, 5, 7, 8 } })
			local extracted, s, e = ec.extract_exchange_lines(lines, parsed, { 1 }, 10)
			assert.equals(5, s)
			assert.equals(10, e) -- delete_end includes trailing blanks
			assert.same({ "q: question", "", "a: answer line 1", "a: answer line 2" }, extracted)
		end)

		it("D2: extracts multiple exchanges", function()
			local lines = {
				"---", "header", "---",                  -- 1-3
				"",                                      -- 4
				"q1",                                    -- 5
				"a1",                                    -- 6
				"",                                      -- 7
				"q2",                                    -- 8
				"a2",                                    -- 9
				"",                                      -- 10
			}
			local parsed = make_parsed({ { 5, 5, 6, 6 }, { 8, 8, 9, 9 } })
			local extracted, s, e = ec.extract_exchange_lines(lines, parsed, { 1, 2 }, 10)
			assert.equals(5, s)
			assert.equals(10, e) -- delete_end includes trailing blanks
			assert.same({ "q1", "a1", "", "q2", "a2" }, extracted)
		end)

		it("D3: empty indices returns empty", function()
			local lines = { "---", "---", "q1", "a1" }
			local parsed = make_parsed({ { 3, 3, 4, 4 } })
			local extracted = ec.extract_exchange_lines(lines, parsed, {}, 4)
			assert.same({}, extracted)
		end)

		it("D4: strips leading blank lines from extracted content", function()
			local lines = {
				"---", "---",                            -- 1-2
				"",                                      -- 3 (blank before exchange)
				"",                                      -- 4 (blank before exchange)
				"q: question",                           -- 5
				"a: answer",                             -- 6
			}
			local parsed = make_parsed({ { 5, 5, 6, 6 } })
			-- Range is 3-6 (includes leading blanks as part of exchange range for a single-exchange file)
			-- But we want extracted content to start at question
			local extracted = ec.extract_exchange_lines(lines, parsed, { 1 }, 6)
			assert.same({ "q: question", "a: answer" }, extracted)
		end)
	end)

	describe("Group E: build_paste_lines", function()
		it("E1: adds blank line before when previous line has content", function()
			local buf = { "---", "---", "q1", "a1" }
			local result = ec.build_paste_lines(buf, 4, { "q2", "a2" }, 4)
			assert.same({ "", "q2", "a2" }, result)
		end)

		it("E2: no extra blank when previous line is already blank", function()
			local buf = { "---", "---", "q1", "a1", "" }
			local result = ec.build_paste_lines(buf, 5, { "q2", "a2" }, 5)
			assert.same({ "q2", "a2" }, result)
		end)

		it("E3: adds blank line after when next line has content", function()
			local buf = { "---", "---", "", "q1", "a1", "q2", "a2" }
			-- Paste after line 5 (a1), next line 6 is "q2" (content)
			local result = ec.build_paste_lines(buf, 5, { "q_new", "a_new" }, 7)
			assert.same({ "", "q_new", "a_new", "" }, result)
		end)

		it("E4: no extra blank after when next line is blank", function()
			local buf = { "---", "---", "q1", "a1", "", "q2", "a2" }
			-- Paste after line 4 (a1), next line 5 is blank
			local result = ec.build_paste_lines(buf, 4, { "q_new", "a_new" }, 7)
			assert.same({ "", "q_new", "a_new" }, result)
		end)

		it("E5: no extra blank after at end of file", function()
			local buf = { "---", "---", "q1", "a1" }
			local result = ec.build_paste_lines(buf, 4, { "q2", "a2" }, 4)
			assert.same({ "", "q2", "a2" }, result)
		end)

		it("E6: empty clipboard returns empty", function()
			local buf = { "---", "---", "q1", "a1" }
			local result = ec.build_paste_lines(buf, 4, {}, 4)
			assert.same({}, result)
		end)
	end)

	describe("Group F: compute_cut_cleanup", function()
		it("F1: collapses multiple blank lines to one", function()
			local buf = { "a1", "", "", "", "q2" }
			local s, e, replacement = ec.compute_cut_cleanup(buf, 3, 5)
			assert.equals(2, s)
			assert.equals(4, e)
			assert.same({ "" }, replacement)
		end)

		it("F2: single blank line needs no cleanup", function()
			local buf = { "a1", "", "q2" }
			local s = ec.compute_cut_cleanup(buf, 2, 3)
			assert.is_nil(s)
		end)

		it("F3: no blank lines needs no cleanup", function()
			local buf = { "a1", "q2" }
			local s = ec.compute_cut_cleanup(buf, 2, 2)
			assert.is_nil(s)
		end)

		it("F4: blank lines at end of file are collapsed", function()
			local buf = { "content", "", "", "" }
			local s, e, replacement = ec.compute_cut_cleanup(buf, 3, 4)
			assert.equals(2, s)
			assert.equals(4, e)
			assert.same({ "" }, replacement)
		end)
	end)
end)
