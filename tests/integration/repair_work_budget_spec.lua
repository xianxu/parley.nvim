-- #293: work budgets for repairing a large written block. A tool round's
-- continuation waits for the document to repair what the round wrote, so the
-- work each repair step does is latency the user sees. Counters, not wall time:
-- the same write always does the same work, so these cannot flake.
--
-- Baselines (before #293 M2/M3) are recorded beside each budget.
local parley = require("parley")
local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-repair-budget-" .. os.time()
parley.setup({ chat_dir = tmp_dir, state_dir = tmp_dir .. "/state", providers = {}, api_keys = {} })
vim.api.nvim_create_autocmd("VimLeavePre", { callback = function() vim.fn.delete(tmp_dir, "rf") end })
local highlighter = require("parley.highlighter")
local D = require("parley.document")

local BODY_ROWS = 300
-- Baseline before #293 M2: 483057 summary values copied (and 230111 metadata
-- values, not budgeted: query snapshots and find predicates drive those). The
-- combine copies were ~3 per call on every leaf/branch rebuild; budget = 1/5.
local SUMMARY_BUDGET = 96000

local function block()
    local lines = { "📎: read_file id=budget", "```" }
    for i = 1, BODY_ROWS do lines[#lines + 1] = ("line %03d "):format(i) .. string.rep("w", 40) end
    lines[#lines + 1] = "```"
    return lines
end

describe("repair work budget for a large written block (#293)", function()
    local buf, win, document

    before_each(function()
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false,
            { "# topic: Budget", "- file: budget.md", "---", "", "💬: question", "", "🤖:[Agent]", "" })
        parley._parley_bufs[buf] = "chat"
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        document = highlighter.rebuild_structure(buf)
        assert.equals("idle", D.drain(document).status)
    end)

    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then
            parley._parley_bufs[buf] = nil
            highlighter.clear_structure(buf)
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    -- Append the block and repair it to idle synchronously: no redraw runs, so
    -- the counters are the index's own work.
    local function write_and_repair()
        D.stats(document, true)
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, block())
        assert.equals("idle", D.drain(document, 100000).status)
        return D.stats(document)
    end

    it("repairs the block within the summary-copy budget", function()
        local work = write_and_repair()
        assert.is_true((work.summary_values_copied or 0) <= SUMMARY_BUDGET,
            ("summary_values_copied %d > %d"):format(work.summary_values_copied or 0, SUMMARY_BUDGET))
    end)

    -- Baseline before #293 M3: 256 rows queried to draw 9.
    it("decorates a closed fold over the block by querying only drawn rows", function()
        write_and_repair()
        local first = vim.api.nvim_buf_line_count(buf) - #block() + 1
        vim.wo[win].foldmethod = "manual"
        vim.cmd(("%d,%dfold"):format(first, vim.api.nvim_buf_line_count(buf)))
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        local queried, query = 0, D.query
        D.query = function(doc, a, b, opts)
            queried = queried + (b - a)
            return query(doc, a, b, opts)
        end
        local ok, err = pcall(vim.api.nvim__redraw, { win = win, valid = false, flush = true })
        D.query = query
        assert.is_true(ok, tostring(err))
        local drawn = vim.api.nvim_buf_line_count(buf) - #block() + 1 -- rows before the fold + its first row
        assert.is_true(queried > 0, "the decoration provider did not run")
        assert.is_true(queried <= drawn + highlighter._VIEWPORT_MARGIN + 1, ("queried %d rows to draw %d"):format(queried, drawn))
    end)

    -- PQ-3: opening a fold without scrolling must decorate its interior on the
    -- next redraw; closing it bounds the query again. (Each redraw recomputes
    -- the current spans, which carries this; the cache's fold key covers a pass
    -- resuming over 256+ drawn rows, which a 22-row test window cannot reach.)
    it("decorates a fold's interior once it is opened, and stops once closed", function()
        write_and_repair()
        local first = vim.api.nvim_buf_line_count(buf) - #block() + 1
        -- The block starts inside the 22-row window, so opening its fold shows
        -- this row without any scroll: only the fold state changes.
        local interior = first - 1 + 5 -- 0-based
        vim.wo[win].foldmethod = "manual"
        vim.cmd(("%d,%dfold"):format(first, vim.api.nvim_buf_line_count(buf)))
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        local query, ranges = D.query, {}
        D.query = function(doc, a, b, opts)
            ranges[#ranges + 1] = { a, b }
            return query(doc, a, b, opts)
        end
        local function redraw()
            ranges = {}
            vim.api.nvim__redraw({ win = win, valid = false, flush = true })
            local covered = false
            for _, r in ipairs(ranges) do if interior >= r[1] and interior < r[2] then covered = true end end
            return covered
        end
        local ok, err = pcall(function()
            assert.is_false(redraw(), "a closed fold's interior was queried")
            local top = vim.api.nvim_win_call(win, function() return vim.fn.line("w0") end)
            vim.cmd(("%dfoldopen"):format(first))
            assert.equals(top, vim.api.nvim_win_call(win, function() return vim.fn.line("w0") end), "the view scrolled")
            assert.is_true(redraw(), "the opened fold's interior was not decorated")
            vim.cmd(("%dfoldclose"):format(first))
            assert.is_false(redraw(), "the re-closed fold's interior was queried again")
        end)
        D.query = query
        assert.is_true(ok, tostring(err))
    end)
end)
