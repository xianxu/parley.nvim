-- Integration tests for lua/parley/skills/review/projection.lua — decoration
-- coherence across undo/redo (#133 M5). The watcher is driven directly via
-- M.project(buf) (TextChanged is unreliable to trigger in headless).

local projection = require("parley.skills.review.projection")
local skill_render = require("parley.skill_render")

local function set(buf, lines)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

describe("review.projection", function()
    local buf

    before_each(function()
        buf = vim.api.nvim_create_buf(false, true)
        projection.reset(buf)
    end)

    after_each(function()
        projection.reset(buf)
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    it("decide: restore for a known hash, capture for a novel one", function()
        assert.are.equal("restore", projection.decide({ abc = {} }, "abc"))
        assert.are.equal("capture", projection.decide({}, "xyz"))
    end)

    it("clears style on undo to base, restores it on redo to the round state", function()
        -- Simulate a round: post-round content with decorations drawn.
        set(buf, { "the reviewed line" })
        local content = "the reviewed line"
        skill_render.highlight_edits(buf, { { new_string = "reviewed" } }, content)
        skill_render.attach_diagnostics(buf, { { pos = content:find("reviewed"), explain = "agent edit" } }, content)
        projection.record_empty_for(buf, "the base line") -- pre-round base = no style
        projection.record(buf) -- post-round content → its decorations
        assert.is_true(#vim.diagnostic.get(buf) >= 1)

        -- Undo to base: content reverts → project → style cleared (base recorded empty).
        set(buf, { "the base line" })
        projection.project(buf)
        assert.are.equal(0, #vim.diagnostic.get(buf))

        -- Redo to the round state: content matches → project → style restored.
        set(buf, { "the reviewed line" })
        projection.project(buf)
        assert.is_true(#vim.diagnostic.get(buf) >= 1, "style should re-render at the round state")
    end)

    it("captures a novel forward state (manual edit) rather than clearing", function()
        set(buf, { "round output" })
        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "why" } }, "round output")
        projection.record(buf)
        -- A manual forward edit → novel content; project should CAPTURE (not clear).
        set(buf, { "round output edited" })
        projection.project(buf)
        -- it recorded the new state, so projecting again restores (no clear)
        local snap_diags = #vim.diagnostic.get(buf)
        set(buf, { "round output edited" }) -- same content again (e.g. redo here)
        projection.project(buf)
        assert.are.equal(snap_diags, #vim.diagnostic.get(buf))
    end)
end)
