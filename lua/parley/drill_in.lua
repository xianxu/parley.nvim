-- drill_in.lua — Pure-function drill-in marker handling for chat buffers.
--
-- Drill-in reuses the existing 🤖{T}[Q]{A}... marker syntax from the review
-- skill but with chat-side semantics:
--   - <C-g>q (visual mode) wraps a selection as 🤖{T}[] for the user to type
--     a question inside the empty [].
--   - On <C-g>g, ready drill-in markers (those with a leading {T} body AND a
--     trailing non-empty []) are gathered as `> T` + Q blockquotes prepended
--     to the next user turn, and stripped from the transcript back to plain T.
--   - <C-g>r resolves a discussion chain: every 🤖{T}[..]..  marker buffer-wide
--     is stripped back to plain T. Plain review markers (no {T} body) are left.
--
-- Section-parsing is delegated to review._parse_marker_sections so the syntax
-- stays single-source-of-truth across review (per-line) and drill-in
-- (multi-line, since drill-in operates on the joined buffer text).

local M = {}

local MARKER_CHAR = "🤖"
local MARKER_BYTE_LEN = 4

local _review
local function get_review()
    if not _review then _review = require("parley.skills.review") end
    return _review
end

-- Split a string on "\n" without requiring vim runtime (so tests can run pure).
local function split_lines(s)
    local lines = {}
    local start = 1
    while true do
        local nl = s:find("\n", start, true)
        if not nl then
            table.insert(lines, s:sub(start))
            return lines
        end
        table.insert(lines, s:sub(start, nl - 1))
        start = nl + 1
    end
end

--- Parse all 🤖 markers in joined text. Multi-line bracket content is supported
--- because the section parser walks the input text byte-by-byte.
--- @param text string
--- @return table[]  each entry: { byte_start, byte_end, sections, ready, pending, has_quoted_body }
---                  byte_start = position of 🤖 (inclusive, 1-based)
---                  byte_end   = position of the trailing } or ] (inclusive)
function M.parse(text)
    local parse_sections = get_review()._parse_marker_sections
    local markers = {}
    local search_start = 1
    while true do
        local pos = text:find(MARKER_CHAR, search_start, true)
        if not pos then break end
        local sections, end_pos = parse_sections(text, pos, MARKER_BYTE_LEN)
        if #sections > 0 then
            local first = sections[1]
            local last = sections[#sections]
            table.insert(markers, {
                byte_start = pos,
                byte_end = end_pos - 1,
                sections = sections,
                has_quoted_body = first.type == "agent" and first.text ~= "",
                ready = last.type == "user" and last.text ~= "",
                pending = last.type == "agent" and last.text ~= "",
            })
            search_start = end_pos
        else
            search_start = pos + MARKER_BYTE_LEN
        end
    end
    return markers
end

-- Splice a sorted (ascending byte_start) list of replacements into text.
local function splice(text, replacements)
    local result = text
    for i = #replacements, 1, -1 do
        local r = replacements[i]
        result = result:sub(1, r.byte_start - 1) .. r.replacement .. result:sub(r.byte_end + 1)
    end
    return result
end

--- Gather ready drill-in markers and strip each back to its {T} body in place.
--- Returns the gathered blocks (in document order) and the rewritten text.
--- Plain review markers and pending markers are left untouched.
--- @param text string
--- @return table[] blocks  list of { quoted, question } in document order
--- @return string new_text
function M.gather_and_strip(text)
    local markers = M.parse(text)
    local blocks = {}
    local replacements = {}
    for _, m in ipairs(markers) do
        if m.ready and m.has_quoted_body then
            local quoted = m.sections[1].text
            local question = m.sections[#m.sections].text
            table.insert(blocks, { quoted = quoted, question = question })
            table.insert(replacements, {
                byte_start = m.byte_start,
                byte_end = m.byte_end,
                replacement = quoted,
            })
        end
    end
    return blocks, splice(text, replacements)
end

--- Resolve every 🤖{T}[..](..)* marker back to plain T (any ready/pending state).
--- Plain review markers (no leading {T}) are left alone.
--- @param text string
--- @return string new_text
--- @return integer count
function M.resolve_all(text)
    local markers = M.parse(text)
    local replacements = {}
    for _, m in ipairs(markers) do
        if m.has_quoted_body then
            table.insert(replacements, {
                byte_start = m.byte_start,
                byte_end = m.byte_end,
                replacement = m.sections[1].text,
            })
        end
    end
    return splice(text, replacements), #replacements
end

--- Format one drill-in block as a blockquote-of-T followed by Q.
--- Multi-line T becomes multiple `> ` lines; multi-line Q is preserved verbatim.
--- @param quoted string
--- @param question string
--- @return string[]
function M.format_block(quoted, question)
    local out = {}
    for _, line in ipairs(split_lines(quoted)) do
        table.insert(out, "> " .. line)
    end
    for _, line in ipairs(split_lines(question)) do
        table.insert(out, line)
    end
    return out
end

--- Format multiple blocks with one blank line between consecutive blocks.
--- @param blocks table[]
--- @return string[]
function M.format_blocks(blocks)
    local out = {}
    for i, b in ipairs(blocks) do
        if i > 1 then table.insert(out, "") end
        for _, line in ipairs(M.format_block(b.quoted, b.question)) do
            table.insert(out, line)
        end
    end
    return out
end

--- Wrap text as a drill-in marker awaiting a question.
--- @param text string
--- @return string  "🤖{text}[]"
function M.wrap(text)
    return MARKER_CHAR .. "{" .. text .. "}[]"
end

--- Append formatted blocks to a list of buffer lines, separated from the
--- existing content by exactly one blank line (unless the input is empty).
--- Trailing empty lines on the input are trimmed first so the separator
--- count is deterministic regardless of incoming whitespace.
--- @param lines string[]
--- @param blocks table[]
--- @return string[]
function M.append_blocks(lines, blocks)
    local out = {}
    for _, l in ipairs(lines) do table.insert(out, l) end
    while #out > 0 and out[#out] == "" do table.remove(out) end
    local block_lines = M.format_blocks(blocks)
    if #out > 0 and #block_lines > 0 then table.insert(out, "") end
    for _, l in ipairs(block_lines) do table.insert(out, l) end
    return out
end

return M
