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

-- Link anchors use GitHub-style ATX slugs, independently of outline depth.
function M.anchor_row(lines, fragment)
    fragment = fragment:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    local code = require("parley.document.lexical").code_block_memo(lines, {}, true, false)
    local used, counts = {}, {}
    for row, line in ipairs(lines) do
        local hashes, text = line:match("^ ? ? ?(#+)%s+(.+)$")
        if hashes and #hashes <= 6 and not code[row] then
            text = text:gsub("%s+#+%s*$", ""):lower()
            local base = text:gsub("%p", function(c) return (c == "-" or c == "_") and c or "" end)
                :gsub("%s", "-")
            local slug, count = base, counts[base] or 0
            while used[slug] do count = count + 1; slug = base .. "-" .. count end
            counts[base], used[slug] = count, true
            if slug == fragment then return row end
        end
    end
end

return M
