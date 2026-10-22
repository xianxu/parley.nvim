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

local function starts_html_tag(text, first)
    if text:sub(first, first) == "/" then first = first + 1 end
    if not text:sub(first, first):match("%a") then return false end
    local last = first + 1
    while text:sub(last, last):match("[%w-]") do last = last + 1 end
    local boundary = text:sub(last, last)
    return boundary == ">" or boundary == "/" or boundary:match("%s") ~= nil
end

local function autolink_end(text, first)
    -- Stop at the next angle delimiter so malformed nested openers cannot
    -- repeatedly scan/copy the same suffix.
    local last = text:find("[<>]", first + 1)
    if not last or text:sub(last, last) ~= ">" then return nil end
    local content = text:sub(first + 1, last - 1)
    local scheme = content:match("^(%a[%w+.-]*):[^%s<>]*$")
    local email = content:match("^[%w.!#$%%&'*+/=?^_`{|}~-]+@[%w.-]+%.[%a]+$")
    if (scheme and #scheme >= 2 and #scheme <= 32) or email then return last end
end

-- Extract the ordinary inline forms used in heading labels. Keep code and
-- escaped underscores literal; an underscore inside a word is not emphasis.
-- This deliberately does not implement reference-link definitions or a full
-- Markdown renderer. Delimiter indexes keep malformed input scans linear.
local function anchor_content(text)
    local parens, stack, ticks, next_tick = {}, {}, {}, {}
    local i = 1
    while i <= #text do
        local c = text:sub(i, i)
        if c == "\\" then
            i = i + 2
        elseif c == "`" then
            local last = i
            while text:sub(last + 1, last + 1) == "`" do last = last + 1 end
            ticks[#ticks + 1] = { first = i, last = last, width = last - i + 1 }
            i = last + 1
        else
            if c == "(" then stack[#stack + 1] = i end
            if c == ")" and #stack > 0 then
                parens[stack[#stack]] = i
                stack[#stack] = nil
            end
            i = i + 1
        end
    end
    local by_width = {}
    for n = #ticks, 1, -1 do
        local run = ticks[n]
        next_tick[run.first] = by_width[run.width]
        by_width[run.width] = run
    end

    local chars, literal = {}, {}
    local function append(value, protected)
        for n = 1, #value do
            chars[#chars + 1] = value:sub(n, n)
            literal[#chars] = protected
        end
    end
    i = 1
    while i <= #text do
        local c, close = text:sub(i, i), next_tick[i]
        local autolink = c == "<" and autolink_end(text, i)
        if c == "\\" and text:sub(i + 1, i + 1):match("%p") then
            append(text:sub(i + 1, i + 1), true)
            i = i + 2
        elseif c == "`" and close then
            local width = close.width
            append(text:sub(i + width, close.first - 1), true)
            i = close.last + 1
        elseif c == "]" and text:sub(i + 1, i + 1) == "(" and parens[i + 1] then
            i = parens[i + 1] + 1
        elseif autolink then
            append(text:sub(i + 1, autolink - 1), true)
            i = autolink + 1
        elseif c == "<" and (text:sub(i, i + 3) == "<!--" or starts_html_tag(text, i + 1)) then
            -- HTML rendering is outside the anchor contract; do not invent a
            -- raw-source slug for content whose visible text we cannot know.
            return nil
        elseif c == "&" and (text:find("^&[%a][%w]*;", i)
            or text:find("^&#%d+;", i) or text:find("^&#[xX]%x+;", i)) then
            return nil
        else
            append(c)
            i = i + 1
        end
    end

    local open = {}
    i = 1
    while i <= #chars do
        if chars[i] == "_" and not literal[i] then
            local last = i
            while chars[last + 1] == "_" and not literal[last + 1] do last = last + 1 end
            local before, after = chars[i - 1] or "", chars[last + 1] or ""
            local width = last - i + 1
            local can_open = after ~= "" and not after:match("%s")
                and (before == "" or before:match("[%s%p]"))
            local can_close = before ~= "" and not before:match("%s")
                and (after == "" or after:match("[%s%p]"))
            if can_close and open[width] then
                for n = open[width], open[width] + width - 1 do chars[n] = "" end
                for n = i, last do chars[n] = "" end
                open[width] = nil
            elseif can_open then
                open[width] = i
            end
            i = last + 1
        else
            i = i + 1
        end
    end
    return table.concat(chars):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Link anchors use GitHub-style ATX slugs, independently of outline depth.
function M.anchor_row(lines, fragment)
    fragment = fragment:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    local code = require("parley.document.lexical").code_block_memo(lines, {}, true, false)
    local used, counts = {}, {}
    for row, line in ipairs(lines) do
        local hashes, text = line:match("^ ? ? ?(#+)%s+(.+)$")
        if hashes and #hashes <= 6 and not code[row] then
            text = text:gsub("%s+#+%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
            text = anchor_content(text)
            if text then
                text = text:lower()
                local base = text:gsub("%p", function(c) return (c == "-" or c == "_") and c or "" end)
                    :gsub(" ", "-"):gsub("%s", "")
                local slug, count = base, counts[base] or 0
                while used[slug] do count = count + 1; slug = base .. "-" .. count end
                counts[base], used[slug] = count, true
                if slug == fragment then return row end
            end
        end
    end
end

return M
