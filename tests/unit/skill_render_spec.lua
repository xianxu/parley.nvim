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
end)
