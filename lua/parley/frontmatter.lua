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

--- The leading quoted scalar of `s` ("…" with backslash escapes, '…' with
--- ''), quotes included; nil when `s` does not start with a closed one.
---@param s string
---@return string|nil
M.quoted_span = function(s)
	local q = s:sub(1, 1)
	if q ~= '"' and q ~= "'" then
		return nil
	end
	local i = 2
	while i <= #s do
		local c = s:sub(i, i)
		if q == '"' and c == "\\" then
			i = i + 2
		elseif c == q then
			if q == "'" and s:sub(i + 1, i + 1) == "'" then
				i = i + 2
			else
				return s:sub(1, i)
			end
		else
			i = i + 1
		end
	end
	return nil
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
		local key, value = lines[i]:match("^([%w_][%w_-]*):%s*(.-)%s*$")
		if key then
			key = key:lower()
			fm.raw[key] = value
			fm.lnum[key] = i
			-- A quoted scalar ends at its closing quote (a comment may follow).
			local span = M.quoted_span(value)
			local plain = span and M.unquote(span) or (value:gsub("%s+#.*$", ""))
			fm.fields[key] = plain ~= "" and plain or nil
		end
	end
	return nil
end

return M
