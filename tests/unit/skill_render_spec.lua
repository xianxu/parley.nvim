-- Unit tests for lua/parley/skill_render.lua — the salvaged buffer-decoration
-- helpers (INFO diagnostics + DiffChange highlights for applied skill edits).

local skill_render = require("parley.skill_render")

local function scratch(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    return buf
end

describe("skill_render", function()
    it("attach_diagnostics sets an INFO diagnostic per edit, on the edit's line", function()
        local buf = scratch({ "line one", "line two", "line three" })
        local original = "line one\nline two\nline three"
        -- pos within "line two" (after the first newline)
        local pos = original:find("two", 1, true)
        skill_render.attach_diagnostics(buf, { { pos = pos, explain = "changed two" } }, original)
        local diags = vim.diagnostic.get(buf)
        assert.are.equal(1, #diags)
        assert.are.equal(1, diags[1].lnum) -- 0-indexed line 1 = "line two"
        assert.matches("changed two", diags[1].message)
        assert.are.equal(vim.diagnostic.severity.INFO, diags[1].severity)
    end)

    it("clear_decorations removes the diagnostics", function()
        local buf = scratch({ "x" })
        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")
        assert.is_true(#vim.diagnostic.get(buf) > 0)
        skill_render.clear_decorations(buf)
        assert.are.equal(0, #vim.diagnostic.get(buf))
    end)

    it("highlight_edits runs without error on edited regions", function()
        local buf = scratch({ "alpha", "BETA", "gamma" })
        -- should not raise; highlights the line containing new_string
        skill_render.highlight_edits(buf, { { new_string = "BETA" } }, "alpha\nBETA\ngamma")
    end)

    it("a non-empty edit produces highlight extmarks", function()
        local buf = scratch({ "alpha", "BETA", "gamma" })
        skill_render.highlight_edits(buf, { { new_string = "BETA" } }, "alpha\nBETA\ngamma")
        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
        local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, {})
        assert.is_true(#marks > 0)
    end)

    it("a deletion (empty new_string) gets a gutter diagnostic but no highlight", function()
        local buf = scratch({ "keep this", "delete me", "keep this too" })
        local original = "keep this\ndelete me\nkeep this too"
        local new_content = "keep this\nkeep this too"
        local pos = original:find("delete me", 1, true)
        local edits = { { pos = pos, explain = "removed redundant line", new_string = "" } }
        skill_render.attach_diagnostics(buf, edits, original)
        skill_render.highlight_edits(buf, edits, new_content)
        -- gutter "why" is present (deletion orientation)
        local diags = vim.diagnostic.get(buf)
        assert.are.equal(1, #diags)
        assert.matches("removed redundant line", diags[1].message)
        -- no highlight: empty new_string is skipped (would've spuriously hit line 0)
        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
        local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, {})
        assert.are.equal(0, #marks)
    end)

    it("wrap hard-wraps at word boundaries to the given width", function()
        local w = skill_render.wrap("the quick brown fox jumps over the lazy dog", 12)
        assert.is_truthy(w:find("\n"), "wrapped into multiple lines")
        for line in (w .. "\n"):gmatch("(.-)\n") do
            assert.is_true(#line <= 12 or not line:find(" ", 1, true), "within width or single long word: " .. line)
        end
    end)

    it("attach_diagnostics wraps the message + spans the edit's lines (end_lnum)", function()
        local buf = scratch({ "a", "b", "c", "d" })
        local original = "a\nb\nc\nd"
        local pos = original:find("b")
        skill_render.attach_diagnostics(buf, {
            { pos = pos, explain = string.rep("word ", 30), new_string = "x\ny" },
        }, original)
        local d = vim.diagnostic.get(buf)[1]
        assert.are.equal(1, d.lnum) -- 0-based line of "b"
        assert.are.equal(2, d.end_lnum) -- spans the 2-line new_string
        assert.is_truthy(d.message:find("\n"), "long message is wrapped")
    end)

    it("snapshot captures highlights + diagnostics; apply_snapshot restores them", function()
        local buf = scratch({ "line one", "line two", "line three" })
        local content = "line one\nline two\nline three"
        skill_render.highlight_edits(buf, { { new_string = "line two" } }, content)
        skill_render.attach_diagnostics(buf, { { pos = content:find("two"), explain = "why two" } }, content)
        local snap = skill_render.snapshot(buf)
        assert.is_true(#snap.hl_lines >= 1)
        assert.is_true(#snap.diags >= 1)
        -- clear → empty, then restore from the snapshot
        skill_render.clear_decorations(buf)
        assert.are.equal(0, #vim.diagnostic.get(buf))
        skill_render.apply_snapshot(buf, snap)
        local diags = vim.diagnostic.get(buf)
        assert.is_true(#diags >= 1)
        assert.matches("why two", diags[1].message)
        local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
        assert.is_true(#vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, {}) >= 1)
    end)

    it("dismiss clears decorations (alias of clear_decorations)", function()
        local buf = scratch({ "x" })
        skill_render.attach_diagnostics(buf, { { pos = 1, explain = "e" } }, "x")
        assert.is_true(#vim.diagnostic.get(buf) > 0)
        skill_render.dismiss(buf)
        assert.are.equal(0, #vim.diagnostic.get(buf))
    end)
end)
