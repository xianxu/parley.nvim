-- parley/branch_submit.lua — the PURE half of `<M-S-CR>` (#214 M3).
--
-- The chord is one rule:
--
--     <M-S-CR> performs the submission <M-CR> would perform, into a new child
--     chat, and leaves a 🌿: reference where <M-CR>'s output would have appeared.
--
-- This module decides *what* that means for a given cursor position: which case
-- applies, what the child is seeded with, which parent line the reference
-- follows, and what the parent loses. It performs no IO, opens no buffer and
-- creates nothing — so the decision is unit-testable with hand-built parser
-- output, and the effects stay in `init.lua`'s `branch_inserters`, which already
-- owns the durability rule (create the child, commit the parent, then navigate).
--
-- The reference always follows the last line of what the exchange currently ends
-- with, which for an answered exchange is `answer.line_end` — and that line IS
-- the `📝:` summary (verified against chat_parser). Placing it *before* the
-- summary drops the summary block out of the exchange model entirely: measured,
-- `from_parsed_chat` yields `question, agent_header, text` with no `summary`, and
-- `append_pos` then points into the middle of the exchange.

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

--- Where exchange `ex` currently ends: the summary line when it has an answer,
--- otherwise its question. This is the line the reference follows.
local function exchange_end(ex)
    if ex.answer then
        return ex.answer.line_end
    end
    return ex.question and ex.question.line_end
end

--- The exchange the cursor is in, by line span. Mirrors `init.lua`'s
--- `find_exchange_at_line` INCLUDING its margin rule — a line after a question
--- but before the answer (or before the next exchange, when there is no answer)
--- belongs to that question. Without the margin, composing on the blank line
--- under a new question resolved to "nowhere", and `<M-CR>` and `<M-S-CR>` would
--- disagree about the most common case there is.
---
--- Deliberately re-derived rather than called: that function needs the whole
--- plugin loaded, and this module's reason for existing is that it does not.
--- Task 7's conformance check is what keeps the two honest.
--- @return integer|nil index
local function exchange_at(parsed_chat, line)
    local exchanges = parsed_chat.exchanges
    for i, ex in ipairs(exchanges) do
        local q, a = ex.question, ex.answer
        if q and line >= q.line_start and line <= q.line_end then
            return i
        end
        if a and line >= a.line_start and line <= a.line_end then
            return i
        end
        if q and line > q.line_end then
            if a then
                if line < a.line_start then return i end
            else
                local nxt = exchanges[i + 1]
                if not nxt or line < nxt.question.line_start then return i end
            end
        end
    end
    return nil
end

-- Test seam: the duplicated rule is pinned line-by-line against
-- `init.lua`'s `find_exchange_at_line` (#214 M3 Task 7). Exposed because a
-- duplicated rule that nothing compares is exactly how the two chords drift.
M._exchange_at = exchange_at

--- Plan the submission for a cursor position.
---
--- @param parsed_chat table   chat_parser output
--- @param cursor_line integer 1-indexed
--- @param markers table[]     ready drill-in markers, each carrying `line`
--- @return table|nil plan, string|nil reason
--- plan = {
---   case          = "quotes" | "question",
---   question      = string,                -- what the child is seeded with
---   topic         = string,                -- the child's `topic:` header
---   ref_after     = integer,               -- parent line the 🌿: block follows
---   strip_markers = boolean,               -- case 2 only
---   delete_lines  = { first, last } | nil, -- case 3b only: the replaced answer
--- }
function M.plan_submission(parsed_chat, cursor_line, markers)
    local exchanges = (parsed_chat or {}).exchanges or {}
    if #exchanges == 0 then
        return nil, "no exchange to branch from"
    end

    -- Case 2 first. `<M-CR>` resolves drill-in markers BEFORE resubmit handling
    -- (atlas/chat/drill_in.md), and preserves the original Q/A — so markers win
    -- over the question case, and nothing is deleted.
    if markers and #markers > 0 then
        local target = nil
        for _, marker in ipairs(markers) do
            local idx = marker.line and exchange_at(parsed_chat, marker.line)
            if idx then
                target = math.max(target or idx, idx)
            end
        end
        -- Markers that belong to no exchange (or none at all) mean the new turn
        -- would have gone to the end of the buffer, so the ref follows the last
        -- exchange — which is where <M-CR> would have appended it.
        target = target or #exchanges
        return {
            case = "quotes",
            ref_after = exchange_end(exchanges[target]),
            strip_markers = true,
        }
    end

    -- Case 3: the question at the cursor. A cursor outside every exchange — in
    -- the frontmatter, say — is NOT "the last question": `<M-CR>` there submits
    -- the buffer as a new turn and deletes nothing, so silently adopting the last
    -- exchange would make <M-S-CR> destroy an answer the user never pointed at.
    -- Decline instead.
    local idx = exchange_at(parsed_chat, cursor_line)
    if not idx then
        return nil, "put the cursor on the question you want to branch"
    end
    local ex = exchanges[idx]
    local text = ex.question and ex.question.content or ""
    if text:match("^%s*$") then
        return nil, "that question is empty — nothing to submit"
    end

    return {
        case = "question",
        question = M.seed_question("question", text),
        -- The child's `topic:` stays the "?" sentinel so auto-titling fires and
        -- the slug rename follows (#214 BR-1 — a real topic here disables both,
        -- and the generated title beats the raw question text anyway). `label`
        -- is what the parent's 🌿: line displays, which is a different job.
        topic = "?",
        label = require("parley.branch_ref").topic_for_selection(text),
        -- The ref replaces the ANSWER, so it follows the question — never
        -- `exchange_end`, which would put it inside the span we are deleting.
        ref_after = ex.question.line_end,
        delete_lines = ex.answer and { ex.answer.line_start, ex.answer.line_end } or nil,
    }
end

return M
