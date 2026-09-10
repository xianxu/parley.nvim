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

--- Order the candidates a timestamp glob returned, for one reference. PURE.
---
--- The timestamp prefix IS the identity of a chat file; the trailing slug is
--- for human inspection and carries no meaning to resolution (#224). So a glob
--- over `<timestamp>*` normally returns exactly one file and this is trivial.
--- It exists for the case that is not:
---
---   * the reference names a file that is still there → that exact name wins,
---     whatever else matched;
---   * otherwise the pick is the lexicographically first, which is stable
---     across machines and across the order the filesystem happens to hand
---     back — and the caller reports the ambiguity.
---
--- The rule it replaces sorted by LENGTH and took the longest, encoding
--- "prefer the one that has a slug". That is right until two slugged variants
--- exist, at which point it silently prefers whichever has the wordier topic.
---
--- `names` arrives in SEARCH ORDER — the reference's own directory first, then
--- the chat roots — and that order is the tie-break for non-exact matches. It
--- has to be: a reference reading `sub/<ts>.md` whose target has been renamed
--- must resolve inside `sub/`, and sorting the full paths lexicographically
--- instead would hand it whichever root sorts first (#224 BR-14). The caller
--- sorts within each directory, so nothing depends on filesystem order.
---
---@param reference string # the basename the reference used
---@param names string[] # candidate paths whose timestamp matched, in search order
---@return string[] # ordered picks, best first
---@return boolean # true when the choice was ambiguous (>1 and no exact match)
M.resolve_candidates = function(reference, names)
    local ordered = {}
    for _, n in ipairs(names or {}) do
        ordered[#ordered + 1] = n
    end

    for i, n in ipairs(ordered) do
        if vim.fn.fnamemodify(n, ":t") == reference then
            table.remove(ordered, i)
            table.insert(ordered, 1, n)
            return ordered, false
        end
    end
    return ordered, #ordered > 1
end

--- Rewrite one reference inside a line. PURE.
---
--- Returns the new line, or nil when `old_basename` does not appear in it —
--- nil means "nothing to do", which is how the caller avoids dirtying a buffer
--- for a no-op.
---
--- The `%`-escape on the replacement is load-bearing: Lua's `gsub` reads `%` in
--- the replacement string as a capture reference, so a filename containing one
--- would either raise or silently interpolate. That trap already cost a round
--- in #214.
---
---@param line string
---@param old_basename string
---@param new_basename string
---@return string|nil
M.rewrite_reference = function(line, old_basename, new_basename)
    if old_basename == new_basename then
        return nil
    end
    if not line:find(old_basename, 1, true) then
        return nil
    end
    local safe_new = new_basename:gsub("%%", "%%%%")
    -- gsub-safe: `safe_new` is %-escaped on the line above
    return (line:gsub(vim.pesc(old_basename), safe_new))
end

return M
