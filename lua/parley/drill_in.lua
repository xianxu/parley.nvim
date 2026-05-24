-- drill_in.lua — Pure-function drill-in marker handling for chat buffers.
--
-- A drill-in marker is the 🤖 marker syntax with an optional first-slot
-- reference (`<quoted body>` or `~strike body~`, mutually exclusive):
--
--    🤖(<T>|~D~)?([U]|{A})*
--
-- Drill-in semantics in chat buffers (see #123):
--
--   - <C-g>q (visual mode) wraps a selection as 🤖<T>[] for the user to type
--     a question inside the empty [].
--   - On <C-g>g (chat respond), every "ready" marker (last section is a
--     non-empty []) is gathered and stripped from the inline text:
--       * `🤖<Q>[U]`           → block `> Q` / `U`            ; inline → `Q`
--       * `🤖[U]`              → block `U`                   ; inline removed
--       * `🤖<Q>[U1]{A1}[U2]`  → block `> Q` / `> User: U1`
--                                       / `> Agent: A1` / `U2`; inline → `Q`
--       * `🤖[U1]{A1}[U2]`     → block `> User: U1`
--                                       / `> Agent: A1` / `U2`; inline removed
--     Markers ending in `{}` (annotations / pending agent turns) stay inline.
--   - <C-g>r resolves a marker back to its accepted text, regardless of state:
--       * Marker with `<T>` body → stripped to plain T (T wins even when a
--         trailing `{A}` exists).
--       * Marker without `<T>` whose last section is a non-empty `{A}` →
--         stripped to A. This is the "accept agent suggestion" form: 🤖{A},
--         🤖[U]{A}, 🤖{A1}[U]{A2} all collapse to the final `{}` body.
--       * Other markers without `<T>` (e.g. `🤖[U]`, trailing `{}` is empty)
--         are left alone — there is nothing to accept yet.
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
--- @return table[]  each entry: { byte_start, byte_end, quoted, strike,
---                                 sections, ready, pending, has_quoted_body }
---                  byte_start = position of 🤖 (inclusive, 1-based)
---                  byte_end   = position of the trailing `>`/`~`/`]`/`}` (inclusive)
---                  quoted     = { text, byte_start, byte_end } or nil — `<X>` ref
---                  strike     = { text, byte_start, byte_end } or nil — `~X~` ref
---                  quoted and strike are mutually exclusive.
function M.parse(text)
    local parse_sections = get_review()._parse_marker_sections
    local markers = {}
    local search_start = 1
    while true do
        local pos = text:find(MARKER_CHAR, search_start, true)
        if not pos then break end
        local sections, end_pos, quoted, strike = parse_sections(text, pos, MARKER_BYTE_LEN)
        -- Normalize: empty <> / ~~ carry no information — drop them so
        -- downstream gather/resolve don't have to special-case them.
        if quoted and quoted.text == "" then quoted = nil end
        if strike and strike.text == "" then strike = nil end
        if #sections > 0 or quoted or strike then
            local last = sections[#sections]
            table.insert(markers, {
                byte_start = pos,
                byte_end = end_pos - 1,
                quoted = quoted,
                strike = strike,
                sections = sections,
                has_quoted_body = quoted ~= nil,
                -- Strike markers are proposals, not questions — they never
                -- count as ready, even when a trailing [] is present (e.g.
                -- 🤖~D~[N] is a human-authored replacement).
                ready = (not strike) and (last ~= nil) and last.type == "user" and last.text ~= "",
                pending = (last ~= nil) and last.type == "agent" and last.text ~= "",
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

--- Gather ready markers and strip each from the inline text.
--- - Marker with `<Q>` body → inline replaced by Q.
--- - Marker without `<Q>` body → inline removed entirely.
--- Pending markers (last section non-empty `{}`) and annotation-only markers
--- (no ready `[]` last section) are left untouched.
--- @param text string
--- @return table[] blocks  list of { quoted = string|nil, sections = list } in document order
--- @return string new_text
function M.gather_and_strip(text)
    local markers = M.parse(text)
    local blocks = {}
    local replacements = {}
    for _, m in ipairs(markers) do
        if m.ready then
            local quoted_text = m.quoted and m.quoted.text or nil
            table.insert(blocks, { quoted = quoted_text, sections = m.sections })
            table.insert(replacements, {
                byte_start = m.byte_start,
                byte_end = m.byte_end,
                replacement = quoted_text or "",
            })
        end
    end
    return blocks, splice(text, replacements)
end

--- Resolve a marker to its final inline text per the review-convention §5
--- table. Pure — no buffer side effects. Used by accept_at / reject_at;
--- exposed for direct testing.
---
--- Rules (see ariadne/workshop/targets/review-convention.md §5):
---   1. `<X>` anchor preserves X (both modes).
---   2. `~D~` anchor:
---        chain ∅       → accept "" / reject D
---        chain {N}     → accept N  / reject D
---        chain [N]     → accept N  / reject D
---        longer chain  → treat as base deletion: accept "" / reject D
---                        (dialogue past the proposal is ambiguous; spec
---                        only enumerates single-section chains, so we
---                        fall back to the bare proposal rather than
---                        guess at intent)
---   3. No anchor:
---        bare `{R}` (chain length 1, single agent block) is the only
---        proposal: accept → R, reject → "".
---        Everything else (just `[H]`, dialogue chains, longer) is pure
---        commentary: "" both modes.
--- @param marker table  parsed marker (from M.parse)
--- @param mode string   "accept" | "reject"
--- @return string
function M.resolve(marker, mode)
    assert(mode == "accept" or mode == "reject",
        "drill_in.resolve: mode must be 'accept' or 'reject', got " .. tostring(mode))
    if marker.quoted then
        return marker.quoted.text
    end
    if marker.strike then
        if mode == "accept" and #marker.sections == 1 then
            return marker.sections[1].text
        end
        if mode == "reject" then
            return marker.strike.text
        end
        return ""
    end
    -- No anchor: only a bare `{R}` is a proposal; everything else is commentary.
    if #marker.sections == 1 and marker.sections[1].type == "agent" then
        if mode == "accept" then return marker.sections[1].text end
        return ""
    end
    return ""
end

local function resolve_at_with_mode(text, offset, mode)
    local markers = M.parse(text)
    for _, m in ipairs(markers) do
        if offset >= m.byte_start and offset <= m.byte_end then
            local replacement = M.resolve(m, mode)
            local new_text = text:sub(1, m.byte_start - 1) .. replacement .. text:sub(m.byte_end + 1)
            return new_text, m
        end
    end
    return text, nil
end

--- Accept the marker at `offset` per §5 — splice its accepted text in place.
--- @param text string
--- @param offset integer  byte offset (1-based) into `text`
--- @return string new_text
--- @return table|nil marker  the resolved marker, or nil if cursor was outside any marker
function M.accept_at(text, offset)
    return resolve_at_with_mode(text, offset, "accept")
end

--- Reject the marker at `offset` per §5 — splice its rejection text in place.
--- @param text string
--- @param offset integer
--- @return string new_text
--- @return table|nil marker
function M.reject_at(text, offset)
    return resolve_at_with_mode(text, offset, "reject")
end

--- Format one drill-in block for the next user turn.
---
--- Layout:
---   [`> <quoted line 1>`]              (only if block.quoted is non-nil)
---   [`> <quoted line 2>` ...]
---   `> User: <U1 line 1>`              (per chain section, except final)
---   `> <U1 line 2>`                    (continuation lines stay quoted)
---   `> Agent: <A1 line 1>`
---   ...
---   `<final user turn line 1>`         (unprefixed, the actual prompt)
---   `<final user turn line 2>`
---
--- block = { quoted = string|nil, sections = list-of-{type,text} }
--- The last section MUST be a user turn (caller filters by `m.ready`).
--- @param block table
--- @return string[]
function M.format_block(block)
    local out = {}
    if block.quoted then
        for _, line in ipairs(split_lines(block.quoted)) do
            table.insert(out, "> " .. line)
        end
    end
    local n = #block.sections
    for i = 1, n - 1 do
        local s = block.sections[i]
        local label = s.type == "user" and "User: " or "Agent: "
        local s_lines = split_lines(s.text)
        for j, line in ipairs(s_lines) do
            if j == 1 then
                table.insert(out, "> " .. label .. line)
            else
                table.insert(out, "> " .. line)
            end
        end
    end
    if n >= 1 then
        local last = block.sections[n]
        for _, line in ipairs(split_lines(last.text)) do
            table.insert(out, line)
        end
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
        for _, line in ipairs(M.format_block(b)) do
            table.insert(out, line)
        end
    end
    return out
end

--- Wrap text as a drill-in marker awaiting a question.
--- @param text string
--- @return string  "🤖<text>[]"
function M.wrap(text)
    return MARKER_CHAR .. "<" .. text .. ">[]"
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
