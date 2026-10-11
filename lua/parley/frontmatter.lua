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
			local plain = value:match("^[\"']") and value or value:gsub("%s+#.*$", "")
			plain = M.unquote(plain)
			fm.fields[key] = plain ~= "" and plain or nil
		end
	end
	return nil
end

return M
