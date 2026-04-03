-- parley.memory_prefs — per-tag user preference profiles from chat history
-- Extracts 📝: summary lines and tags: from chat files via grep,
-- groups by tag, sends to LLM to generate preference profiles,
-- and injects them into the system prompt.

local M = {}
local _parley
local _cached_prefs = nil -- in-memory cache of loaded preferences
local _generating = false -- in-memory lock to prevent concurrent generation

M.setup = function(parley)
	_parley = parley
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function prefs_dir()
	return vim.fn.expand(_parley.config.chat_dir)
end

local function prefs_path(tag)
	return prefs_dir() .. "/memory_prefs_" .. tag .. ".md"
end

--------------------------------------------------------------------------------
-- Phase 1+2: Extract and group summaries via grep
--------------------------------------------------------------------------------

--- Parse grep output lines into per-tag summary buckets.
--- Pure function: no I/O.
---@param grep_lines string[] output from grep -rn
---@param max_files number max recent files per tag to include
---@return table<string, string[]> tag → summary lines (reverse chrono)
M.parse_grep_output = function(grep_lines, max_files)
	-- First pass: build filename → tags map and filename → summaries map
	local file_tags = {} -- filename → { tag1, tag2, ... }
	local file_summaries = {} -- filename → { summary1, summary2, ... }
	local seen_files = {} -- ordered unique filenames

	for _, line in ipairs(grep_lines) do
		-- grep output: filepath:linenum:content
		local filepath, content = line:match("^(.-):%d+:(.*)")
		if filepath and content then
			local filename = vim.fn.fnamemodify(filepath, ":t")
			if content:match("^tags:") then
				local tag_str = content:sub(6) -- strip "tags:"
				local tags = {}
				for tag in tag_str:gmatch("[^,%s]+") do
					local trimmed = vim.trim(tag)
					if trimmed ~= "" then
						table.insert(tags, trimmed:lower())
					end
				end
				file_tags[filename] = tags
			elseif content:match("^📝:") then
				local summary_text = vim.trim(content:sub(#"📝:" + 1))
				if summary_text ~= "" then
					if not file_summaries[filename] then
						file_summaries[filename] = {}
						table.insert(seen_files, filename)
					end
					table.insert(file_summaries[filename], summary_text)
				end
			end
		end
	end

	-- Sort filenames chronologically (oldest first)
	table.sort(seen_files)

	-- Per-tag: collect which files belong to each tag
	local tag_files = {} -- tag → { filename, ... }
	for _, filename in ipairs(seen_files) do
		local tags = file_tags[filename] or {}
		if #tags == 0 then
			tag_files._all = tag_files._all or {}
			table.insert(tag_files._all, filename)
		else
			for _, tag in ipairs(tags) do
				tag_files[tag] = tag_files[tag] or {}
				table.insert(tag_files[tag], filename)
			end
		end
	end

	-- For each tag, keep only the last N files, then collect their summaries
	local buckets = {} -- tag → { summary, ... }
	for tag, filenames in pairs(tag_files) do
		-- Take last max_files entries
		local start = math.max(1, #filenames - max_files + 1)
		buckets[tag] = {}
		for i = start, #filenames do
			for _, s in ipairs(file_summaries[filenames[i]] or {}) do
				table.insert(buckets[tag], s)
			end
		end
	end

	return buckets
end

--- Run grep across all chat roots and return parsed buckets.
---@return table<string, string[]> tag → summary lines
M.extract_summaries = function()
	local roots = _parley.get_chat_roots()
	local dirs = {}
	for _, root in ipairs(roots) do
		table.insert(dirs, vim.fn.shellescape(vim.fn.expand(root.dir)))
	end

	if #dirs == 0 then
		_parley.logger.warning("memory_prefs: no chat directories configured")
		return {}
	end

	local cmd = 'grep -rn -E "^tags:|^📝:" ' .. table.concat(dirs, " ") .. " 2>/dev/null"
	_parley.logger.debug("memory_prefs: grep cmd: " .. cmd)
	local lines = vim.fn.systemlist(cmd)
	_parley.logger.debug("memory_prefs: grep returned " .. #lines .. " lines")
	local max_files = _parley.config.memory_prefs and _parley.config.memory_prefs.max_files or 100
	local buckets = M.parse_grep_output(lines, max_files)
	local tag_count = 0
	for tag, summaries in pairs(buckets) do
		tag_count = tag_count + 1
		_parley.logger.debug("memory_prefs: bucket [" .. tag .. "] has " .. #summaries .. " summaries")
	end
	_parley.logger.debug("memory_prefs: " .. tag_count .. " tag buckets")
	return buckets
end

--------------------------------------------------------------------------------
-- Phase 3: LLM summarization
--------------------------------------------------------------------------------

--- Generate preferences for all tag buckets via sequential LLM calls.
--- Async: calls callback(preferences) when all tags are done.
---@param buckets table<string, string[]> tag → summary lines
---@param callback function called with { tag → preference_text }
M.generate_preferences = function(buckets, callback)
	local tags = {}
	for tag in pairs(buckets) do
		table.insert(tags, tag)
	end
	table.sort(tags)

	if #tags == 0 then
		callback({})
		return
	end

	local agent = _parley.get_agent()
	local provider = agent.provider
	local model = agent.model
	_parley.logger.debug("memory_prefs: using provider=" .. tostring(provider) .. " model=" .. vim.inspect(model))
	local prompt = _parley.config.memory_prefs and _parley.config.memory_prefs.prompt
		or "Based on the following chat history summaries, generate a concise user preference profile that captures the user's interests, expertise level, and communication preferences. Output only the profile text."

	local preferences = {}
	local idx = 0

	local function process_next()
		idx = idx + 1
		if idx > #tags then
			vim.schedule(function()
				callback(preferences)
			end)
			return
		end

		local tag = tags[idx]
		local summaries = buckets[tag]
		local tag_label = tag == "_all" and "all topics" or ("topic: " .. tag)

		vim.schedule(function()
			vim.notify(
				string.format("Memory prefs: generating %s (%d/%d)", tag_label, idx, #tags),
				vim.log.levels.INFO
			)
		end)

		local messages = {
			{ role = "system", content = prompt },
			{ role = "user", content = "Topic: " .. tag_label .. "\n\n" .. table.concat(summaries, "\n") },
		}

		local payload = _parley.dispatcher.prepare_payload(messages, model, provider)
		_parley.logger.debug("memory_prefs: querying LLM for tag [" .. tag .. "] with " .. #summaries .. " summaries")

		local handler = function(_qid, content)
			_parley.logger.debug("memory_prefs: handler chunk for [" .. tag .. "]: " .. tostring(content and #content or "nil") .. " chars")
		end

		_parley.dispatcher.query(nil, provider, payload, handler, nil, function(response)
			_parley.logger.debug("memory_prefs: callback for [" .. tag .. "]: response=" .. tostring(response and #response or "nil") .. " chars")
			if response and response ~= "" then
				local trimmed = vim.trim(response)
				preferences[tag] = trimmed
				M.save_tag(tag, trimmed)
				_parley.logger.debug("memory_prefs: saved preference for [" .. tag .. "]")
			else
				_parley.logger.warning("memory_prefs: empty response for tag [" .. tag .. "]")
			end
			process_next()
		end)
	end

	process_next()
end

--------------------------------------------------------------------------------
-- Persistence
--------------------------------------------------------------------------------

--- Save a single tag's preference to its own markdown file.
---@param tag string
---@param text string preference content
M.save_tag = function(tag, text)
	local out = {}
	table.insert(out, "<!-- last_generated: " .. os.date("!%Y-%m-%dT%H:%M:%S") .. " -->")
	table.insert(out, "")
	for _, line in ipairs(vim.split(text, "\n")) do
		table.insert(out, line)
	end

	_parley.helpers.prepare_dir(prefs_dir(), "chat")
	vim.fn.writefile(out, prefs_path(tag))
	-- Invalidate cache so next load picks up changes
	_cached_prefs = nil
end

--- Load a single tag's preference file.
--- Returns { last_generated = string, text = string } or nil.
local function load_tag_file(tag)
	local path = prefs_path(tag)
	if vim.fn.filereadable(path) ~= 1 then
		return nil
	end
	local lines = vim.fn.readfile(path)
	if #lines == 0 then
		return nil
	end

	local ts = lines[1]:match("<!%-%- last_generated: (.+) %-%->")
	-- Content starts after the timestamp line and blank line
	local start = ts and 3 or 1
	local content_lines = {}
	for i = start, #lines do
		table.insert(content_lines, lines[i])
	end
	local text = vim.trim(table.concat(content_lines, "\n"))
	if text == "" then
		return nil
	end
	return { last_generated = ts, text = text }
end

--- Load all preference files. Returns cached version if available.
---@return table|nil { preferences = { tag → text }, oldest_generated = string|nil }
M.load = function()
	if _cached_prefs then
		return _cached_prefs
	end

	local dir = prefs_dir()
	local pattern = dir .. "/memory_prefs_*.md"
	local files = vim.fn.glob(pattern, false, true)
	if #files == 0 then
		return nil
	end

	local data = { preferences = {} }
	local oldest_ts = nil

	for _, file in ipairs(files) do
		local tag = vim.fn.fnamemodify(file, ":t"):match("^memory_prefs_(.+)%.md$")
		if tag then
			local entry = load_tag_file(tag)
			if entry then
				data.preferences[tag] = entry.text
				if entry.last_generated then
					if not oldest_ts or entry.last_generated < oldest_ts then
						oldest_ts = entry.last_generated
					end
				end
			end
		end
	end

	if not next(data.preferences) then
		return nil
	end

	data.oldest_generated = oldest_ts
	_cached_prefs = data
	return data
end

--- Clear the in-memory cache (forces reload from disk on next load).
M.clear_cache = function()
	_cached_prefs = nil
end

--------------------------------------------------------------------------------
-- Phase 4: System prompt injection
--------------------------------------------------------------------------------

--- Get combined preference text for a set of tags.
---@param tags string[]|nil tags from chat headers
---@return string|nil preference text to append, or nil
M.get_preference = function(tags)
	local config = _parley.config.memory_prefs
	if not config or not config.enable then
		return nil
	end

	local data = M.load()
	if not data or not data.preferences then
		return nil
	end

	local parts = {}

	-- _all is always included as baseline
	if data.preferences._all then
		table.insert(parts, data.preferences._all)
	end

	-- Add tag-specific preferences
	if type(tags) == "table" then
		for _, tag in ipairs(tags) do
			local normalized = tag:lower()
			if data.preferences[normalized] then
				table.insert(parts, data.preferences[normalized])
			end
		end
	end

	if #parts == 0 then
		return nil
	end

	return table.concat(parts, "\n\n")
end

--------------------------------------------------------------------------------
-- Generation pipeline
--------------------------------------------------------------------------------

--- Run the full generation pipeline (extract → summarize → save).
--- Async. Respects lock.
M.generate = function()
	if _generating then
		_parley.logger.debug("memory_prefs: generation already in progress")
		return
	end
	_generating = true

	vim.schedule(function()
		vim.notify("Memory prefs: scanning chat history...", vim.log.levels.INFO)
	end)

	local ok, err = pcall(function()
		local buckets = M.extract_summaries()
		if not next(buckets) then
			vim.schedule(function()
				vim.notify("Memory prefs: no summaries found in chat history", vim.log.levels.WARN)
			end)
			_generating = false
			return
		end

		_parley.logger.debug("memory_prefs: starting LLM summarization")
		M.generate_preferences(buckets, function(preferences)
			local count = 0
			for _ in pairs(preferences) do count = count + 1 end
			_parley.logger.debug("memory_prefs: generation complete, " .. count .. " preferences")
			_generating = false
			vim.schedule(function()
				vim.notify(
					string.format("Memory prefs: generated preferences for %d tag(s)", count),
					vim.log.levels.INFO
				)
			end)
		end)
	end)
	if not ok then
		_parley.logger.error("memory_prefs: generation failed: " .. tostring(err))
		_generating = false
	end
end

--- Check if generation is needed and trigger if so.
--- Called on startup.
M.maybe_generate = function()
	local config = _parley.config.memory_prefs
	if not config or not config.enable then
		return
	end

	local data = M.load()
	if data and data.oldest_generated then
		-- Parse ISO timestamp
		local y, mo, d, h, mi, s = data.oldest_generated:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
		if y then
			local generated_time = os.time({
				year = tonumber(y), month = tonumber(mo), day = tonumber(d),
				hour = tonumber(h), min = tonumber(mi), sec = tonumber(s),
			})
			local age_seconds = os.difftime(os.time(os.date("!*t")), generated_time)
			local max_age = (config.max_age_days or 1) * 86400
			if age_seconds < max_age then
				return
			end
		end
	end

	-- File missing, empty, or stale — generate
	vim.defer_fn(function()
		M.generate()
	end, 2000) -- small delay to let startup complete
end

return M
