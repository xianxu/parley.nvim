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

	describe("build_grep_cmd", function()
		it("builds grep command from directory list", function()
			local cmd = memory_prefs.build_grep_cmd({ "'/path/to/chats'", "'/other/dir'" })
			assert.truthy(cmd:find("grep %-rn %-E"))
			assert.truthy(cmd:find("'/path/to/chats'"))
			assert.truthy(cmd:find("'/other/dir'"))
			assert.truthy(cmd:find("2>/dev/null"))
		end)
	end)

	describe("parse_tag_content", function()
		it("parses file with timestamp and content", function()
			local result = memory_prefs.parse_tag_content({
				"<!-- last_generated: 2026-04-03T04:34:29 -->",
				"",
				"User prefers concise code.",
				"Expert in Lua.",
			})
			assert.equals("2026-04-03T04:34:29", result.last_generated)
			assert.equals("User prefers concise code.\nExpert in Lua.", result.text)
		end)

		it("parses file without timestamp", function()
			local result = memory_prefs.parse_tag_content({
				"User prefers concise code.",
			})
			assert.is_nil(result.last_generated)
			assert.equals("User prefers concise code.", result.text)
		end)

		it("returns nil for empty lines", function()
			assert.is_nil(memory_prefs.parse_tag_content({}))
		end)

		it("returns nil for blank content", function()
			assert.is_nil(memory_prefs.parse_tag_content({
				"<!-- last_generated: 2026-04-03T04:34:29 -->",
				"",
			}))
		end)
	end)

	describe("is_stale", function()
		it("returns true when timestamp is nil", function()
			assert.is_true(memory_prefs.is_stale(nil, 1, os.date("!*t")))
		end)

		it("returns true when timestamp is malformed", function()
			assert.is_true(memory_prefs.is_stale("not-a-date", 1, os.date("!*t")))
		end)

		it("returns false when within max age", function()
			-- Use a timestamp 1 hour ago
			local now = os.date("!*t")
			local recent = os.date("!%Y-%m-%dT%H:%M:%S", os.time(now) - 3600)
			assert.is_false(memory_prefs.is_stale(recent, 1, now))
		end)

		it("returns true when older than max age", function()
			local now = os.date("!*t")
			local old = os.date("!%Y-%m-%dT%H:%M:%S", os.time(now) - 2 * 86400)
			assert.is_true(memory_prefs.is_stale(old, 1, now))
		end)
	end)
end)
