-- The repo's one ATX-heading dialect: column-zero, one to three hashes,
-- followed by a literal space. Stated once so entity_range, outline and the
-- document tokenizer cannot drift apart (ARCH-DRY); document/lexical.lua keeps
-- its own inline byte-scanner for the hot incremental path and is pinned to
-- this dialect by tests/unit/markdown_heading_conformance_spec.lua.
local M = {}

M.MAX_LEVEL = 3

--- Heading level of a line, or nil when the line is not a heading.
--- Pure function.
--- @param line string|nil
--- @return number|nil
function M.level(line)
	if type(line) ~= "string" then
		return nil
	end
	local hashes = line:match("^(#+) ")
	if not hashes or #hashes > M.MAX_LEVEL then
		return nil
	end
	return #hashes
end

return M
