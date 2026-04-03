-- Unit tests for memory_prefs module (lua/parley/memory_prefs.lua)

local memory_prefs = require("parley.memory_prefs")

describe("memory_prefs", function()
	describe("parse_grep_output", function()
		it("extracts tags and summaries from grep output", function()
			local grep_lines = {
				"/chats/2026-03-30-10-00-00.md:3:tags: lua, neovim",
				"/chats/2026-03-30-10-00-00.md:25:📝: you asked about buffers, I answered with buffer API overview",
				"/chats/2026-03-30-10-00-00.md:41:📝: you asked about metatables, I answered with __index explanation",
				"/chats/2026-04-01-09-00-00.md:3:tags: cooking",
				"/chats/2026-04-01-09-00-00.md:18:📝: you asked about pasta, I answered with carbonara recipe",
			}

			local buckets = memory_prefs.parse_grep_output(grep_lines, 50)

			-- _all should be nil (all chats have tags)
			assert.is_nil(buckets._all)
			-- lua and neovim tags should have the first 2 summaries
			assert.equals(2, #buckets.lua)
			assert.equals(2, #buckets.neovim)
			-- cooking tag should have 1 summary
			assert.equals(1, #buckets.cooking)
		end)

		it("handles chats with no tags", function()
			local grep_lines = {
				"/chats/2026-03-30-10-00-00.md:25:📝: summary without tags",
			}

			local buckets = memory_prefs.parse_grep_output(grep_lines, 50)

			assert.equals(1, #buckets._all)
			assert.is_nil(buckets.lua)
		end)

		it("truncates to max_files per tag", function()
			local grep_lines = {}
			for i = 1, 10 do
				local ts = string.format("2026-03-%02d-10-00-00", i)
				table.insert(grep_lines, string.format("/chats/%s.md:3:tags: test", ts))
				table.insert(grep_lines, string.format("/chats/%s.md:10:📝: summary %d", ts, i))
			end

			local buckets = memory_prefs.parse_grep_output(grep_lines, 3)

			assert.equals(3, #buckets.test)
			assert.is_nil(buckets._all)
			-- should keep the last 3 files (chronological: 8, 9, 10)
			assert.truthy(buckets.test[1]:find("summary 8"))
			assert.truthy(buckets.test[2]:find("summary 9"))
			assert.truthy(buckets.test[3]:find("summary 10"))
		end)

		it("sorts summaries chronologically by filename", function()
			local grep_lines = {
				"/chats/2026-04-01-09-00-00.md:3:tags: t",
				"/chats/2026-04-01-09-00-00.md:10:📝: second",
				"/chats/2026-03-01-09-00-00.md:3:tags: t",
				"/chats/2026-03-01-09-00-00.md:10:📝: first",
			}

			local buckets = memory_prefs.parse_grep_output(grep_lines, 50)

			assert.equals("first", buckets.t[1])
			assert.equals("second", buckets.t[2])
		end)

		it("returns empty table for empty input", function()
			local buckets = memory_prefs.parse_grep_output({}, 50)
			assert.same({}, buckets)
		end)

		it("handles multiple summary lines per file", function()
			local grep_lines = {
				"/chats/2026-03-30-10-00-00.md:3:tags: dev",
				"/chats/2026-03-30-10-00-00.md:20:📝: first exchange summary",
				"/chats/2026-03-30-10-00-00.md:40:📝: second exchange summary",
			}

			local buckets = memory_prefs.parse_grep_output(grep_lines, 50)

			assert.is_nil(buckets._all)
			assert.equals(2, #buckets.dev)
		end)
	end)
end)
