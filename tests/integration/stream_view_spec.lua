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

-- A real attached UI is required to observe wrapped-line scrolling. RPC input
-- and schedule_wrap are asynchronous: wait for observable state, then redraw.
describe("streaming cursor follows the rendered frontier", function()
    local child
    local function exec(source, ...)
        return vim.rpcrequest(child, "nvim_exec_lua", source, { ... })
    end
    local function snapshot()
        return exec([[
            vim.cmd("redraw")
            return { view = vim.fn.winsaveview(), cursor = vim.api.nvim_win_get_cursor(win),
                text = vim.api.nvim_buf_get_lines(buf, 2, -1, false),
                qt = { last_line = tasker.get_query("view").last_line, last_col = tasker.get_query("view").last_col } }
        ]])
    end
    local function await_state(predicate)
        local last
        local ok = vim.wait(1000, function()
            last = snapshot()
            return predicate(last)
        end, 10)
        assert.is_true(ok, "UI did not settle: " .. vim.inspect(last))
        return snapshot()
    end
    local function chunk(text, expected)
        exec("handler('view', ...)", text)
        return await_state(function(s)
            return vim.deep_equal(s.text, expected) and s.qt.last_col == #expected[#expected]
        end)
    end

    before_each(function()
        child = vim.fn.jobstart({ vim.v.progpath, "--clean", "--embed", "--headless", "-i", "NONE" }, { rpc = true })
        assert.is_true(child > 0)
        vim.rpcrequest(child, "nvim_ui_attach", 80, 24, { rgb = true })
        exec("vim.opt.runtimepath:prepend(...)", vim.fn.getcwd())
        exec([[
            vim.o.mouse = "a"
            vim.o.scrolloff = 0
            vim.o.wrap = true
            vim.o.linebreak = false
            vim.o.smoothscroll = false
            require("parley").setup({ chat_dir = vim.fn.tempname(), state_dir = vim.fn.tempname(),
                providers = {}, api_keys = {}, cliproxy = { manage = false }, default_keymaps = false })
            tasker = require("parley.tasker")
            buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "question", "", "" })
            tasker.set_query("view", { response = "", buf = buf })
            function start(follow, prefix)
                handler = require("parley.dispatcher").create_handler(buf, win, 2, true, prefix or "", follow)
            end
        ]])
    end)
    after_each(function()
        if child and child > 0 then
            vim.fn.jobstop(child)
            vim.fn.jobwait({ child }, 1000)
        end
    end)

    it("keeps the tip visible as one paragraph grows past the screen bottom", function()
        exec("start(true)")
        chunk("short", { "short" })
        local paragraph = "short" .. string.rep(" word", 700)
        local state = chunk(string.rep(" word", 700), { paragraph })
        assert.equals(#paragraph - 1, state.cursor[2])
        assert.is_true(state.view.skipcol > 0)
        local screen = exec("return vim.fn.screenpos(win, 3, #vim.api.nvim_get_current_line())")
        assert.is_true(screen.row > 0 and screen.row <= 24, vim.inspect(screen))
        state = chunk(" tip", { paragraph .. " tip" })
        assert.equals(#paragraph + 3, state.cursor[2])
        assert.is_true(state.view.skipcol > 0)
    end)

    it("allows a wheel scroll and returns to the text tip on the next followed chunk", function()
        exec("vim.o.smoothscroll = true; start(true)")
        local paragraph = string.rep("word ", 700)
        chunk(paragraph, { paragraph })
        local before = snapshot()
        for _ = 1, 4 do
            vim.rpcrequest(child, "nvim_input_mouse", "wheel", "up", "", 0, 10, 30)
        end
        local up = await_state(function(s) return s.view.skipcol < before.view.skipcol end)
        vim.rpcrequest(child, "nvim_input_mouse", "wheel", "down", "", 0, 10, 30)
        await_state(function(s) return s.view.skipcol > up.view.skipcol end)
        local state = chunk("tip", { paragraph .. "tip" })
        assert.equals(#paragraph + 2, state.cursor[2])
        assert.is_true(state.view.skipcol >= before.view.skipcol)
    end)

    it("preserves a manual wheel view with follow disabled", function()
        exec("follow = true; start(function() return follow end); follow = false")
        local lines = {}
        for i = 1, 100 do lines[i] = "line " .. i end
        chunk(table.concat(lines, "\n"), lines)
        exec("vim.api.nvim_win_set_cursor(win, { 40, 0 }); vim.cmd('normal! zt')")
        local before = snapshot()
        vim.rpcrequest(child, "nvim_input_mouse", "wheel", "down", "", 0, 10, 30)
        local scrolled = await_state(function(s) return s.view.topline > before.view.topline end)
        lines[100] = lines[100] .. " tip"
        local after = chunk(" tip", lines)
        assert.same(scrolled.view, after.view)
    end)

    it("tracks prefixed multibyte pending text and newline endpoints", function()
        exec("start(true, '🧠: ')")
        local state = chunk("café", { "🧠: café" })
        assert.equals(#"🧠: café", state.qt.last_col)
        assert.equals(#"🧠: caf", state.cursor[2])
        state = chunk("\n", { "🧠: café", "🧠: " })
        assert.same({ 4, #"🧠: " - 1 }, state.cursor)
        state = chunk("next", { "🧠: café", "🧠: next" })
        assert.same({ 4, #"🧠: next" - 1 }, state.cursor)
    end)

    it("keeps helper's row-only default and rejects another current buffer", function()
        exec("start(false)")
        chunk("text", { "text" })
        exec("require('parley.helper').cursor_to_line(3, buf, win)")
        assert.same({ 3, 0 }, snapshot().cursor)
        exec([[
            local other = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_set_current_buf(other)
            require("parley.helper").cursor_to_line(3, buf, win, 4)
        ]])
        assert.same({ 1, 0 }, exec("return vim.api.nvim_win_get_cursor(win)"))
    end)
end)
