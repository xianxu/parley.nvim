-- parley/branch_submit.lua — the PURE half of `<M-S-CR>` (#214 M3).
--
-- The chord inserts a branch reference at the cursor and creates the child it
-- points at. Where pending <M-q> markers exist it gathers them into that child,
-- stripping them from the parent through the SAME `drill_in.chat_gather_opts`
-- `<M-CR>` uses — so removal and `[…]` span marking match, and both follow
-- `mark_reference_span`. The SCOPE differs on purpose: this gathers every
-- pending quote in the buffer, while `<M-CR>` inside an exchange gathers only
-- that exchange's. Branching takes all of it elsewhere; responding answers a
-- turn. An earlier header claimed the two were equivalent, which was never true
-- of scope and stopped being true of brackets (#214 BR-60).
--
-- This module decides *what* that means for a given cursor position: which case
-- applies, what the child is seeded with, which parent line the reference
-- follows, and what the parent loses. It performs no IO, opens no buffer and
-- creates nothing — so the decision is unit-testable with hand-built parser
-- output, and the effects stay in `init.lua`'s `branch_inserters`, which already
-- owns the durability rule (create the child, commit the parent, then navigate).
--
-- WHERE the reference lands (operator, 2026-09-07, revising the earlier
-- end-of-answer rule): at the CURSOR. `<M-S-CR>` reads as a *submission*, whose
-- effect is not local to anywhere — but `<M-i>` is the key that actually works
-- in a terminal, and it reads as an *insertion*, which has to happen where you
-- are. Relocating the line to the end of the answer made the keypress jump.
--
-- The cost is measured and real: `🌿:` sets the parser's `line_before_local`,
-- the same mechanism `🔒:` uses, so answer text AFTER a mid-answer reference is
-- excluded from the LLM context and the exchange model truncates that exchange
-- (its `summary` block disappears and `append_pos` moves into the middle). That
-- is pre-existing — `insert_plain` has always inserted at the cursor — and it is
-- why end-of-answer looked better on paper. See the issue's ## Revisions.

local M = {}

--- The child chat's first question.
---
--- One place that knows how a payload becomes a prompt; the three call sites
--- would otherwise each invent wording.
---
--- A selection carrying its own quote marks is passed through rather than
--- escaped: backslashes would leak a code convention into chat prose and the
--- model reads either form. A `%` is likewise passed through — this function
--- introduces no gsub, and the one place a topic reaches gsub as a REPLACEMENT
--- (`create_child_chat`) uses a function replacement for exactly that reason
--- (#214 BR-21).
---
--- @param case string  "define" | "quotes" | "question"
--- @param payload string
--- @return string
function M.seed_question(case, payload)
    payload = payload or ""
    if case == "define" then
        local trimmed = payload:gsub("^%s+", ""):gsub("%s+$", "")
        return 'tell me more about "' .. trimmed .. '"'
    end
    -- "quotes" is already a formatted prompt (drill_in.format_blocks output) and
    -- "question" is the user's own text. Neither is ours to rewrite.
    return payload
end

--- Plan the branch for a cursor position.
---
--- Returns a plan ONLY when there are pending `<M-q>` markers to rearrange.
--- Everything else — a bare question, an answered exchange, an empty transcript
--- — returns nil, and the caller inserts a plain reference at the cursor and
--- opens an empty child. That is a deliberate narrowing (operator, 2026-09-07):
---
---   `<M-i>` reads as an INSERTION. An insertion must not delete your answer.
---
--- The earlier design copied the question into the child and deleted the answer
--- it replaced, mirroring `<M-CR>`'s resubmit. That is coherent for
--- `<M-S-CR>` — a *submission*, whose effect is not local to anywhere — but
--- `<M-i>`, `<M-S-CR>` and `<C-g>i` are one registry entry with one callback, and
--- `<M-S-CR>` does not survive most terminals. So the destructive reading would
--- only ever be reachable from the key that reads as "insert here". Dropped
--- rather than left as unreachable code.
---
--- @param parsed_chat table   chat_parser output
--- @param cursor_line integer 1-indexed
--- @param has_markers boolean whether the gather found anything to rearrange
--- @return table|nil plan, string|nil reason
--- plan = {
---   case          = "quotes",
---   ref_after     = integer,  -- parent line the 🌿: block follows (the cursor)
---   strip_markers = true,
--- }
function M.plan_submission(parsed_chat, cursor_line, has_markers)
    local exchanges = (parsed_chat or {}).exchanges or {}
    if #exchanges == 0 then
        return nil, "no exchange to branch from"
    end
    if not has_markers then
        return nil, "no pending 🤖 markers — inserting a plain reference"
    end
    return {
        case = "quotes",
        ref_after = cursor_line,
        strip_markers = true,
    }
end

return M
