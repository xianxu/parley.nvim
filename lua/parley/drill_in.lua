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

-- Topmost line of the contiguous content block ending at line `start` (scan up
-- while the line above is neither blank nor a turn boundary). Shared by the
-- inline and previous-block scans.
local function paragraph_top(idx, start, boundaries)
    local top = start
    while top - 1 >= 1
        and not is_blank(idx[top - 1].line)
        and not is_boundary_line(idx[top - 1].line, boundaries) do
        top = top - 1
    end
    return top
end

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

-- Tokenize byte range [lo, hi] of `text` into words tagged with absolute byte
-- offsets {s, e}. Works directly on the original text so the selected span maps
-- straight back to byte positions (needed to enclose the span — #127 brackets).
local function tokenize(text, lo, hi)
    local toks = {}
    local i = lo
    while i <= hi do
        while i <= hi and text:sub(i, i):match("%s") do i = i + 1 end
        if i > hi then break end
        local s = i
        while i <= hi and not text:sub(i, i):match("%s") do i = i + 1 end
        toks[#toks + 1] = { s = s, e = i - 1 }
    end
    return toks
end

-- `.!?` are ASCII (single byte), so the last byte of a token suffices.
local function ends_sentence(text, tok) return text:sub(tok.e, tok.e):match("[%.%!%?]") ~= nil end

-- Inline span: the smallest sentence-aligned suffix of [lo,hi] with ≥MIN words,
-- capped to the last MAX. Returns span_start, span_end (absolute), truncated.
local function select_tail(text, lo, hi)
    local toks = tokenize(text, lo, hi)
    local n = #toks
    if n == 0 then return nil end
    local chosen = 1 -- token 1 always begins a sentence; whole region is the floor
    for k = 1, n do
        if (k == 1 or ends_sentence(text, toks[k - 1])) and (n - k + 1) >= SNIPPET_MIN_WORDS then
            chosen = k -- latest sentence start still ≥MIN words = smallest qualifying span
        end
    end
    local truncated = false
    if (n - chosen + 1) > SNIPPET_MAX_WORDS then
        chosen = n - SNIPPET_MAX_WORDS + 1
        truncated = true
    end
    return toks[chosen].s, toks[n].e, truncated
end

-- Standalone span: the first sentence of [lo,hi], capped at MAX words.
local function select_head(text, lo, hi)
    local toks = tokenize(text, lo, hi)
    local n = #toks
    if n == 0 then return nil end
    local f = n
    for k = 1, n do if ends_sentence(text, toks[k]) then f = k; break end end
    local truncated = false
    if f > SNIPPET_MAX_WORDS then f = SNIPPET_MAX_WORDS; truncated = true end
    return toks[1].s, toks[f].e, truncated
end

-- Display text for a span: verbatim slice, markers stripped + whitespace
-- collapsed, with a leading "… " (tail) or trailing " …" (head) when capped.
local function span_text(text, lo, hi, truncated, head)
    local s = collapse_ws(strip_markers(text:sub(lo, hi)))
    if not truncated then return s end
    return head and (s .. " …") or ("… " .. s)
end

--- Infer a verbatim anchor snippet for an unquoted marker from surrounding
--- reply prose. Pure. Also returns the byte range of the prose it drew from so
--- a caller can enclose the referenced span in place (#127 brackets).
---
--- Tuned for single-line markers (the common `🤖[comment]` case): classification
--- reasons line-locally off `byte_start`/`byte_end`, so a multi-line marker
--- (`🤖[a\nb]`) whose `byte_end` lands on a later line may mis-pick inline vs
--- standalone. It still degrades safely (a reasonable or empty anchor, never a
--- crash) since both branches fall back to the previous prose block.
--- @param text string           joined reply text
--- @param marker table          a parsed marker (M.parse) — uses byte_start/byte_end
--- @param opts table|nil        { boundaries = string[] } turn-prefix hard stops
--- @return string               anchor snippet, or "" when none can be recovered
--- @return integer|nil          span_start (absolute byte, inclusive) or nil
--- @return integer|nil          span_end   (absolute byte, inclusive) or nil
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
    -- before-text so the prefix never leaks into classification.
    if boundaries then
        for _, p in ipairs(boundaries) do
            if p ~= "" and before_on_line:sub(1, #p) == p then
                before_on_line = before_on_line:sub(#p + 1)
                break
            end
        end
    end

    -- Inline source region [lo, hi]: the paragraph prose before the marker.
    local function inline_region()
        local top = paragraph_top(idx, L, boundaries)
        local lo = idx[top].off
        if boundaries and is_boundary_line(idx[top].line, boundaries) then
            for _, p in ipairs(boundaries) do
                if p ~= "" and idx[top].line:sub(1, #p) == p then lo = lo + #p; break end
            end
        end
        return lo, marker.byte_start - 1
    end

    -- Standalone source region [lo, hi]: the previous prose block (nil if none).
    local function prev_block_region()
        local i = L - 1
        while i >= 1 and is_blank(idx[i].line) do i = i - 1 end
        if i < 1 or is_boundary_line(idx[i].line, boundaries) then return nil end
        local top = paragraph_top(idx, i, boundaries)
        return idx[top].off, idx[i].off + #idx[i].line - 1
    end

    local function from_inline()
        local lo, hi = inline_region()
        if hi < lo then return "" end
        local s, e, trunc = select_tail(text, lo, hi)
        if not s then return "" end
        return span_text(text, s, e, trunc, false), s, e
    end

    local function from_prev_block()
        local lo, hi = prev_block_region()
        if not lo then return "" end
        local s, e, trunc = select_head(text, lo, hi)
        if not s then return "" end
        return span_text(text, s, e, trunc, true), s, e
    end

    local has_before = before_on_line:match("%S") ~= nil
    local marker_only = (not has_before) and (after_on_line:match("%S") == nil)

    if marker_only then
        -- Standalone iff blank/boundary-separated above AND below.
        local above_sep = (L == 1) or is_blank(idx[L - 1].line) or is_boundary_line(idx[L - 1].line, boundaries)
        local below_sep = (L == #idx) or is_blank(idx[L + 1].line) or is_boundary_line(idx[L + 1].line, boundaries)
        if above_sep and below_sep then
            return from_prev_block()
        end
        -- Bare marker mid-paragraph → inline from preceding lines.
    end

    -- Inline (or bare-mid-paragraph): preceding words; fall back to the
    -- previous block when there is nothing before the marker.
    local t, s, e = from_inline()
    if t ~= "" then return t, s, e end
    return from_prev_block()
end

--- Assemble the turn-prefix boundary list for snippet inference from a parley
--- config table (#127). Pure (config in → string[] out) so the chat-structure
--- knowledge has a single tested home instead of an inline closure in the
--- chat_respond glue. These prefixes hard-stop the backward anchor scan so it
--- never crosses out of the marker's own agent turn.
--- @param cfg table  parley config (reads chat_*_prefix fields)
--- @return string[]  ordered, de-nil'd prefix list
function M.chat_boundaries(cfg)
    cfg = cfg or {}
    local function first(p) return type(p) == "table" and p[1] or p end
    local out = {}
    local function add(p) if p and p ~= "" then table.insert(out, p) end end
    add(cfg.chat_user_prefix or "💬:")
    add(first(cfg.chat_assistant_prefix) or "🤖:")
    add((cfg.chat_memory and cfg.chat_memory.reasoning_prefix) or "🧠:")
    add((cfg.chat_memory and cfg.chat_memory.summary_prefix) or "📝:")
    add(cfg.chat_tool_use_prefix or "🔧:")
    add(cfg.chat_tool_result_prefix or "📎:")
    add(cfg.chat_branch_prefix or "🌿:")
    add(cfg.chat_local_prefix)
    return out
end

--- Gather ready markers and strip each from the inline text.
--- - Marker with `<Q>` body → inline replaced by Q.
--- - Marker without `<Q>` body → inline removed entirely; its block quote is
---   inferred from surrounding prose (#127) when one can be recovered.
--- Pending markers (last section non-empty `{}`) and annotation-only markers
--- (no ready `[]` last section) are left untouched.
---
--- With `opts.bracket`, the referenced span is enclosed in `[]` in place so a
--- human can see what each gathered comment points at (#127): an explicit `Q`
--- becomes `[Q]`; an inferred span is bracketed where it sits in the reply (the
--- snippet is *not* re-inserted — it's already there, we only delimit it).
--- @param text string
--- @param opts table|nil  { boundaries = string[], bracket = boolean }
--- @return table[] blocks  list of { quoted = string|nil, sections = list } in document order
--- @return string new_text
function M.gather_and_strip(text, opts)
    opts = opts or {}
    local bracket = opts.bracket
    local markers = M.parse(text)
    local blocks = {}
    local edits = {}
    local function edit(bs, be, repl) table.insert(edits, { byte_start = bs, byte_end = be, replacement = repl }) end
    for _, m in ipairs(markers) do
        if m.ready then
            local explicit = m.quoted and m.quoted.text or nil
            if explicit then
                -- Explicit <Q>: restore Q inline (optionally bracketed) — the
                -- whole marker collapses to the anchor text.
                edit(m.byte_start, m.byte_end, bracket and ("[" .. explicit .. "]") or explicit)
                table.insert(blocks, { quoted = explicit, sections = m.sections })
            else
                -- Unquoted: infer the anchor + its span, remove the marker, and
                -- (optionally) bracket the span where it already sits.
                local snip, ss, se = M.generate_snippet(text, m, opts)
                if bracket and ss then
                    edit(ss, ss - 1, "[") -- zero-width insert before the span
                    local gap = (se < m.byte_start) and text:sub(se + 1, m.byte_start - 1) or "x"
                    if se < m.byte_start and gap:match("^%s*$") then
                        -- Inline: span abuts the marker — absorb the gap + marker into "]".
                        edit(se + 1, m.byte_end, "]")
                    else
                        -- Standalone: span sits elsewhere — close it, remove the marker.
                        edit(se + 1, se, "]") -- zero-width insert after the span
                        edit(m.byte_start, m.byte_end, "")
                    end
                else
                    edit(m.byte_start, m.byte_end, "") -- no span / no bracketing: just remove
                end
                table.insert(blocks, { quoted = (snip ~= "" and snip or nil), sections = m.sections })
            end
        end
    end
    -- splice() applies right-to-left on original offsets, so order ascending.
    table.sort(edits, function(a, b)
        if a.byte_start ~= b.byte_start then return a.byte_start < b.byte_start end
        return a.byte_end < b.byte_end
    end)
    return blocks, splice(text, edits)
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
