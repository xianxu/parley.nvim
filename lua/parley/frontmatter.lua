-- parley.frontmatter — a markdown file's leading `---` block (#316). PURE.
--
-- Flat `key: value` lines only; nothing here pulls in a YAML library. Keys may
-- carry `-` (`process-instruction`). A value comes in two readings: `fields`
-- drops an inline ` # comment` and unquotes, `raw` is the whole text after the
-- colon, for values whose own text may hold a `#`.

local M = {}

--- Strip one level of YAML scalar quoting: "…" (with `\"` and `\\` escapes)
--- or '…' (with `''`). Anything else is returned unchanged.
---@param s string
---@return string
M.unquote = function(s)
	local inner = s:match('^"(.*)"$')
	if inner then
		return (inner:gsub("\\(.)", "%1"))
	end
	inner = s:match("^'(.*)'$")
	if inner then
		return (inner:gsub("''", "'"))
	end
	return s
end

--- Double-quote a value, escaping the escape character and the quote.
---@param s string
---@return string
M.quote = function(s)
	return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

--- Whether a plain scalar would not read back as itself under a strict YAML
--- reader (sdlc parses issue frontmatter with yaml.v3: `a: [x] y` is an error).
---@param s string
---@return boolean
M.needs_quote = function(s)
	return s:match("^[%[%]{}\"'&*!|>%%@`#,?:-]") ~= nil
		or s:find(": ", 1, true) ~= nil
		or s:find(" #", 1, true) ~= nil
		or s:match("%s$") ~= nil
end

--- The quoted scalar at `start` (default 1) of `s` ("…" with backslash escapes, '…' with
--- ''), quotes included; nil when no closed scalar starts there.
---@param s string
---@param start? integer byte offset
---@return string|nil
M.quoted_span = function(s, start)
	start = start or 1
	local q = s:sub(start, start)
	if q ~= '"' and q ~= "'" then
		return nil
	end
	local i = start + 1
	while i <= #s do
		local c = s:sub(i, i)
		if q == '"' and c == "\\" then
			i = i + 2
		elseif c == q then
			if q == "'" and s:sub(i + 1, i + 1) == "'" then
				i = i + 2
			else
				return s:sub(start, i)
			end
		else
			i = i + 1
		end
	end
	return nil
end

-- Anchored edge scans avoid backtracking across long interior whitespace runs.
local function rtrim(s)
	local last = #s
	while last > 0 and s:sub(last, last):match("%s") do
		last = last - 1
	end
	return s:sub(1, last)
end

--- Parse the frontmatter at the top of `lines`.
---@param lines string[]
---@return table|nil { fields, raw, lnum, close } (lnum/close are 1-based), nil without a closed block
M.parse = function(lines)
	if lines[1] ~= "---" then
		return nil
	end
	local fm = { fields = {}, raw = {}, lnum = {} }
	for i = 2, #lines do
		if lines[i] == "---" then
			fm.close = i
			return fm
		end
		local key, value = lines[i]:match("^([%w_][%w_-]*):%s*(.*)$")
		if key then
			value = rtrim(value)
			key = key:lower()
			fm.raw[key] = value
			fm.lnum[key] = i
			-- A quoted scalar ends at its closing quote (a comment may follow).
			local span = M.quoted_span(value)
			local comment = not span and value:find("%s#")
			local plain = span and M.unquote(span) or (comment and rtrim(value:sub(1, comment - 1)) or value)
			fm.fields[key] = plain ~= "" and plain or nil
		end
	end
	return nil
end

return M
