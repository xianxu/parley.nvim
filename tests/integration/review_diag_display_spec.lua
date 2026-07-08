-- Integration tests for the review-diagnostic inline display toggle (#133 M6).

local dd = require("parley.skills.review.diag_display")

local function ns_cfg()
    return vim.diagnostic.config(nil, require("parley.skill_render").diag_namespace())
end

local function display_marks(buf)
    local display_ns = vim.api.nvim_create_namespace("parley_diagnostic_virtual_lines")
    return vim.api.nvim_buf_get_extmarks(buf, display_ns, 0, -1, { details = true })
end

local function diagnostic_floats()
    local floats = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative ~= "" and cfg.focusable == false and cfg.title and cfg.title[1][1] == "Diagnostics" then
            table.insert(floats, { win = win, config = cfg, buf = vim.api.nvim_win_get_buf(win) })
        end
    end
    return floats
end

describe("review.diag_display", function()
    after_each(function()
        dd.set(true) -- restore default for other specs
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) then
                pcall(vim.diagnostic.reset, require("parley.skill_render").diag_namespace(), buf)
            end
        end
    end)

    it("toggles the enabled state", function()
        dd.set(true)
        assert.is_true(dd.is_enabled())
        assert.is_false(dd.toggle())
        assert.is_false(dd.is_enabled())
        assert.is_true(dd.toggle())
        assert.is_true(dd.is_enabled())
    end)

    it("configures Parley's custom current-line display on its namespace when on; off when disabled", function()
        dd.set(true)
        local on = ns_cfg()
        assert.is_false(on.virtual_lines) -- Parley owns its virtual-lines renderer.
        assert.is_truthy(on["parley/virtual_lines"])
        assert.is_false(on.virtual_text) -- inline single-line is never used
        dd.set(false)
        assert.is_false(ns_cfg()["parley/virtual_lines"])
    end)

    it("renders footnote diagnostics in a centered non-focusable float without moving the diagnostic span", function()
        local skill_render = require("parley.skill_render")
        local diag_ns = skill_render.diag_namespace()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_win_set_width(0, 100)
        local parent_width = vim.api.nvim_win_get_width(0)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            string.rep("x", 120) .. " ACOS[^acos]",
        })
        vim.api.nvim_win_set_cursor(0, { 1, 122 })

        dd.set(true)
        vim.diagnostic.set(diag_ns, buf, { {
            lnum = 0,
            col = 121,
            end_lnum = 0,
            end_col = 132,
            message = "ACOS — Advertising Cost of Sales.",
            severity = vim.diagnostic.severity.INFO,
            source = "parley-footnote",
        } })

        vim.wait(100, function()
            return #diagnostic_floats() == 1
        end)

        assert.are.equal(0, #display_marks(buf))
        local floats = diagnostic_floats()
        assert.are.equal(1, #floats)
        local expected_width = math.max(1, math.floor(parent_width * 0.8))
        assert.are.equal(expected_width, floats[1].config.width)
        assert.are.equal(math.floor((parent_width - expected_width) / 2), floats[1].config.col)
        assert.is_false(floats[1].config.focusable)
        local lines = vim.api.nvim_buf_get_lines(floats[1].buf, 0, -1, false)
        assert.are.equal("Diagnostics:", lines[1])
        assert.are.equal("ACOS — Advertising Cost of Sales.", lines[2])

        local diagnostics = vim.diagnostic.get(buf, { namespace = diag_ns })
        assert.are.equal(1, #diagnostics)
        assert.are.equal(0, diagnostics[1].lnum)
        assert.are.equal(121, diagnostics[1].col)
        assert.are.equal(0, diagnostics[1].end_lnum)
        assert.are.equal(132, diagnostics[1].end_col)

        dd.set(false)
        assert.are.equal(0, #display_marks(buf))
        assert.are.equal(0, #diagnostic_floats())
        assert.are.equal(1, #vim.diagnostic.get(buf, { namespace = diag_ns }))
    end)

    it("shows footnote diagnostics only while the cursor is inside the anchor span", function()
        local skill_render = require("parley.skill_render")
        local diag_ns = skill_render.diag_namespace()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            'before ACOS[^acos] after the anchor on the same line',
        })

        dd.set(true)
        vim.diagnostic.set(diag_ns, buf, { {
            lnum = 0,
            col = 7,
            end_lnum = 0,
            end_col = 18,
            message = "ACOS — Advertising Cost of Sales.",
            severity = vim.diagnostic.severity.INFO,
            source = "parley-footnote",
        } })
        assert.are.equal(0, #display_marks(buf), "cursor starts before the footnote anchor")

        vim.api.nvim_win_set_cursor(0, { 1, 8 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        assert.are.equal(1, #diagnostic_floats(), "cursor inside the footnote anchor should show diagnosis")

        vim.api.nvim_win_set_cursor(0, { 1, 25 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        assert.are.equal(0, #diagnostic_floats(), "same line outside the anchor should hide diagnosis")
    end)

    it("keeps a multi-line diagnostic visible anywhere inside its span", function()
        local skill_render = require("parley.skill_render")
        local diag_ns = skill_render.diag_namespace()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "edited line one",
            "edited line two",
            "edited line three",
        })

        dd.set(true)
        vim.diagnostic.set(diag_ns, buf, { {
            lnum = 0,
            col = 0,
            end_lnum = 2,
            end_col = 17,
            message = "review explanation",
            severity = vim.diagnostic.severity.INFO,
            source = "parley-skill",
        } })
        assert.are.equal(1, #display_marks(buf))

        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        assert.are.equal(1, #display_marks(buf), "span diagnostic should show on middle line")

        vim.api.nvim_win_set_cursor(0, { 3, 0 })
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
        assert.are.equal(1, #display_marks(buf), "span diagnostic should show on final line")
    end)
end)
