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
        diagnostic_refresh.drain(buf,10000)
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
        { event = "InsertLeave", name = "converges through scheduled repair after InsertLeave" },
        { event = "TextChanged", name = "converges through scheduled repair after TextChanged" },
        { event = "BufWritePost", name = "converges through scheduled repair after BufWritePost" },
        { event = "BufEnter", name = "hydrates on BufEnter" },
        { event = "WinEnter", name = "hydrates on WinEnter" },
    }) do
        it(case.name, function()
            vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "time and reference removed" })
            vim.api.nvim_exec_autocmds(case.event, { buffer = buf })
            diagnostic_refresh.drain(buf,10000)
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

    for _, case in ipairs({
        { event = "BufUnload", name = "clears on BufUnload" },
        { event = "BufDelete", name = "clears on BufDelete" },
    }) do
        it(case.name, function()
            local ns = skill_render.diag_namespace()
            local existing = vim.diagnostic.get(buf, { namespace = ns })
            table.insert(existing, {
                lnum = 0, col = 0, message = "unrelated", source = "parley-edit",
                severity = vim.diagnostic.severity.INFO,
            })
            vim.diagnostic.set(ns, buf, existing)
            vim.api.nvim_exec_autocmds(case.event, { buffer = buf })
            diagnostic_refresh.drain(buf,10000)
            assert.equals(0, #vim.diagnostic.get(buf, { namespace = timezone.diag_namespace() }))
            local remaining = vim.diagnostic.get(buf, { namespace = ns })
            assert.equals(1, #remaining)
            assert.equals("unrelated", remaining[1].message)
        end)
    end
end)

describe('diagnostic publication evidence',function()
    local buf,doc
    local D=require('parley.document')
    before_each(function()
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'intro','time 2026-07-12T12:00:00Z'})
        doc=D.attach(buf,{schedule=false})
        assert.equals('idle',D.drain(doc,1000).status)
        diagnostic_refresh.refresh(buf,{schedule=false})
    end)
    after_each(function()
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end
    end)
    local function prepare_publication(phase)
        for _=1,100 do
            if diagnostic_refresh.step(buf).status==(phase or 'publish') then return end
        end
        error('diagnostic derivation did not reach publication')
    end
    for _,phase in ipairs({'read','publish'}) do
    it('revalidates pending '..phase..' work after incoming context becomes uncertain',function()
        prepare_publication(phase)
        vim.api.nvim_buf_set_text(buf,0,0,0,5,{'```'})
        assert.is_false(D.query(doc,1,2)[1].metadata.confirmed)
        assert.not_equals('idle',diagnostic_refresh.step(buf).status)
        assert.equals(0,#vim.diagnostic.get(buf,{namespace=timezone.diag_namespace()}))
        assert.equals('idle',diagnostic_refresh.drain(buf,1000).status)
        assert.equals(1,#vim.diagnostic.get(buf,{namespace=timezone.diag_namespace()}))
    end)
    end
    it('retains prepared results when an unrelated text edit preserves semantic context',function()
        prepare_publication()
        vim.api.nvim_buf_set_text(buf,0,5,0,5,{' extended'})
        assert.is_true(D.query(doc,1,2)[1].metadata.confirmed)
        assert.equals('idle',diagnostic_refresh.step(buf).status)
        assert.equals(1,#vim.diagnostic.get(buf,{namespace=timezone.diag_namespace()}))
    end)
end)
