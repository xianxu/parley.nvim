-- comment/view.lua — PURE geometry of 🤖 markers on one line (#312).
--
-- What is hidden (with which conceal char), what stays visible, and where the
-- cursor may rest. The highlighter (conceal), the cursor snap and the <CR>
-- lookup all read this one layout; section parsing stays in
-- skills/review's parse_marker_sections (no second parser).
--
-- Columns are 0-based bytes; ranges are { s, e, extra } with `e` exclusive.
--   marker = { start, stop, kind = "bare"|"quoted"|"strike",
--              visible = { s, e, hl_group } | nil,
--              hidden  = { { s, e, conceal_char }, ... } }
--          | { start, stop, broken = true }
-- A marker renders only when it closes on its own line (markers are
-- single-line, newlines inside a turn are `<br>`); one whose chain stops at an
-- opener it couldn't close — e.g. a #125 multi-line marker — is `broken`.
local M = {}

local MARK, MARK_LEN = "🤖", 4
local OPENERS = { ["<"] = true, ["["] = true, ["{"] = true, ["~"] = true }
local CLOSER = { ["["] = "]", ["{"] = "}" }

-- Bare chain `🤖[H]{R}…`: keep `🤖[` visible, show the middle as `…` and the
-- last byte as the first opener's closer, so it reads 🤖[…] / 🤖{…}.
-- `first` is the 0-based col of the first `[`/`{`; `stop` 0-based exclusive.
local function chain_hidden(line, first, stop)
    if stop - first <= 2 then return {} end -- `[]` / `{}`: nothing to hide
    local close = CLOSER[line:sub(first + 1, first + 1)]
    return {
        { first + 1, stop - 1, "…" },
        { stop - 1, stop, close },
    }
end

function M.layout(line)
    local review = require("parley.skills.review")
    local parse = review._parse_marker_sections
    local code = review._inline_code_ranges(line)
    local function in_code(i)
        for _, r in ipairs(code) do
            if i >= r[1] and i <= r[2] then return true end
        end
        return false
    end

    local out, from = {}, 1
    while true do
        local pos = line:find(MARK, from, true)
        if not pos then break end
        local nxt = line:sub(pos + MARK_LEN, pos + MARK_LEN)
        if in_code(pos) or not OPENERS[nxt] then
            from = pos + MARK_LEN
        else
            local sections, stop, quoted, strike = parse(line, pos, MARK_LEN)
            local start0 = pos - 1
            local unclosed = CLOSER[line:sub(stop, stop)] ~= nil
            if unclosed or (#sections == 0 and not quoted and not strike) then
                -- An unmatched `~` is ordinary prose (`~/path`), not a marker.
                if unclosed or nxt ~= "~" then
                    out[#out + 1] = { start = start0, stop = #line, broken = true }
                    break
                end
                from = pos + MARK_LEN
            else
                local stop0 = stop - 1
                local m = { start = start0, stop = stop0 }
                local anchor = quoted or strike
                if anchor then
                    m.kind = quoted and "quoted" or "strike"
                    if anchor.text == "" then
                        m.hidden = {} -- nothing to show in its place: leave it raw
                    else
                        -- anchor.byte_start / byte_end are the 1-based `<`/`>`.
                        m.visible = { anchor.byte_start, anchor.byte_end - 1,
                            quoted and "ParleyReviewQuoted" or "ParleyReviewStrike" }
                        m.hidden = {
                            { start0, anchor.byte_start, "" },
                            { anchor.byte_end - 1, stop0, "" },
                        }
                    end
                else
                    m.kind = "bare"
                    m.hidden = chain_hidden(line, sections[1].byte_start - 1, stop0)
                end
                out[#out + 1] = m
                from = stop
            end
        end
    end
    return out
end

-- Where the cursor may NOT be, as half-open [a, b) spans of columns.
-- Normal mode: the cursor sits ON a byte, so every hidden byte is off limits —
-- even a range's first one (an `x` on the first char of a `…`-concealed
-- comment keeps the marker parseable, so the edit would be silent).
-- Insert mode: the cursor is an insertion POINT between bytes. Before the 🤖
-- and after the marker are outside it; inside a visible anchor (both ends
-- included) types into X/D; every other point inside the marker is hidden.
local function blocked_spans(markers, insert)
    local out = {}
    for _, m in ipairs(markers) do
        if not m.broken and #m.hidden > 0 then
            if not insert then
                for _, h in ipairs(m.hidden) do out[#out + 1] = { h[1], h[2] } end
            elseif m.visible then
                out[#out + 1] = { m.start + 1, m.visible[1] }
                out[#out + 1] = { m.visible[2] + 1, m.stop }
            else
                out[#out + 1] = { m.start + 1, m.stop }
            end
        end
    end
    return out
end

local function blocked_at(spans, col)
    for _, sp in ipairs(spans) do
        if col >= sp[1] and col < sp[2] then return sp end
    end
end

-- First allowed column from `col` stepping in `dir` (+1/-1), or nil.
local function allowed_from(spans, col, dir, max_col)
    while col >= 0 and col <= max_col do
        local sp = blocked_at(spans, col)
        if not sp then return col end
        col = dir > 0 and sp[2] or sp[1] - 1
    end
    return nil
end

--- Where the cursor must go so it never rests on hidden marker text. Moves in
--- the direction of travel, else the other way; nil = stay where it is.
--- `max_col`: `#line - 1` in normal mode, `#line` in insert mode. `line`
--- (optional) lets a leftward landing back up to its UTF-8 char start.
function M.snap(markers, prev_col, col, max_col, line, insert)
    local spans = blocked_spans(markers, insert)
    if not blocked_at(spans, col) then return nil end
    local dir = col >= prev_col and 1 or -1
    local to = allowed_from(spans, col, dir, max_col)
        or allowed_from(spans, col, -dir, max_col)
    if to and line and to < #line then
        to = to + vim.str_utf_start(line, to + 1)
    end
    return to
end

--- Whether `line` carries any rendered marker (cheap pre-check included).
function M.has_marker(line)
    if not line:find("🤖", 1, true) then return false end
    for _, m in ipairs(M.layout(line)) do
        if not m.broken then return true end
    end
    return false
end

--- The rendered (non-broken) marker whose bytes contain `col`, or nil.
function M.marker_at(markers, col)
    for _, m in ipairs(markers) do
        if not m.broken and col >= m.start and col < m.stop then return m end
    end
    return nil
end

return M
