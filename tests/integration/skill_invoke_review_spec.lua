-- Integration test for review ported onto skill_invoke (#128 M3).
--
-- Tests review.run_via_invoke's marker pre-check + resubmit logic by stubbing
-- skill_invoke.invoke (the driver itself is covered by skill_invoke_spec). The
-- marker grammar: a `[]` (human) last section = ready; a `{}` (agent) last
-- section = pending (awaiting the human).

local review = require("parley.skills.review")
local skill_invoke = require("parley.skill_invoke")

describe("review.run_via_invoke", function()
    local buf, orig_invoke, invoke_calls

    before_each(function()
        require("parley.tools").register_builtins()
        invoke_calls = {}
        orig_invoke = skill_invoke.invoke
        skill_invoke.invoke = function(b, manifest, args, opts)
            table.insert(invoke_calls, { buf = b, manifest = manifest, args = args, opts = opts })
        end
        buf = vim.api.nvim_create_buf(false, true)
    end)

    after_each(function()
        skill_invoke.invoke = orig_invoke
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    it("invokes skill_invoke with the review manifest when a ready marker exists", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "prose 🤖[please fix this]" })
        review.run_via_invoke(buf, {})
        assert.are.equal(1, #invoke_calls)
        assert.are.equal("review", invoke_calls[1].manifest.name)
        assert.is_true(invoke_calls[1].opts.manual)
        assert.is_function(invoke_calls[1].opts.on_done)
    end)

    it("does NOT invoke when there are no markers", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "plain text, no markers" })
        review.run_via_invoke(buf, {})
        assert.are.equal(0, #invoke_calls)
    end)

    it("does NOT invoke when the last marker is a pending agent question", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "prose 🤖{agent asks a question}" })
        review.run_via_invoke(buf, {})
        assert.are.equal(0, #invoke_calls)
    end)

    it("resubmits when the marker set shrank and a ready marker remains (bounded at 3)", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[a]", "🤖[b]" }) -- 2 ready markers
        review.run_via_invoke(buf, {})
        assert.are.equal(1, #invoke_calls)
        -- the apply removed one marker; one ready marker remains → progress → re-invoke
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[b]" })
        invoke_calls[1].opts.on_done({ ok = true })
        assert.are.equal(2, #invoke_calls)
    end)

    it("does NOT resubmit when the marker set did not shrink (no-progress storm guard)", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[fix]" })
        review.run_via_invoke(buf, {})
        -- buffer unchanged (model made no/empty/wrong edit) → no progress → stop
        invoke_calls[1].opts.on_done({ ok = true })
        assert.are.equal(1, #invoke_calls)
    end)

    it("does NOT resubmit when the remaining marker is a pending question", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[a]", "🤖[b]" })
        review.run_via_invoke(buf, {})
        -- shrank to one marker, but it's now a pending agent question
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[b]{a question}" })
        invoke_calls[1].opts.on_done({ ok = true })
        assert.are.equal(1, #invoke_calls)
    end)

    it("does NOT resubmit on a failed exchange", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[fix]" })
        review.run_via_invoke(buf, {})
        invoke_calls[1].opts.on_done({ ok = false, msg = "tool error" })
        assert.are.equal(1, #invoke_calls)
    end)

    -- M2 (#133): no-marker general review + submission decoupled from pending {}.

    it("invokes a mode run even with NO markers (general review)", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "plain prose, no markers" })
        review.run_via_invoke(buf, { mode = "developmental" })
        assert.are.equal(1, #invoke_calls)
        assert.are.equal("developmental", invoke_calls[1].args.mode)
    end)

    it("does NOT resubmit when a mode round inserts {} findings (fact-check 0→N)", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a dubious claim" }) -- 0 markers
        review.run_via_invoke(buf, { mode = "fact-check" })
        assert.are.equal(1, #invoke_calls)
        -- the round inserted a finding marker (0 → 1 pending); one-shot, no resubmit
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a dubious claim 🤖{is this true?}" })
        invoke_calls[1].opts.on_done({ ok = true })
        assert.are.equal(1, #invoke_calls)
    end)

    it("invokes (processes ready) even when an unaddressed pending {} marker is present", function()
        -- Was blocked pre-#133 (#pending > 0 → return); now the ready [] is processed.
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[fix me]", "prose 🤖{agent asked earlier}" })
        review.run_via_invoke(buf, {})
        assert.are.equal(1, #invoke_calls)
    end)

    it("does NOT invoke a strike-only doc with no mode (no ready markers)", function()
        -- A bare strike (🤖~del~) is a proposal, not agent-actionable: no mode +
        -- no ready marker → nothing to do, no LLM call (M2 review-finding pin).
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "prose 🤖~delete this~" })
        review.run_via_invoke(buf, {})
        assert.are.equal(0, #invoke_calls)
    end)
end)
