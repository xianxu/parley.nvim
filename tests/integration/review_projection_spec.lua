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

    it("captures a novel forward state (manual edit) without clearing the riding style", function()
        set(buf, { "round output" })
        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "why" } }, "round output")
        projection.record(buf)
        -- A manual forward edit → novel content; the riding decoration is still
        -- present and project must CAPTURE it (not clear).
        set(buf, { "round output edited" })
        assert.is_true(#vim.diagnostic.get(buf) >= 1, "decoration rides the manual edit")
        projection.project(buf)
        assert.is_true(#vim.diagnostic.get(buf) >= 1, "capture must not clear the riding style")
        -- Move away and back: the captured novel state restores its style.
        set(buf, { "different content entirely" })
        projection.project(buf)
        set(buf, { "round output edited" })
        projection.project(buf)
        assert.is_true(#vim.diagnostic.get(buf) >= 1, "novel state restores its captured style")
    end)

    it("re-renders coherently across TWO rounds of undo", function()
        -- round 1: base0 → A (decoA)
        set(buf, { "state A" })
        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "edit A" } }, "state A")
        projection.record_empty_for(buf, "base zero")
        projection.record(buf)
        -- round 2: A → B (decoB). record_empty_for(A) must NOT clobber A's
        -- already-recorded decorations (the #133-close-review bug).
        set(buf, { "state B" })
        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "edit B" } }, "state B")
        projection.record_empty_for(buf, "state A")
        projection.record(buf)
        -- undo B→A → decoA restored (would clear if record_empty_for clobbered A)
        set(buf, { "state A" })
        projection.project(buf)
        local diags = vim.diagnostic.get(buf)
        assert.is_true(#diags >= 1)
        assert.matches("edit A", diags[1].message)
        -- undo A→base0 → cleared
        set(buf, { "base zero" })
        projection.project(buf)
        assert.are.equal(0, #vim.diagnostic.get(buf))
    end)

    it("set_applying suppresses the watcher (the round's own :edit! is not a user edit)", function()
        set(buf, { "round output" })
        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "why" } }, "round output")
        projection.record(buf)
        projection.record_empty_for(buf, "base")
        projection.set_applying(buf, true)
        set(buf, { "base" }) -- would normally clear via projection
        projection.project(buf) -- guarded → no-op
        assert.is_true(#vim.diagnostic.get(buf) >= 1, "project is a no-op while applying")
        projection.set_applying(buf, false)
    end)
end)
