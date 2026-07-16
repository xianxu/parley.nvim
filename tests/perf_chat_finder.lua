-- Performance benchmark for ChatFinder's pure record materializer.
--
-- Usage:
--   nvim --headless -u tests/minimal_init.vim -l tests/perf_chat_finder.lua
--
-- Discovery, stat, and header IO are intentionally excluded. The benchmark
-- receives the same prebuilt raw records a settled FinderLoadSession delivers,
-- so it measures deterministic dedup/sort/recency/render policy only.

local chat_records = require("parley.chat_finder_records")

local function benchmark(label, fn, iterations)
	iterations = iterations or 5
	local times = {}
	for _ = 1, iterations do
		local start = (vim.uv or vim.loop).hrtime()
		fn()
		times[#times + 1] = ((vim.uv or vim.loop).hrtime() - start) / 1e6
	end
	table.sort(times)
	print(string.format(
		"  %-32s min=%7.1fms median=%7.1fms max=%7.1fms",
		label,
		times[1],
		times[math.ceil(#times / 2)],
		times[#times]
	))
end

local function records_for(count)
	local tags = { "work", "personal", "ai", "code", "research" }
	local result = {}
	for index = 1, count do
		local timestamp = os.time() - (index % 730) * 86400
		local path = string.format("/benchmark/%06d.md", index)
		result[index] = {
			path = path,
			identity = {
				key = path,
				source = { root_ordinal = 1, unresolved = path },
			},
			stat = { mtime = { sec = timestamp } },
			root = { path = "/benchmark", label = "main", is_primary = true },
			mtime = timestamp,
			timestamp = timestamp,
			topic = "Benchmark topic " .. index,
			tags = index % 3 == 0 and { tags[(index % #tags) + 1] } or {},
		}
	end
	return result
end

local function run(count)
	print(string.format("\n=== %d records ===", count))
	local records = records_for(count)
	benchmark("all records", function()
		local entries = chat_records.materialize(records, {})
		assert(#entries == count)
	end)
	local cutoff = os.time() - 180 * 86400
	benchmark("six-month recency", function()
		local entries = chat_records.materialize(records, { cutoff_time = cutoff })
		assert(#entries > 0 and #entries < count)
	end)
end

print("ChatFinder Materializer Benchmark")
print("=================================")
run(1000)
run(5000)
run(10000)
print("\nDone.")
vim.cmd("qa!")
