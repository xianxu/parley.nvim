-- Performance benchmark for ChatFinder file scanning.
--
-- Usage:
--   nvim --headless -u tests/minimal_init.vim -l tests/perf_chat_finder.lua
--
-- Populates a temp directory with N chat files (default 1000, 5000, 10000),
-- then benchmarks:
--   1) Cold scan (no cache)
--   2) Warm scan (all cached, no files changed)
--   3) Warm scan with 1% files modified
--
-- Stash this branch's changes and re-run to compare before/after.

local M = require("parley")

-- Run full setup with defaults to initialize config, chat_parser, etc.
M.setup({})

-- Silence logger after setup
M.logger = setmetatable({}, {
	__index = function()
		return function() end
	end,
})

local chat_finder = require("parley.chat_finder")

-- Stub get_chat_roots to return our temp dir
local tmpdir

local function generate_files(dir, count)
	vim.fn.mkdir(dir, "p")
	local tags_pool = { "work", "personal", "ai", "code", "research", "draft", "review", "bug", "feature", "docs" }

	for i = 1, count do
		-- Spread files across 2 years for recency filter testing
		local days_ago = math.random(0, 730)
		local t = os.time() - days_ago * 86400 + math.random(0, 86399)
		local d = os.date("*t", t)
		local filename = string.format(
			"%04d-%02d-%02d-%02d-%02d-%02d-topic-%d.md",
			d.year, d.month, d.day, d.hour, d.min, d.sec, i
		)
		local filepath = dir .. "/" .. filename

		-- Random tags (0-3)
		local ntags = math.random(0, 3)
		local file_tags = {}
		for _ = 1, ntags do
			table.insert(file_tags, tags_pool[math.random(#tags_pool)])
		end

		-- Write frontmatter
		local lines = {
			"---",
			"topic: Benchmark topic number " .. i,
		}
		if #file_tags > 0 then
			table.insert(lines, "tags: " .. table.concat(file_tags, ", "))
		end
		table.insert(lines, "---")
		table.insert(lines, "")
		table.insert(lines, "# Content for file " .. i)

		local f = io.open(filepath, "w")
		f:write(table.concat(lines, "\n") .. "\n")
		f:close()

		-- Set mtime to match the filename timestamp
		vim.loop.fs_utime(filepath, t, t)
	end
end

local function touch_random_files(dir, count, pct)
	-- Touch pct% of files to simulate modifications
	local pattern = vim.fn.fnameescape(dir) .. "/[0-9]*.md"
	local files = vim.fn.glob(pattern, false, true)
	local n = math.max(1, math.floor(#files * pct / 100))
	for i = 1, n do
		local idx = math.random(#files)
		local filepath = files[idx]
		-- Append a line to change mtime
		local f = io.open(filepath, "a")
		f:write("<!-- touched -->\n")
		f:close()
	end
	return n
end

local function benchmark(label, fn, iterations)
	iterations = iterations or 3
	local times = {}
	for i = 1, iterations do
		local start = vim.loop.hrtime()
		fn()
		local elapsed_ms = (vim.loop.hrtime() - start) / 1e6
		table.insert(times, elapsed_ms)
	end
	table.sort(times)
	local median = times[math.ceil(#times / 2)]
	local min_t = times[1]
	local max_t = times[#times]
	print(string.format("  %-40s  min=%7.1fms  median=%7.1fms  max=%7.1fms", label, min_t, median, max_t))
end

local function run_benchmark(file_count)
	print(string.format("\n=== %d files ===", file_count))

	-- Clean up and regenerate
	if tmpdir then
		vim.fn.delete(tmpdir, "rf")
	end
	local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
	tmpdir = "/tmp/parley-perf-chatfinder-" .. random_suffix
	generate_files(tmpdir, file_count)

	-- Wire up stubs
	local chat_roots = { { dir = tmpdir, label = "perf", is_primary = true } }
	M.get_chat_roots = function()
		return chat_roots
	end
	M.config = M.config or {}
	M.config.chat_dir = tmpdir

	local has_cache = chat_finder._scan_chat_files ~= nil

	-- Fallback scan for old code (no cache, inline reimplementation of the scan loop)
	local function scan_fallback(roots, cutoff_time, is_filtering)
		local files = {}
		local seen = {}
		for _, root in ipairs(roots) do
			local pattern = vim.fn.fnameescape(root.dir) .. "/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*.md"
			for _, file in ipairs(vim.fn.glob(pattern, false, true)) do
				local resolved = vim.fn.resolve(file)
				if not seen[resolved] then
					seen[resolved] = true
					table.insert(files, { path = file, root = root })
				end
			end
		end
		local entries = {}
		for _, item in ipairs(files) do
			local file = item.path
			local stat = vim.loop.fs_stat(file)
			if not stat then goto skip end
			local file_time
			local fname = vim.fn.fnamemodify(file, ":t:r")
			local y, mo, d, h, mi, s = fname:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)")
			if y then
				file_time = os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d),
					hour = tonumber(h), min = tonumber(mi), sec = tonumber(s) })
			else
				file_time = stat.mtime.sec
			end
			if is_filtering and cutoff_time and file_time < cutoff_time then goto skip end
			local lines = vim.fn.readfile(file, "", 10)
			local topic, tags = "", {}
			local header_end = M.chat_parser.find_header_end(lines)
			if header_end then
				local parsed = M.parse_chat(lines, header_end)
				topic = parsed.headers.topic or ""
				if parsed.headers.tags and type(parsed.headers.tags) == "table" then
					tags = parsed.headers.tags
				end
			end
			table.insert(entries, { value = file, topic = topic, tags = tags, timestamp = file_time })
			::skip::
		end
		table.sort(entries, function(a, b) return a.timestamp > b.timestamp end)
		return entries
	end

	local function do_scan(roots, cutoff, filtering)
		if has_cache then
			return chat_finder._scan_chat_files(roots, cutoff, filtering)
		else
			return scan_fallback(roots, cutoff, filtering)
		end
	end

	local function clear()
		if has_cache then chat_finder.clear_cache() end
	end

	if has_cache then
		print("  (cache layer detected)")
	else
		print("  (no cache layer — baseline mode)")
	end

	-- 1) Cold scan (clear cache each time)
	benchmark("Cold scan (no cache)", function()
		clear()
		local entries = do_scan(chat_roots, nil, false)
		assert(#entries > 0, "expected entries, got 0")
	end, 5)

	-- 2) Warm scan (cache populated, no changes)
	clear()
	do_scan(chat_roots, nil, false)

	benchmark("Warm scan (fully cached)", function()
		local entries = do_scan(chat_roots, nil, false)
		assert(#entries > 0, "expected entries, got 0")
	end, 5)

	-- 3) Warm scan with 1% files modified
	local touched = touch_random_files(tmpdir, file_count, 1)
	print(string.format("  (touched %d files for partial-invalidation test)", touched))

	benchmark("Warm scan (1% modified)", function()
		local entries = do_scan(chat_roots, nil, false)
		assert(#entries > 0, "expected entries, got 0")
	end, 5)

	-- 4) Cold scan with recency filter (6 months)
	local cutoff = os.time() - 6 * 30 * 86400
	benchmark("Cold scan (6mo recency)", function()
		clear()
		local entries = do_scan(chat_roots, cutoff, true)
	end, 5)

	-- 5) Warm scan with recency filter
	clear()
	do_scan(chat_roots, cutoff, true)

	benchmark("Warm scan (6mo recency)", function()
		local entries = do_scan(chat_roots, cutoff, true)
	end, 5)

	-- Cleanup
	vim.fn.delete(tmpdir, "rf")
end

print("ChatFinder Performance Benchmark")
print("================================")

math.randomseed(42) -- deterministic

run_benchmark(1000)
run_benchmark(5000)
run_benchmark(10000)

print("\nDone.")
vim.cmd("qa!")
