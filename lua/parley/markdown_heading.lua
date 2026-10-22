-- The outline/editing ATX-heading dialect: column-zero, one to three hashes,
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

-- Parse strings only: no buffer, injection parser or persistent state is owned
-- by this command-time adapter. Grammar absence is handled by raw-text fallback.
local function parse_inline(text)
    local parser = vim.treesitter.get_string_parser(text, "markdown_inline", { injections = {} })
    local trees = parser:parse()
    return trees[1] and trees[1]:root()
end

local omitted = {
    emphasis_delimiter = true, code_span_delimiter = true,
    strikethrough_delimiter = true, link_destination = true, link_title = true,
}
local unsupported = { html_tag = true, entity_reference = true, numeric_character_reference = true }

local function heading_text(text, parse)
    local ok, root = pcall(parse, text)
    if not ok or not root then return text end
    local parts = {}
    local function walk(node)
        local kind = node:type()
        if unsupported[kind] then return false end
        if omitted[kind] then return true end
        local _, first, _, last = node:range()
        -- Ordinary text is represented by gaps between syntax children in the
        -- bundled grammar. Copy each gap once, excluding markup-owned spans.
        local pos = first
        for child in node:iter_children() do
            local _, child_first, _, child_last = child:range()
            parts[#parts + 1] = text:sub(pos + 1, child_first)
            if not walk(child) then return false end
            pos = child_last
        end
        parts[#parts + 1] = text:sub(pos + 1, last)
        return true
    end
    if not walk(root) then return nil end
    return table.concat(parts)
end

-- Identical compact keys on both sides make GitHub punctuation spelling
-- non-load-bearing. Keep non-ASCII codepoints unchanged except the two approved
-- punctuation blocks; no Unicode database or buffer-dependent word class.
local function key(text)
    local parts = {}
    for _, cp in ipairs(vim.fn.str2list(text, true)) do
        if cp >= 65 and cp <= 90 then cp = cp + 32 end
        if (cp >= 97 and cp <= 122) or (cp >= 48 and cp <= 57) then
            parts[#parts + 1] = string.char(cp)
        elseif cp >= 128 and not (cp >= 0x2000 and cp <= 0x206F)
            and not (cp >= 0x3000 and cp <= 0x303F) then
            parts[#parts + 1] = vim.fn.nr2char(cp, true)
        end
    end
    return table.concat(parts)
end

-- Integration: bundled treesitter structure plus codepoint decoding. Outline
-- and editing retain their independent level() dialect. The optional parser
-- adapter exposes unavailable-grammar behavior without changing editor globals.
function M.anchor_row(lines, fragment, opts)
    fragment = fragment:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    local full = key(fragment)
    if full == "" then return nil end
    local base, suffix = fragment:match("^(.-)%-(%d+)$")
    local duplicate = suffix and tonumber(suffix)
    base = base and key(base)
    local parse = (opts and opts.parse) or parse_inline
    local code = require("parley.document.lexical").code_block_memo(lines, {}, true, false)
    local count, candidate = 0, nil
    for row, line in ipairs(lines) do
        local hashes, text = line:match("^ ? ? ?(#+)%s+(.+)$")
        if hashes and #hashes <= 6 and not code[row] then
            text = text:gsub("%s+#+%s*$", "")
            text = heading_text(text, parse)
            local canonical = text and key(text)
            if canonical and canonical ~= "" then
                -- A complete natural numeric heading wins even when it occurs
                -- after a potential duplicate; only return that duplicate later.
                if canonical == full then return row end
                if duplicate and duplicate >= 1 and base ~= "" and canonical == base then
                    if count == duplicate then candidate = row end
                    count = count + 1
                end
            end
        end
    end
    return candidate
end

return M
