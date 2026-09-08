-- parley/branch_ref.lua — one implementation of "branch at this point in the
-- chat tree", shared by chat and markdown buffers.
--
-- #214. There were FOUR near-identical copies: chat_insert_branch_ref /
-- chat_insert_inline_branch_ref and the markdown twins md_insert_branch_ref /
-- md_insert_inline_branch_ref. They had already drifted in the way that matters:
-- both VISUAL paths called create_child_chat, and neither n/i path did — so the
-- no-selection case wrote a reference to a file that did not exist, which is
-- what made it feel like a different action rather than the same one.
--
-- The pure half (line editing) is separated from the IO half (file creation,
-- window focus) so the former is testable without a filesystem (ARCH-PURE).

local M = {}

--- Splice an inline branch link into `line`, replacing [start_col, end_col].
--- 1-indexed, inclusive, matching vim.fn.getpos() columns.
--- PURE.
--- @param line string
--- @param start_col integer
--- @param end_col integer
--- @param prefix string branch prefix, e.g. "🌿:"
--- @param target string path written into the link
--- @return string spliced, string selected
function M.splice_inline_link(line, start_col, end_col, prefix, target)
    local selected = line:sub(start_col, end_col)
    local before = line:sub(1, start_col - 1)
    local after = line:sub(end_col + 1)
    return before .. "[" .. prefix .. selected .. "](" .. target .. ")" .. after, selected
end

--- The standalone reference line the no-selection path inserts.
--- PURE.
--- @param prefix string
--- @param rel_path string
--- @param topic string|nil
--- @return string
function M.format_ref_line(prefix, rel_path, topic)
    return prefix .. " " .. rel_path .. ": " .. (topic or "")
end

--- Topic seeded for a selection-derived branch.
--- PURE.
--- The child chat's `topic:` header for a selection, which becomes its filename
--- slug — so it names the SUBJECT, not a question about it. This returned
--- `what is "<selected>"` before #214 M3, which put a question form into every
--- branched filename; the question wording now lives in
--- `branch_submit.seed_question`.
---
--- Whitespace is collapsed because a visual selection can span lines and the
--- slug has to survive it. An all-whitespace selection returns "" — the caller
--- decides whether that is an error (the inline path already rejects it).
--- @param selected string
--- @return string
function M.topic_for_selection(selected)
    local topic = (selected or ""):gsub("%s+", " ")
    return (topic:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- The lines to insert so a reference sits as its own block: one blank line on
--- each side, but only where there is not already one.
---
--- Three artifacts claimed "one blank line each side" and neither insert path
--- held it (#214 BR-68): the planned path emitted `{ "", ref }` — a blank before
--- only, so the reference abutted the following prose — and the placeholder path
--- emitted the bare line with no blank at all. The existing assertions passed
--- because their fixtures happened to have a blank in the right place. PURE, so
--- the rule is stated once and testable without a buffer.
---
--- @param ref string       the formatted 🌿: line
--- @param prev string|nil  the line above the insertion point, nil at BOF
--- @param next_ string|nil the line below it, nil at EOF
--- @return string[]
function M.ref_block(ref, prev, next_)
    local function blank(line) return line == nil or not line:match("%S") end
    local out = {}
    if not blank(prev) then out[#out + 1] = "" end
    out[#out + 1] = ref
    if not blank(next_) then out[#out + 1] = "" end
    return out
end

return M
