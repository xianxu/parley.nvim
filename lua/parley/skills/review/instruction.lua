-- Instruction — the `process-instruction:` frontmatter line (#316). PURE.
--
-- `[name][name] free text`: each leading `[name]` names a stock prompt (a
-- modes/<name>.md file, or a unique prefix of one: `[copy-edit]`), the rest is
-- the operator's addition. No `[name]` means the free-form mode. Several modes
-- contribute their briefs; the first one's knobs (scope, deletions, frontier)
-- govern the round, since one round has one set of directives.

local mode = require("parley.skills.review.mode")

local M = {}

M.DEFAULT_MODE = "free-form"

--- "[a][b] text" → { names = {"a","b"}, text = "text" }.
---@param value string|nil
---@return table
M.parse = function(value)
	local rest = vim.trim(value or "")
	local names = {}
	while true do
		local name, after = rest:match("^%[([^%]]*)%]%s*(.*)$")
		if not name then
			break
		end
		names[#names + 1] = vim.trim(name)
		rest = after
	end
	return { names = names, text = vim.trim(rest) }
end

local function known(modes)
	local out = {}
	for _, m in ipairs(modes) do
		out[#out + 1] = m.name
	end
	return table.concat(out, ", ")
end

--- Names → Modes: an exact name, else the one mode the name prefixes.
---@param names string[]
---@param modes table[]  from mode.list
---@return table[]|nil, string|nil err
M.resolve = function(names, modes)
	local out = {}
	for _, name in ipairs(names) do
		local exact, prefixed = nil, {}
		for _, m in ipairs(modes) do
			if m.name == name then
				exact = m
			elseif name ~= "" and m.name:sub(1, #name) == name then
				prefixed[#prefixed + 1] = m
			end
		end
		local hit = exact or (#prefixed == 1 and prefixed[1]) or nil
		if not hit then
			local why = #prefixed > 1 and "is ambiguous" or "is not a stock prompt"
			return nil, ("[%s] %s; known: %s"):format(name, why, known(modes))
		end
		out[#out + 1] = hit
	end
	return out
end

--- The instruction value → { modes, text }, free-form when none is named.
---@param value string|nil
---@param modes table[]
---@return table|nil, string|nil err
M.expand = function(value, modes)
	local parsed = M.parse(value)
	local names = #parsed.names > 0 and parsed.names or { M.DEFAULT_MODE }
	local resolved, err = M.resolve(names, modes)
	if not resolved then
		return nil, err
	end
	return { modes = resolved, text = parsed.text }
end

--- The round's brief: each mode's prompt, the first mode's directives, then
--- the operator's text. Shared by the review skill's system prompt and the
--- message sent to a Couch slot.
---@param modes table[]
---@param text string|nil
---@return string
M.brief = function(modes, text)
	local parts = {}
	for _, m in ipairs(modes) do
		parts[#parts + 1] = "## Review mode: " .. m.name .. "\n" .. m.body
	end
	if modes[1] then
		parts[#parts + 1] = mode.directives(modes[1])
	end
	if text and text ~= "" then
		parts[#parts + 1] = "## Operator instruction\n" .. text
	end
	return table.concat(parts, "\n\n")
end

--- Neutral inputs for the canonical round; its flag table owns semantics.
--- No selection retains the local marker-only invocation's parser defaults.
---@param modes table[]
---@param text string|nil
---@return string
M.context = function(modes, text)
    local parts = {}
    for _, m in ipairs(modes) do
        parts[#parts + 1] = "## Review mode: " .. m.name .. "\n" .. m.body
    end
    local first = modes[1] or {}
    parts[#parts + 1] = "## Selected round flags\n"
        .. "scope: " .. (first.scope or "markers-only") .. "\n"
        .. "deletions: " .. (first.deletions or "propose-strike") .. "\n"
        .. "frontier: " .. (first.frontier or "on")
    if text and text ~= "" then
        parts[#parts + 1] = "## Operator instruction\n" .. text
    end
    return table.concat(parts, "\n\n")
end

--- Completion words for `[`: every mode name, closed.
---@param modes table[]
---@return string[]
M.complete = function(modes)
	local out = {}
	for _, m in ipairs(modes) do
		out[#out + 1] = m.name .. "]"
	end
	return out
end

return M
