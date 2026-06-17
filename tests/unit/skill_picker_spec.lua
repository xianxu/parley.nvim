-- Unit test for skill_picker's routing seam (#128 M4).
--
-- The float-picker UI is untested glue; the load-bearing decision is run_skill's
-- two-way routing: `review` keeps its marker pre-check + resubmit (run_via_invoke),
-- every other skill is a single-shot skill_invoke exchange. Stub both targets.

local skill_picker = require("parley.skill_picker")
local skill_invoke = require("parley.skill_invoke")
local review = require("parley.skills.review")

describe("skill_picker.run_skill routing", function()
    local buf, orig_invoke, orig_rvi, invoke_calls, rvi_calls

    before_each(function()
        invoke_calls, rvi_calls = {}, {}
        orig_invoke = skill_invoke.invoke
        orig_rvi = review.run_via_invoke
        skill_invoke.invoke = function(b, manifest, args, opts)
            table.insert(invoke_calls, { buf = b, manifest = manifest, args = args, opts = opts })
        end
        review.run_via_invoke = function(b, args)
            table.insert(rvi_calls, { buf = b, args = args })
        end
        buf = vim.api.nvim_create_buf(false, true)
    end)

    after_each(function()
        skill_invoke.invoke = orig_invoke
        review.run_via_invoke = orig_rvi
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    it("routes review through run_via_invoke (marker pre-check + resubmit)", function()
        skill_picker.run_skill(buf, { name = "review" }, {})
        assert.are.equal(1, #rvi_calls)
        assert.are.equal(0, #invoke_calls)
    end)

    it("routes a non-review skill through skill_invoke.invoke (single-shot)", function()
        local manifest = { name = "voice-apply" }
        skill_picker.run_skill(buf, manifest, { slug = "x" })
        assert.are.equal(1, #invoke_calls)
        assert.are.equal(0, #rvi_calls)
        assert.are.equal(manifest, invoke_calls[1].manifest)
        assert.are.same({ slug = "x" }, invoke_calls[1].args)
    end)
end)
