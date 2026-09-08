-- #214 M3. `<M-S-CR>` performs the submission `<M-CR>` would perform, into a new
-- child chat, and leaves a 🌿: reference where `<M-CR>`'s output would have
-- appeared. The DECISION — which case applies, what the child is seeded with,
-- which parent line the reference follows — is pure and lives here; the effects
-- live in init.lua's branch_inserters.

local bs = require("parley.branch_submit")

describe("branch_submit.seed_question", function()
    it("a visual selection asks the child to expand on it", function()
        assert.are.equal('tell me more about "monad transformers"',
            bs.seed_question("define", "monad transformers"))
    end)

    it("gathered quotes pass through — they are already a prompt", function()
        local blocks = "> [some quoted text]\n\nwhat about this?"
        assert.are.equal(blocks, bs.seed_question("quotes", blocks))
    end)

    it("a question passes through verbatim", function()
        assert.are.equal("how does X work?", bs.seed_question("question", "how does X work?"))
    end)

    -- A selection carrying its own quote marks reads a little oddly and that is
    -- fine; backslash-escaping it would leak a code convention into chat prose,
    -- and the model reads either. What must not happen is a crash or a mangled
    -- prompt. (Deviation from the plan's draft test, which expected escaping.)
    it("a selection containing quote marks is passed through, not escaped", function()
        assert.are.equal('tell me more about "the "hard" problem"',
            bs.seed_question("define", 'the "hard" problem'))
    end)

    -- BR-21's class: a `%` in a runtime string is a live hazard wherever the
    -- value later reaches gsub as a REPLACEMENT. seed_question must not itself
    -- introduce one, and must not choke on one.
    it("a selection containing % survives intact", function()
        assert.are.equal('tell me more about "50% off"', bs.seed_question("define", "50% off"))
        assert.are.equal('tell me more about "%1 placeholder"',
            bs.seed_question("define", "%1 placeholder"))
    end)

    it("whitespace around a selection is trimmed", function()
        assert.are.equal('tell me more about "widget"', bs.seed_question("define", "  widget  "))
    end)
end)

describe("branch_submit.plan_submission", function()
    -- Hand-built parser output: the decision needs no buffer, which is the whole
    -- reason it lives apart from branch_inserters.
    local function ex(q_start, q_end, a_start, a_end)
        return {
            question = { line_start = q_start, line_end = q_end,
                         content = "q" .. tostring(q_start) },
            answer = a_start and { line_start = a_start, line_end = a_end } or nil,
        }
    end
    local function chat(exchanges) return { exchanges = exchanges } end

    -- The transcript these line numbers describe (verified against chat_parser
    -- in the plan's investigation — `answer.line_end` IS the 📝: summary line):
    --    5 💬: first question      7..11 🤖: … 📝: sum
    --   13 💬: second question    15..19 🤖: … 📝: sum
    local TWO = chat({ ex(5, 5, 7, 11), ex(13, 13, 15, 19) })

    -- The narrowing (operator, 2026-09-07): with no markers there is nothing to
    -- rearrange, so the planner declines and the caller inserts a plain
    -- reference at the cursor. `<M-i>` reads as an INSERTION; an insertion must
    -- not delete your answer. The earlier "copy the question, delete the answer"
    -- reading was coherent only for `<M-S-CR>` as a *submission* — and the three
    -- keys share one callback, so it would have been reachable from the key that
    -- says "insert here".
    describe("no markers — the planner declines so the caller inserts in place", function()
        it("an unanswered question is a placeholder, not a submission", function()
            local c = chat({ ex(5, 5, 7, 11), ex(13, 13) })
            local p, reason = bs.plan_submission(c, 13, {})
            assert.is_nil(p)
            assert.is_truthy(reason)
        end)

        it("an ANSWERED question is never destroyed", function()
            local p = bs.plan_submission(TWO, 5, {})
            assert.is_nil(p, "a bare <M-i> must not plan to delete an answer")
        end)

        it("a cursor inside an answer is likewise a placeholder", function()
            assert.is_nil((bs.plan_submission(TWO, 9, {})))
        end)
    end)

    -- Placement rule (operator, revising the earlier end-of-answer decision):
    -- the reference lands AT THE CURSOR. <M-i> reads as an *insertion*, so
    -- relocating the line elsewhere made the keypress jump.
    describe("case 2 — pending <M-q> markers", function()
        it("the ref lands at the cursor, not at the end of the answer", function()
            local p = bs.plan_submission(TWO, 9, { { line = 9 } })
            assert.are.equal("quotes", p.case)
            assert.are.equal(9, p.ref_after)
            assert.is_true(p.strip_markers)
            assert.is_nil(p.delete_lines, "case 2 preserves the original Q/A")
        end)

        it("the cursor governs even when the markers are elsewhere", function()
            local p = bs.plan_submission(TWO, 17, { { line = 9 } })
            assert.are.equal(17, p.ref_after)
        end)

        it("markers win over the question case — <M-CR> resolves them first", function()
            -- atlas/chat/drill_in.md: "Drill-in detection runs BEFORE resubmit
            -- handling"; the original answer is preserved.
            local p = bs.plan_submission(TWO, 5, { { line = 9 } })
            assert.are.equal("quotes", p.case)
            assert.is_nil(p.delete_lines)
        end)

        it("markers work from a cursor outside every exchange", function()
            -- The question case declines there (it would delete an answer the
            -- user never pointed at); the quotes case has no such hazard.
            local p = bs.plan_submission(TWO, 1, { { line = 9 } })
            assert.are.equal("quotes", p.case)
            assert.are.equal(1, p.ref_after)
        end)
    end)

    describe("declining", function()
        it("an empty transcript has nothing to submit", function()
            local p, reason = bs.plan_submission(chat({}), 1, {})
            assert.is_nil(p)
            assert.is_truthy(reason)
        end)

        it("a question with no text has nothing to submit", function()
            local c = chat({ { question = { line_start = 5, line_end = 5, content = "  " } } })
            local p, reason = bs.plan_submission(c, 5, {})
            assert.is_nil(p)
            assert.is_truthy(reason)
        end)
    end)
end)
