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

    it("resubmits while ready markers remain after apply (bounded at 3)", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "prose 🤖[fix]" })
        review.run_via_invoke(buf, {})
        assert.are.equal(1, #invoke_calls)
        -- on_done fires with the marker still present (fake didn't edit) → re-invoke
        invoke_calls[1].opts.on_done({ ok = true })
        assert.are.equal(2, #invoke_calls)
    end)

    it("does NOT resubmit when remaining markers are pending questions", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "prose 🤖[fix]" })
        review.run_via_invoke(buf, {})
        -- simulate the agent having added a pending question after applying
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "prose 🤖[fix]{now a question}" })
        invoke_calls[1].opts.on_done({ ok = true })
        assert.are.equal(1, #invoke_calls) -- no re-invoke
    end)
end)
