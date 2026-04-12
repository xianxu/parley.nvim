local M = {}

local stop_words = {
	["the"] = true,
	["a"] = true,
	["an"] = true,
	["in"] = true,
	["of"] = true,
	["for"] = true,
	["to"] = true,
	["and"] = true,
	["is"] = true,
	["with"] = true,
	["on"] = true,
	["at"] = true,
	["by"] = true,
}

--- Convert a topic string into a URL-safe slug, or nil if topic is empty/placeholder.
---@param topic string|nil
---@return string|nil
M.slugify = function(topic)
	if not topic or topic == "" or topic == "?" then
		return nil
	end

	-- lowercase, replace underscores with hyphens
	local s = topic:lower():gsub("_", "-")
	-- strip non-ASCII and non-alphanumeric (keep ASCII letters, digits, hyphens, spaces)
	s = s:gsub("[^%a%d%s%-]", "")
	-- remove any remaining non-ASCII bytes (multi-byte UTF-8 chars partially stripped above)
	s = s:gsub("[\128-\255]", "")
	-- normalize whitespace to single hyphens
	s = s:gsub("%s+", "-")
	-- collapse multiple hyphens
	s = s:gsub("%-+", "-")
	-- strip leading/trailing hyphens
	s = s:gsub("^%-+", ""):gsub("%-+$", "")

	-- split into words, filter stop words, take up to 5
	local words = {}
	for word in s:gmatch("[^%-]+") do
		if not stop_words[word] and word ~= "" then
			table.insert(words, word)
		end
		if #words >= 5 then
			break
		end
	end

	if #words == 0 then
		return nil
	end

	-- join and enforce 40 char limit at word boundary
	local result = words[1]
	for i = 2, #words do
		local candidate = result .. "-" .. words[i]
		if #candidate > 40 then
			break
		end
		result = candidate
	end

	return result
end

-- Timestamp pattern: YYYY-MM-DD.HH-MM-SS.mmm
local TIMESTAMP_PATTERN = "^(%d%d%d%d%-%d%d%-%d%d%.%d%d%-%d%d%-%d%d%.%d%d%d)"

--- Parse a chat filename into timestamp and optional slug.
---@param filename string bare filename (no directory)
---@return string|nil timestamp, string|nil slug
M.parse_filename = function(filename)
	local base = filename:gsub("%.md$", "")
	local ts = base:match(TIMESTAMP_PATTERN)
	if not ts then
		return nil, nil
	end
	local rest = base:sub(#ts + 1)
	if rest == "" then
		return ts, nil
	end
	-- rest starts with "_"
	local slug = rest:match("^_(.+)$")
	return ts, slug
end

--- Assemble a chat filename from timestamp and optional slug.
---@param timestamp string
---@param slug string|nil
---@return string
M.make_filename = function(timestamp, slug)
	if slug and slug ~= "" then
		return timestamp .. "_" .. slug .. ".md"
	end
	return timestamp .. ".md"
end

--- Return a glob pattern that matches any slug variant of this timestamp.
---@param timestamp string
---@return string
M.glob_pattern = function(timestamp)
	return timestamp .. "*.md"
end

return M
