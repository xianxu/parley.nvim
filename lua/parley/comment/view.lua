-- comment/view.lua — PURE geometry of 🤖 markers on one line (#312).
--
-- Where each marker is, which part is its anchor and where its turns are, for
-- the highlighter (turn colors) and the <CR> thread lookup. Nothing is hidden
-- (#386): a marker shows its full text. Section parsing stays in
-- skills/review's parse_marker_sections (no second parser).
--
-- Columns are 0-based bytes; ranges are { s, e, extra } with `e` exclusive.
--   marker = { start, stop, kind = "bare"|"quoted"|"strike",
--              visible  = { s, e, hl_group } | nil,  -- the anchor X / D
--              turns_hl = { { s, e, hl_group }, ... }, -- each turn, brackets included
--              brackets = { { col, char }, ... } }     -- turn brackets, kept
--          | { start, stop, broken = true }
-- A marker renders only when it closes on its own line (markers are
-- single-line, newlines inside a turn are `<br>`); one whose chain stops at an
-- opener it couldn't close — e.g. a #125 multi-line marker — is `broken`.
local M = {}

local MARK, MARK_LEN = "🤖", 4
local OPENERS = { ["<"] = true, ["["] = true, ["{"] = true, ["~"] = true }
local CLOSER = { ["["] = "]", ["{"] = "}" } -- an unclosed opener → broken

local TURN_HL = { user = "ParleyReviewUser", agent = "ParleyReviewAgent" }

-- The chain: each turn's color and its brackets. Fills m.turns_hl / m.brackets.
local function line_char(sec, opening)
    if sec.type == "user" then return opening and "[" or "]" end
    return opening and "{" or "}"
end

local function lay_chain(m, sections)
    for _, sec in ipairs(sections) do
        local open, close = sec.byte_start - 1, sec.byte_end - 1 -- 0-based cols
        m.turns_hl[#m.turns_hl + 1] = { open, close + 1, TURN_HL[sec.type] }
        -- Treesitter's markdown_inline reads `[text]` as a shortcut link and,
        -- under conceallevel > 0 (chat buffers), conceals its brackets;
        -- re-assert each bracket as itself so a turn always reads `[text]`.
        m.brackets[#m.brackets + 1] = { open, line_char(sec, true) }
        m.brackets[#m.brackets + 1] = { close, line_char(sec, false) }
    end
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
                local m = { start = start0, stop = stop0, turns_hl = {}, brackets = {} }
                local anchor = quoted or strike
                m.kind = anchor and (quoted and "quoted" or "strike") or "bare"
                -- An empty anchor has no text to color.
                if anchor and anchor.text ~= "" then
                    -- anchor.byte_start / byte_end are the 1-based `<`/`>`.
                    m.visible = { anchor.byte_start, anchor.byte_end - 1,
                        quoted and "ParleyReviewQuoted" or "ParleyReviewStrike" }
                end
                lay_chain(m, sections)
                out[#out + 1] = m
                from = stop
            end
        end
    end
    return out
end

--- The rendered (non-broken) marker whose bytes contain `col`, or nil.
function M.marker_at(markers, col)
    for _, m in ipairs(markers) do
        if not m.broken and col >= m.start and col < m.stop then return m end
    end
    return nil
end

return M
