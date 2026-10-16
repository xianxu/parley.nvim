-- Attached UI is essential: headless-only folds preserve topline accidentally.
describe("stream fold maintenance preserves each window view", function()
    local child
    local function exec(source, ...)
        return vim.rpcrequest(child, "nvim_exec_lua", source, { ... })
    end

    before_each(function()
        child = vim.fn.jobstart({ vim.v.progpath, "--clean", "--embed", "--headless", "-i", "NONE" }, { rpc = true })
        assert.is_true(child > 0)
        vim.rpcrequest(child, "nvim_ui_attach", 100, 30, { rgb = true })
        exec("vim.opt.runtimepath:prepend(...)", vim.fn.getcwd())
        exec([[
            folds = require("parley.tool_folds")
            function fixture(thinking, wrapped)
                local lines = { "header", "", "💬: q", "", "🤖: a", "" }
                if thinking then
                    vim.list_extend(lines, { "🧠: first", "thinking", "more thinking", "" })
                end
                for n = 1, 200 do lines[#lines + 1] = "text " .. n end
                if wrapped then lines[170] = string.rep("word ", 400) end
                buf = vim.api.nvim_create_buf(false, true)
                vim.api.nvim_set_current_buf(buf)
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                document = require("parley.document").attach(buf, { schedule = false })
                assert(require("parley.document").drain(document, 100000).status == "idle")
                windows = { vim.api.nvim_get_current_win() }
                vim.cmd("vsplit")
                windows[2] = vim.api.nvim_get_current_win()
                folds.setup(buf)
                assert(folds.flush(buf) == "idle")
                for i, win in ipairs(windows) do
                    vim.wo[win].foldmethod = "manual"
                    vim.wo[win].scrolloff = 0
                    vim.wo[win].smoothscroll = true
                    vim.api.nvim_win_call(win, function()
                        if wrapped and i == 1 then
                            vim.fn.winrestview({ lnum = 170, col = 800, topline = 170, skipcol = 500 })
                        else
                            vim.fn.winrestview({ lnum = i == 1 and 170 or 110, col = 0,
                                topline = i == 1 and 160 or 105 })
                        end
                    end)
                end
                vim.cmd("redraw")
            end
            function views()
                vim.cmd("redraw")
                local result = {}
                for i, win in ipairs(windows) do
                    result[i] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
                end
                return result
            end
            function append()
                vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "new token" })
                assert(require("parley.document").drain(document, 100000).status == "idle")
                assert(folds.flush(buf) == "idle")
            end
        ]])
    end)

    after_each(function()
        if child and child > 0 then
            vim.fn.jobstop(child)
            vim.fn.jobwait({ child }, 1000)
        end
    end)

    for _, thinking in ipairs({ false, true }) do
        it("retains two independent views with " .. (thinking and "a thinking fold" or "no folds"), function()
            exec("fixture(...)", thinking)
            local before = exec("return views()")
            exec("folds.with_exchange_update(buf, nil, nil, append)")
            assert.same(before, exec("return views()"))
            if thinking then
                assert.equals(7, exec("return vim.api.nvim_win_call(windows[1], function() return vim.fn.foldclosed(7) end)"))
            end
        end)
    end

    it("retains intentional follow movement inside the mutation", function()
        exec("fixture(true)")
        local before = exec("return views()")
        exec([[
            folds.with_exchange_update(buf, nil, nil, function()
                append()
                vim.api.nvim_win_call(windows[2], function()
                    vim.api.nvim_win_set_cursor(windows[2], { vim.api.nvim_buf_line_count(buf), 0 })
                    vim.cmd("normal! zb")
                end)
                followed = views()[2]
            end)
        ]])
        local after = exec("return views()")
        assert.same(before[1], after[1])
        assert.same(exec("return followed"), after[2])
        assert.equals(exec("return vim.api.nvim_buf_line_count(buf)"), after[2].lnum)
    end)

    it("preserves views and rethrows when mutation fails", function()
        exec("fixture(true)")
        local before = exec("return views()")
        local result = exec([[
            local ok, err = pcall(folds.with_exchange_update, buf, nil, nil, function()
                append()
                error("synthetic stream mutation failure")
            end)
            return { ok = ok, err = err }
        ]])
        assert.is_false(result.ok)
        assert.matches("synthetic stream mutation failure", result.err, 1, true)
        assert.same(before, exec("return views()"))
    end)

    it("restores view and foldenable if the fold walk fails", function()
        exec("fixture(false)")
        exec("vim.wo[windows[1]].foldenable = false")
        local before = exec("return views()")
        local result = exec([[
            local original = vim.api.nvim_exec2
            vim.api.nvim_exec2 = function()
                vim.wo.foldenable = true
                vim.api.nvim_win_set_cursor(0, { 3, 0 })
                error("synthetic fold walk failure")
            end
            local ok, err = pcall(function() folds.apply_folds(buf); folds.flush(buf) end)
            vim.api.nvim_exec2 = original
            local win = windows[1]
            return { ok = ok, err = err, enabled = vim.wo[win].foldenable }
        ]])
        assert.is_false(result.ok)
        assert.matches("synthetic fold walk failure", result.err, 1, true)
        assert.is_false(result.enabled)
        assert.same(before, exec("return views()"))
    end)

    it("preserves a smooth-scrolled wrapped line", function()
        exec("fixture(false, true)")
        local before = exec("return views()")
        assert.is_true(before[1].skipcol > 0)
        exec("folds.with_exchange_update(buf, nil, nil, append)")
        assert.same(before, exec("return views()"))
    end)
end)

describe("helper.cursor_to_line", function()
    it("keeps the row-only default and rejects another current buffer", function()
        local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "question", "", "text" })
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        require("parley.helper").cursor_to_line(3, buf, win)
        assert.same({ 3, 0 }, vim.api.nvim_win_get_cursor(win))
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        local other = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(other)
        require("parley.helper").cursor_to_line(3, buf, win, 4)
        vim.api.nvim_set_current_buf(buf)
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(win))
        vim.api.nvim_buf_delete(other, { force = true })
    end)
end)
