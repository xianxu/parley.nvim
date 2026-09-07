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
--- @param selected string
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

return M
