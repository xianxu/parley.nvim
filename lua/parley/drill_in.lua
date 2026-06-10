-- drill_in.lua — Pure-function 🤖 marker handling.
--
-- A marker is the 🤖 marker syntax with an optional first-slot reference
-- (`<quoted body>` or `~strike body~`, mutually exclusive):
--
--    🤖(<T>|~D~)?([U]|{A})*
--
-- Used in two flows:
--
--   1. **Drill-in (chat respond).** On `<C-g>g`, every "ready" marker (last
--      section is a non-empty [], strike markers excluded) is gathered and
--      stripped from the inline text into a quoted block prepended to the
--      next user turn. See `M.gather_and_strip` and `M.format_block`. Marker
--      shapes:
--        * `🤖<Q>[U]`          → block `> Q` / `U`            ; inline → `Q`
--        * `🤖[U]`             → block `> Q̂` / `U`            ; inline removed
--        * `🤖<Q>[U1]{A1}[U2]` → block `> Q` / `> User: U1` /
--                                `> Agent: A1` / `U2`        ; inline → `Q`
--        * `🤖[U1]{A1}[U2]`    → block `> Q̂` / `> User: U1` /
--                                `> Agent: A1` / `U2`         ; inline removed
--      For the unquoted forms, the block quote `Q̂` is *inferred* from the reply
--      prose around the marker (#127) — an unquoted comment is a quoted comment
--      whose anchor we recover, so it routes through the same block pipeline.
--      See `M.generate_snippet`. When no anchor can be recovered the block has
--      no `>` line (degrades to the pre-#127 behavior).
--      Markers ending in `{}` (pending agent turns) and `~D~` markers
--      (proposals, not questions) stay inline.
--
--   2. **Accept / reject (review-convention §5).** `<M-a>` and `<M-r>`
--      resolve the marker at cursor per the §5 table — see `M.resolve`.
--      Canonical spec: `../ariadne/workshop/targets/review-convention.md`.
--      Bulk resolve was dropped in #124 M2; resolution is always
--      operator-initiated per marker (or agentic, §6).
--
-- Section-parsing is delegated to review._parse_marker_sections so the
-- syntax stays single-source-of-truth across review (per-line) and
-- drill-in (multi-line; drill-in operates on joined buffer text).
--
-- See: #123 (quoted-body slot), #124 (strike family + accept/reject split).

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

-- ─── Snippet inference (#127) ───────────────────────────────────────────
-- An unquoted ready marker `🤖[U]` carries no anchor: stripping it would drop
-- the comment into the next turn with no pointer back. `generate_snippet`
-- recovers a verbatim anchor from the reply prose *around* the marker, so the
-- unquoted form routes through the same quoted pipeline as `🤖<Q>[U]` — we just
-- infer the Q the operator didn't type. Pure: a function of text + the marker's
-- byte range (+ optional turn boundaries). The anchor is a meaning-anchor, not
-- a position token; precision is intentionally forgiving (see #127 Spec).

local SNIPPET_MIN_WORDS = 10
local SNIPPET_MAX_WORDS = 20

-- Index `text` into lines, each tagged with its 1-based byte offset (`off`).
local function index_lines(text)
    local out = {}
    local off = 1
    for _, line in ipairs(split_lines(text)) do
        table.insert(out, { line = line, off = off })
        off = off + #line + 1 -- +1 for the stripped "\n"
    end
    return out
end

-- Does `line` begin a non-prose turn region (a configured prefix)? Such lines
-- are hard stops for the backward scan — never cross into another turn or a
-- 🧠:/📎: block, and never use the prefix line itself as anchor prose.
local function is_boundary_line(line, boundaries)
    if not boundaries then return false end
    for _, p in ipairs(boundaries) do
        if p ~= "" and line:sub(1, #p) == p then return true end
    end
    return false
end

local function is_blank(line) return line:match("^%s*$") ~= nil end
local function word_count(s) local n = 0; for _ in s:gmatch("%S+") do n = n + 1 end; return n end

local function collapse_ws(s)
    return (s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Strip any 🤖-markers embedded in candidate prose — a neighboring marker's raw
-- bytes can fall inside a snippet window; they are not prose. Reuses M.parse.
local function strip_markers(s)
    local markers = M.parse(s)
    local repls = {}
    for _, m in ipairs(markers) do
        table.insert(repls, { byte_start = m.byte_start, byte_end = m.byte_end, replacement = "" })
    end
    return splice(s, repls)
end

-- Split prose into sentences at `.!?` followed by whitespace/end (punctuation
-- kept with its sentence). Forgiving: mis-snaps on abbreviations/decimals are
-- accepted per the meaning-anchor philosophy.
local function split_sentences(s)
    local sents, cur = {}, ""
    for i = 1, #s do
        local c = s:sub(i, i)
        cur = cur .. c
        if c:match("[%.%!%?]") then
            local nxt = s:sub(i + 1, i + 1)
            if nxt == "" or nxt:match("%s") then
                table.insert(sents, cur)
                cur = ""
            end
        end
    end
    if cur:match("%S") then table.insert(sents, cur) end
    return sents
end

-- Keep only the last MAX words; prefix "… " when truncated.
local function cap_tail(words)
    if #words <= SNIPPET_MAX_WORDS then return table.concat(words, " ") end
    local kept = {}
    for i = #words - SNIPPET_MAX_WORDS + 1, #words do table.insert(kept, words[i]) end
    return "… " .. table.concat(kept, " ")
end

-- Inline anchor: the prose immediately before the marker, snapped back to a
-- sentence boundary, ≥MIN words (extending across boundaries) and ≤MAX words.
local function tail_snippet(before)
    before = collapse_ws(strip_markers(before))
    if before == "" then return "" end
    local sents = split_sentences(before)
    local acc, count = {}, 0
    for i = #sents, 1, -1 do
        table.insert(acc, 1, sents[i])
        count = count + word_count(sents[i])
        if count >= SNIPPET_MIN_WORDS then break end
    end
    local words = {}
    for w in collapse_ws(table.concat(acc, " ")):gmatch("%S+") do table.insert(words, w) end
    return cap_tail(words)
end

-- Standalone anchor: the first sentence of a previous prose block, ≤MAX words.
local function first_sentence_snippet(block)
    block = collapse_ws(strip_markers(block))
    if block == "" then return "" end
    local first = split_sentences(block)[1] or block
    local words = {}
    for w in first:gmatch("%S+") do table.insert(words, w) end
    if #words <= SNIPPET_MAX_WORDS then return first end
    local kept = {}
    for i = 1, SNIPPET_MAX_WORDS do table.insert(kept, words[i]) end
    return table.concat(kept, " ") .. " …"
end

--- Infer a verbatim anchor snippet for an unquoted marker from surrounding
--- reply prose. Pure.
--- @param text string           joined reply text
--- @param marker table          a parsed marker (M.parse) — uses byte_start/byte_end
--- @param opts table|nil        { boundaries = string[] } turn-prefix hard stops
--- @return string               anchor snippet, or "" when none can be recovered
function M.generate_snippet(text, marker, opts)
    opts = opts or {}
    local boundaries = opts.boundaries
    local idx = index_lines(text)

    -- Locate the marker's line + its column span within that line.
    local L, before_on_line, after_on_line
    for i, e in ipairs(idx) do
        local line_end = e.off + #e.line -- byte just past the line's content
        if marker.byte_start >= e.off and marker.byte_start <= line_end then
            L = i
            before_on_line = e.line:sub(1, marker.byte_start - e.off)
            after_on_line = e.line:sub(marker.byte_end - e.off + 2)
            break
        end
    end
    if not L then return "" end

    -- If the marker sits on a boundary (prefix) line, drop the prefix from the
    -- before-text so the prefix never leaks into the anchor.
    if boundaries then
        for _, p in ipairs(boundaries) do
            if p ~= "" and before_on_line:sub(1, #p) == p then
                before_on_line = before_on_line:sub(#p + 1)
                break
            end
        end
    end

    -- Previous prose block (scan up past blanks; stop at a boundary/top).
    local function prev_block_first_sentence()
        local i = L - 1
        while i >= 1 and is_blank(idx[i].line) do i = i - 1 end
        if i < 1 or is_boundary_line(idx[i].line, boundaries) then return "" end
        local top = i
        while top - 1 >= 1
            and not is_blank(idx[top - 1].line)
            and not is_boundary_line(idx[top - 1].line, boundaries) do
            top = top - 1
        end
        local parts = {}
        for k = top, i do table.insert(parts, idx[k].line) end
        return first_sentence_snippet(table.concat(parts, " "))
    end

    -- Prose preceding the marker within its own paragraph (stop at blank/boundary).
    local function inline_before()
        local top = L
        while top - 1 >= 1
            and not is_blank(idx[top - 1].line)
            and not is_boundary_line(idx[top - 1].line, boundaries) do
            top = top - 1
        end
        local parts = {}
        for k = top, L - 1 do table.insert(parts, idx[k].line) end
        table.insert(parts, before_on_line)
        return table.concat(parts, " ")
    end

    local has_before = before_on_line:match("%S") ~= nil
    local marker_only = (not has_before) and (after_on_line:match("%S") == nil)

    if marker_only then
        -- Standalone iff blank/boundary-separated above AND below.
        local above_sep = (L == 1) or is_blank(idx[L - 1].line) or is_boundary_line(idx[L - 1].line, boundaries)
        local below_sep = (L == #idx) or is_blank(idx[L + 1].line) or is_boundary_line(idx[L + 1].line, boundaries)
        if above_sep and below_sep then
            return prev_block_first_sentence()
        end
        -- Bare marker mid-paragraph → inline from preceding lines.
    end

    -- Inline (or bare-mid-paragraph): preceding words; fall back to the
    -- previous block when there is nothing before the marker.
    local snip = tail_snippet(inline_before())
    if snip ~= "" then return snip end
    return prev_block_first_sentence()
end

--- Gather ready markers and strip each from the inline text.
--- - Marker with `<Q>` body → inline replaced by Q.
--- - Marker without `<Q>` body → inline removed entirely; its block quote is
---   inferred from surrounding prose (#127) when one can be recovered.
--- Pending markers (last section non-empty `{}`) and annotation-only markers
--- (no ready `[]` last section) are left untouched.
--- @param text string
--- @param opts table|nil  { boundaries = string[] } passed to generate_snippet
--- @return table[] blocks  list of { quoted = string|nil, sections = list } in document order
--- @return string new_text
function M.gather_and_strip(text, opts)
    local markers = M.parse(text)
    local blocks = {}
    local replacements = {}
    for _, m in ipairs(markers) do
        if m.ready then
            -- An explicit <Q> body restores inline to Q and anchors the block.
            -- An unquoted marker is removed inline (the snippet is *already* in
            -- the reply — do not re-insert it) and its block quote is inferred.
            local explicit = m.quoted and m.quoted.text or nil
            local block_quote = explicit
            if not block_quote then
                local snip = M.generate_snippet(text, m, opts)
                if snip ~= "" then block_quote = snip end
            end
            table.insert(blocks, { quoted = block_quote, sections = m.sections })
            table.insert(replacements, {
                byte_start = m.byte_start,
                byte_end = m.byte_end,
                replacement = explicit or "",
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
