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

    describe("case 3 — a question, no markers", function()
        it("an unanswered question is copied; the ref follows it", function()
            local c = chat({ ex(5, 5, 7, 11), ex(13, 13) })
            local p = bs.plan_submission(c, 13, {})
            assert.are.equal("question", p.case)
            assert.are.equal("q13", p.question)
            assert.are.equal(13, p.ref_after)
            assert.is_nil(p.delete_lines)
        end)

        it("an answered question deletes the answer; the ref takes its place", function()
            local p = bs.plan_submission(TWO, 5, {})
            assert.are.equal("question", p.case)
            assert.are.equal("q5", p.question)
            assert.are.equal(5, p.ref_after)
            assert.same({ 7, 11 }, p.delete_lines)
        end)

        it("the cursor inside an answer resolves to that exchange's question", function()
            local p = bs.plan_submission(TWO, 9, {})
            assert.are.equal(5, p.ref_after)
            assert.same({ 7, 11 }, p.delete_lines)
        end)

        it("the ref never lands inside the span the same plan deletes", function()
            local p = bs.plan_submission(TWO, 5, {})
            assert.is_true(p.ref_after < p.delete_lines[1],
                "the reference would be deleted by its own plan")
        end)
    end)

    describe("case 2 — pending <M-q> markers", function()
        it("markers in a past exchange put the ref after THAT answer", function()
            local p = bs.plan_submission(TWO, 9, { { line = 9 } })
            assert.are.equal("quotes", p.case)
            assert.are.equal(11, p.ref_after)
            assert.is_true(p.strip_markers)
            assert.is_nil(p.delete_lines, "case 2 preserves the original Q/A")
        end)

        it("markers outside the cursor's exchange fall to the last exchange", function()
            local p = bs.plan_submission(TWO, 1, { { line = 17 } })
            assert.are.equal("quotes", p.case)
            assert.are.equal(19, p.ref_after)
        end)

        it("markers win over the question case — <M-CR> resolves them first", function()
            -- atlas/chat/drill_in.md: "Drill-in detection runs BEFORE resubmit
            -- handling"; the original answer is preserved.
            local p = bs.plan_submission(TWO, 5, { { line = 9 } })
            assert.are.equal("quotes", p.case)
            assert.is_nil(p.delete_lines)
        end)

        it("an unanswered last exchange still gives the ref a home", function()
            local c = chat({ ex(5, 5, 7, 11), ex(13, 13) })
            local p = bs.plan_submission(c, 1, { { line = 9 } })
            assert.are.equal(11, p.ref_after)
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
