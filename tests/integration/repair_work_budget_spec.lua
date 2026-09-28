-- #293: work budgets for repairing a large written block. A tool round's
-- continuation waits for the document to repair what the round wrote, so the
-- work each repair step does is latency the user sees. Counters, not wall time:
-- the same write always does the same work, so these cannot flake.
--
-- Baselines (before #293 M2/M3) are recorded beside each budget.
local parley = require("parley")
local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-repair-budget-" .. os.time()
parley.setup({ chat_dir = tmp_dir, state_dir = tmp_dir .. "/state", providers = {}, api_keys = {} })
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

    -- Enabled by #293 M2.
    pending("repairs the block within the summary-copy budget", function()
        local work = write_and_repair()
        assert.is_true((work.summary_values_copied or 0) <= SUMMARY_BUDGET,
            ("summary_values_copied %d > %d"):format(work.summary_values_copied or 0, SUMMARY_BUDGET))
    end)

    -- Baseline before #293 M3: 256 rows queried to draw 9. Enabled by M3.
    pending("decorates a closed fold over the block by querying only drawn rows", function()
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
        assert.is_true(queried <= drawn + 21, ("queried %d rows to draw %d"):format(queried, drawn))
    end)
end)
