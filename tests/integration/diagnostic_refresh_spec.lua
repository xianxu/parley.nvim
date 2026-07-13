local buffer_lifecycle = require("parley.buffer_lifecycle")
local diagnostic_refresh = require("parley.diagnostic_refresh")
local skill_render = require("parley.skill_render")
local timezone = require("parley.timezone_diagnostics")

describe("diagnostic refresh lifecycle", function()
    local buf
    local lifecycle
    local function footnotes(bufnr)
        local found = {}
        for _, diagnostic in ipairs(vim.diagnostic.get(bufnr, { namespace = skill_render.diag_namespace() })) do
            if diagnostic.source == "parley-footnote" then table.insert(found, diagnostic) end
        end
        return found
    end

    before_each(function()
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        local group = vim.api.nvim_create_augroup("parley-test-diagnostic-lifecycle", { clear = true })
        lifecycle = buffer_lifecycle._new({
            is_valid = vim.api.nvim_buf_is_valid,
            diagnostics = diagnostic_refresh,
            structure = { rebuild = function() end, clear = function() end },
            create_autocmd = function(events, callback)
                vim.api.nvim_create_autocmd(events, { group = group, callback = callback })
            end,
        })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "time 2026-07-12T12:00:00Z and ASIN[^asin]",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        })
        lifecycle.setup(buf)
    end)

    after_each(function()
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    it("keeps diagnostics stale during TextChangedI", function()
        assert.equals(1, #vim.diagnostic.get(buf, { namespace = timezone.diag_namespace() }))
        assert.equals(1, #footnotes(buf))
        vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "time and reference removed" })
        vim.api.nvim_exec_autocmds("TextChangedI", { buffer = buf })
        assert.equals(1, #vim.diagnostic.get(buf, { namespace = timezone.diag_namespace() }))
        assert.equals(1, #footnotes(buf))
    end)

    for _, case in ipairs({
        { event = "InsertLeave", name = "refreshes synchronously on InsertLeave" },
        { event = "TextChanged", name = "refreshes synchronously on TextChanged" },
        { event = "BufWritePost", name = "refreshes synchronously on BufWritePost" },
        { event = "BufEnter", name = "hydrates on BufEnter" },
        { event = "WinEnter", name = "hydrates on WinEnter" },
    }) do
        it(case.name, function()
            vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "time and reference removed" })
            vim.api.nvim_exec_autocmds(case.event, { buffer = buf })
            assert.equals(0, #vim.diagnostic.get(buf, { namespace = timezone.diag_namespace() }))
            assert.equals(0, #footnotes(buf))
        end)
    end

    it("footnote teardown preserves unrelated shared diagnostics", function()
        local ns = skill_render.diag_namespace()
        local existing = vim.diagnostic.get(buf, { namespace = ns })
        table.insert(existing, {
            lnum = 0, col = 0, message = "unrelated", source = "parley-edit",
            severity = vim.diagnostic.severity.INFO,
        })
        vim.diagnostic.set(ns, buf, existing)
        skill_render.clear_footnote_diagnostics(buf)
        local remaining = vim.diagnostic.get(buf, { namespace = ns })
        assert.equals(1, #remaining)
        assert.equals("unrelated", remaining[1].message)
    end)

    for _, event in ipairs({ "BufUnload", "BufDelete" }) do
        it("clears timezone and footnotes on " .. event, function()
            local ns = skill_render.diag_namespace()
            local existing = vim.diagnostic.get(buf, { namespace = ns })
            table.insert(existing, {
                lnum = 0, col = 0, message = "unrelated", source = "parley-edit",
                severity = vim.diagnostic.severity.INFO,
            })
            vim.diagnostic.set(ns, buf, existing)
            vim.api.nvim_exec_autocmds(event, { buffer = buf })
            assert.equals(0, #vim.diagnostic.get(buf, { namespace = timezone.diag_namespace() }))
            local remaining = vim.diagnostic.get(buf, { namespace = ns })
            assert.equals(1, #remaining)
            assert.equals("unrelated", remaining[1].message)
        end)
    end
end)
