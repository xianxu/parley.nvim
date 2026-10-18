-- skill_render's round kind (#383): the agent's last round, drawn as
-- highlights plus diagnostics in the shared review namespace, beside the
-- footnote and review-skill kinds and never clearing them.
local skill_render = require("parley.skill_render")

describe("skill_render round", function()
    local buf

    local function kinds()
        local out = {}
        for _, d in ipairs(vim.diagnostic.get(buf, { namespace = skill_render.diag_namespace() })) do
            out[#out + 1] = (d.user_data or {}).parley_kind or d.source
        end
        table.sort(out)
        return out
    end

    local function round_marks()
        return vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_create_namespace("parley_round_hl"), 0, -1,
            { details = true })
    end

    before_each(function()
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# Title", "the new text here", "tail" })
    end)

    after_each(function()
        vim.api.nvim_buf_delete(buf, { force = true })
    end)

    local decorations = {
        { lnum = 1, col = 4, end_lnum = 1, end_col = 12, message = "why", deletion = false },
        { lnum = 2, col = 0, end_lnum = 2, end_col = 0, message = "deleted: gone", deletion = true },
    }

    it("draws each span with its message, a deletion as a zero-width mark on its line", function()
        skill_render.publish_round(buf, decorations)
        local marks = round_marks()
        assert.equals(2, #marks)
        assert.same({ 1, 4, 1, 12 }, { marks[1][2], marks[1][3], marks[1][4].end_row, marks[1][4].end_col })
        assert.equals("ParleyAgentChange", marks[1][4].hl_group)
        assert.is_nil(marks[2][4].hl_group)
        local diagnostics = vim.diagnostic.get(buf, { namespace = skill_render.diag_namespace() })
        assert.same({ "why", "deleted: gone" }, { diagnostics[1].message, diagnostics[2].message })
        assert.same({ "parley-round", "round" }, { diagnostics[1].source, diagnostics[1].user_data.parley_kind })
        assert.equals(2, diagnostics[2].lnum)
    end)

    it("keeps footnote and review-skill diagnostics through publish and clear", function()
        local ns = skill_render.diag_namespace()
        vim.diagnostic.set(ns, buf, { { lnum = 0, col = 0, message = "skill", source = "parley-skill" } })
        skill_render.publish_footnotes(buf, { { lnum = 2, col = 0, end_col = 4, term = "tail", definition = "end" } })
        skill_render.publish_round(buf, decorations)
        assert.same({ "footnote", "parley-skill", "round", "round" }, kinds())
        skill_render.clear_round(buf)
        assert.same({ "footnote", "parley-skill" }, kinds())
        assert.equals(0, #round_marks())
    end)

    it("keeps the round's diagnostics when a skill round sets its own", function()
        skill_render.publish_round(buf, decorations)
        skill_render.attach_diagnostics(buf, { { pos = 0, explain = "skill edit" } }, "# Title\n")
        assert.same({ "parley-skill", "round", "round" }, kinds())
    end)

    it("re-derives the diagnostics from where the marks moved", function()
        skill_render.publish_round(buf, decorations)
        vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "inserted" })
        skill_render.rederive_round(buf)
        local diagnostics = vim.diagnostic.get(buf, { namespace = skill_render.diag_namespace() })
        assert.same({ 2, 4, 2, 12 }, { diagnostics[1].lnum, diagnostics[1].col, diagnostics[1].end_lnum,
            diagnostics[1].end_col })
        assert.equals(3, diagnostics[2].lnum)
    end)

    it("draws a position past the end of the buffer without raising", function()
        skill_render.publish_round(buf, { { lnum = 9, col = 99, end_lnum = 9, end_col = 120, message = "far" } })
        assert.equals(1, #round_marks())
    end)
end)
