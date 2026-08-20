local exchange_model = require("parley.exchange_model")
local tool_folds = require("parley.tool_folds")

describe("tool_folds incremental manual folds", function()
    local original_buf
    local buf
    local win

    before_each(function()
        original_buf = vim.api.nvim_get_current_buf()
        buf = vim.api.nvim_create_buf(false, true)
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
        vim.api.nvim_set_option_value("foldenable", true, { win = win })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "header", "", "💬: q", "", "🤖: a", "",
            "🧠: first", "thinking", "", "plain", "tail",
        })
    end)

    after_each(function()
        if vim.api.nvim_buf_is_valid(original_buf) then
            vim.api.nvim_win_set_buf(win, original_buf)
        end
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    local function model_with(kind, size)
        local model = exchange_model.new(1)
        model:add_exchange(1)
        model:add_block(1, "agent_header", 1)
        model:add_block(1, kind, size)
        return model
    end

    it("leaves a user fold outside the rewritten range untouched", function()
        vim.cmd("10,11fold")
        local model = model_with("thinking", 2)
        tool_folds.reconcile_exchange(buf, win, model, 1)
        tool_folds.with_exchange_update(buf, model, 1, function()
            require("parley.buffer_edit").stream_replace_at_line(buf, 7, {
                "thinking", "inserted thinking",
            })
            model:grow_block(1, 3, 1)
        end)
        vim.cmd("normal! zM")

        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(9, vim.fn.foldclosedend(7))
        assert.equals(11, vim.fn.foldclosed(11))
        assert.equals(12, vim.fn.foldclosedend(11))
    end)

    it("builds initial folds from semantic model blocks and clears user folds in the span", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "---", "topic: folds", "file: folds.md", "---", "",
            "💬: q", "", "🤖: [A]", "", "🧠: think", "detail", "",
            "📝: summary", "", "🔧: read id=x", "```json", "{}", "```", "",
            "📎: read id=x", "```", "ok", "```", "", "plain one", "plain two",
        })
        vim.cmd("25,26fold")

        tool_folds.apply_folds(buf)
        vim.cmd("normal! zM")

        assert.equals(10, vim.fn.foldclosed(10))
        assert.equals(11, vim.fn.foldclosedend(10))
        assert.equals(13, vim.fn.foldclosed(13))
        assert.equals(15, vim.fn.foldclosed(15))
        assert.equals(18, vim.fn.foldclosedend(15))
        assert.equals(20, vim.fn.foldclosed(20))
        assert.equals(23, vim.fn.foldclosedend(20))
        -- #200: Parley owns every fold within an exchange span, so a manual
        -- fold over the exchange's trailing prose does not survive a reconcile.
        -- (Contrast the case above, whose fold sits outside every span.)
        assert.equals(-1, vim.fn.foldclosed(25))
    end)

    -- #200: the deleter only zd'd at DESIRED start rows, so a fold anywhere
    -- else in the exchange survived forever — that is what let a drifted fold
    -- anchor on a 💬: line and persist for the whole session.
    it("clears a stale fold anywhere in the exchange, not just at a projected start", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "header", "", "💬: q", "", "🤖: a", "",
            "📎: read_file", "```", "b", "```", "tail",
        })
        local model = exchange_model.new(1)
        model:add_exchange(1)
        model:add_block(1, "agent_header", 1)
        model:add_block(1, "tool_result", 4)
        tool_folds.reconcile_exchange(buf, win, model, 1)

        -- The shape a drifted reconcile leaves behind: a fold no projected
        -- range starts on, covering the question.
        vim.api.nvim_win_call(win, function() vim.cmd("3,6fold") end)

        tool_folds.reconcile_exchange(buf, win, model, 1)
        vim.cmd("normal! zM")

        assert.equals(-1, vim.fn.foldclosed(3))   -- 💬: must not be folded
        assert.equals(7, vim.fn.foldclosed(7))    -- 📎: folded at its own start
        assert.equals(10, vim.fn.foldclosedend(7))
    end)

    -- #200 ROOT CAUSE: reconcile treated the projection as an append list, so a
    -- model that drifted from the buffer anchored a fold on a 💬: line and
    -- nothing ever removed it (hydrate_window latches per buf/win).
    it("never anchors a fold on a user question when the model has drifted", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "---", "topic: t", "file: f.md", "---", "",
            "💬: first", "", "🤖: [A]", "", "📎: read_file",
            "```", "b1", "b2", "```", "", "prose", "",
            "💬: second question", "", "🤖: [A]", "",
            "📎: grep", "```", "c1", "```",
        })
        tool_folds.hydrate_window(buf, win)

        -- A model built BEFORE a mutation that bypassed with_exchange_update.
        local chat_parser = require("parley.chat_parser")
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local model = exchange_model.from_parsed_chat(
            chat_parser.parse_chat(lines, 4, require("parley.config")))
        require("parley.buffer_edit").insert_lines_at(buf, 16, { "x1", "x2", "x3", "x4" })

        tool_folds.reconcile_exchange(buf, win, model, 2)
        vim.cmd("normal! zM")

        local after = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        for i, line in ipairs(after) do
            if line:match("^💬:") then
                assert.message(("question folded at row %d"):format(i))
                    .equals(-1, vim.fn.foldclosed(i))
            end
        end
        -- It healed rather than merely refusing: the real 📎: is folded.
        for i, line in ipairs(after) do
            if line:match("^📎: grep") then
                assert.message(("tool result not folded at row %d"):format(i))
                    .equals(i, vim.fn.foldclosed(i))
            end
        end
    end)

    it("does not throw when drift runs a projected range past the end of the buffer", function()
        local model = exchange_model.new(1)
        model:add_exchange(1)
        model:add_block(1, "agent_header", 1)
        model:add_block(1, "tool_result", 40)  -- far past EOF

        assert.has_no.errors(function()
            tool_folds.reconcile_exchange(buf, win, model, 1)
        end)
        -- Refusing means creating nothing, not merely not crashing.
        assert.is_false(tool_folds.reconcile_exchange(buf, win, model, 1))
        for row = 1, vim.api.nvim_buf_line_count(buf) do
            assert.message(("a fold was created at row %d despite refusal"):format(row))
                .equals(0, vim.fn.foldlevel(row))
        end
    end)

    -- #200 PQ-5: chat_respond wraps EVERY streamed chunk in
    -- with_exchange_update, so reconcile runs per chunk. Clearing the span must
    -- therefore scale with the number of folds present, not with the length of
    -- the exchange — otherwise a long tool body makes streaming quadratic.
    --
    -- Timed under a loaded test suite, so each size is sampled repeatedly and
    -- compared on its MINIMUM: the least-contended sample is the one that
    -- reflects the algorithm rather than the machine.
    it("clears an exchange span without a per-row walk as the span grows", function()
        local function best_reconcile_ms(body_lines)
            local lines = { "header", "", "💬: q", "", "🤖: a", "", "🔧: read id=x" }
            for i = 1, body_lines do lines[#lines + 1] = "body " .. i end
            local probe = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(probe, 0, -1, false, lines)
            vim.api.nvim_win_set_buf(win, probe)
            vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
            vim.api.nvim_set_option_value("foldenable", true, { win = win })

            local model = exchange_model.new(1)
            model:add_exchange(1)
            model:add_block(1, "agent_header", 1)
            model:add_block(1, "tool_use", body_lines + 1)
            tool_folds.reconcile_exchange(probe, win, model, 1)

            local best = math.huge
            for _ = 1, 5 do
                local started = vim.loop.hrtime()
                for _ = 1, 20 do
                    tool_folds.reconcile_exchange(probe, win, model, 1)
                end
                best = math.min(best, (vim.loop.hrtime() - started) / 1e6)
            end
            vim.api.nvim_win_set_buf(win, buf)
            vim.api.nvim_buf_delete(probe, { force = true })
            return best
        end

        local small = best_reconcile_ms(50)
        local large = best_reconcile_ms(800)  -- 16x the rows, still one fold

        -- A row-walk puts this near 16x; fold-to-fold navigation keeps it flat.
        -- The bound is deliberately loose — it exists to catch a return to
        -- O(span), not to police small constant-factor drift.
        assert.message(("50-row span %.2fms vs 800-row span %.2fms — clearing scales with span")
            :format(small, large)).is_true(large < small * 6 + 3)
    end)

    -- #200 C1: widening destruction (projected start rows -> whole span) without
    -- widening verification let a drifted reconcile delete a NEIGHBOUR's fold,
    -- which nothing recreates. Note exchange 1 has no foldable block, so range
    -- verification passes vacuously — the span check is what catches this.
    it("does not destroy a neighbouring exchange's fold when its own span drifted", function()
        local lines = { "---", "topic: t", "file: f.md", "---", "",
            "💬: first", "", "🤖: [A]" }
        for i = 1, 12 do lines[#lines + 1] = "prose " .. i end
        vim.list_extend(lines, { "", "💬: second", "", "🤖: [A]", "",
            "📎: grep", "```", "c1", "```" })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        tool_folds.hydrate_window(buf, win)

        local chat_parser = require("parley.chat_parser")
        local stale = exchange_model.from_parsed_chat(chat_parser.parse_chat(
            vim.api.nvim_buf_get_lines(buf, 0, -1, false), 4, require("parley.config")))

        vim.api.nvim_buf_set_lines(buf, 8, 18, false, {})  -- bypass with_exchange_update
        tool_folds.reconcile_exchange(buf, win, stale, 1)

        local row
        for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if line:match("^📎: grep") then row = i end
        end
        assert.message("the neighbouring tool fold was destroyed by a drifted span")
            .equals(row, vim.fn.foldclosed(row))
    end)

    it("reports which half of the model drifted when it refuses", function()
        local seen
        tool_folds._observer = function(e) if e.phase == "drift" then seen = e end end

        local model = exchange_model.new(1)
        model:add_exchange(1)
        model:add_block(1, "agent_header", 1)
        model:add_block(1, "tool_result", 40)  -- anchors nowhere; past EOF

        tool_folds.reconcile_exchange(buf, win, model, 1)
        tool_folds._observer = nil

        assert.is_not_nil(seen)
        assert.equals("ranges", seen.which)
        assert.equals(1, seen.failed_index)
    end)

    it("reconciles a changed exchange without leaving a blank-line ghost", function()
        local model = model_with("thinking", 2)
        tool_folds.reconcile_exchange(buf, win, model, 1)
        vim.cmd("normal! zM")

        local windows = tool_folds.prepare_exchange_update(buf, model, 1)
        vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
        model:replace_span(1, 3, 1, { { kind = "summary", size = 1 } })
        tool_folds.finalize_exchange_update(buf, windows, model, 1)
        vim.cmd("normal! zM")

        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(7, vim.fn.foldclosedend(7))
        assert.equals(-1, vim.fn.foldclosed(8))
        assert.equals(0, vim.fn.foldlevel(8))
    end)

    it("prepares and reconciles the changed exchange in every displayed window", function()
        local model = model_with("thinking", 2)
        local second_win = vim.api.nvim_open_win(buf, false, {
            relative = "editor", row = 1, col = 1, width = 30, height = 8,
            style = "minimal",
        })
        vim.api.nvim_set_option_value("foldmethod", "manual", { win = second_win })
        vim.api.nvim_set_option_value("foldenable", true, { win = second_win })
        tool_folds.reconcile_exchange(buf, win, model, 1)
        tool_folds.reconcile_exchange(buf, second_win, model, 1)

        local windows = tool_folds.prepare_exchange_update(buf, model, 1)
        vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
        model:replace_span(1, 3, 1, { { kind = "summary", size = 1 } })
        tool_folds.finalize_exchange_update(buf, windows, model, 1)

        for _, target in ipairs({ win, second_win }) do
            vim.api.nvim_win_call(target, function()
                vim.cmd("normal! zM")
                assert.equals(7, vim.fn.foldclosed(7))
                assert.equals(7, vim.fn.foldclosedend(7))
                assert.equals(0, vim.fn.foldlevel(8))
            end)
        end
        vim.api.nvim_win_close(second_win, true)
    end)

    it("restores from the current buffer model without masking a mutation error", function()
        local model = model_with("thinking", 2)
        local recovered = model_with("summary", 1)
        tool_folds.reconcile_exchange(buf, win, model, 1)
        local previous_provider = tool_folds._model_provider
        tool_folds._model_provider = function() return recovered end

        local ok, err = pcall(function()
            tool_folds.with_exchange_update(buf, model, 1, function()
                vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
                error("write exploded")
            end)
        end)
        tool_folds._model_provider = previous_provider

        assert.is_false(ok)
        assert.matches("write exploded", err)
        vim.cmd("normal! zM")
        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(7, vim.fn.foldclosedend(7))
        assert.equals(0, vim.fn.foldlevel(8))
    end)

    it("recovers after the model changed without masking the mutation error", function()
        local model = model_with("thinking", 2)
        local recovered = model_with("summary", 1)
        tool_folds.reconcile_exchange(buf, win, model, 1)
        local previous_provider = tool_folds._model_provider
        tool_folds._model_provider = function() return recovered end

        local ok, err = pcall(function()
            tool_folds.with_exchange_update(buf, model, 1, function()
                vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary" })
                model:replace_span(1, 3, 1, { { kind = "summary", size = 1 } })
                error("post-model mutation exploded")
            end)
        end)
        tool_folds._model_provider = previous_provider

        assert.is_false(ok)
        assert.matches("post%-model mutation exploded", err)
        vim.cmd("normal! zM")
        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(7, vim.fn.foldclosedend(7))
        assert.equals(0, vim.fn.foldlevel(8))
    end)

    it("ignores scheduled hydration after its target buffer is deleted", function()
        local scheduled = {}
        local original_schedule = vim.schedule
        vim.schedule = function(callback) scheduled[#scheduled + 1] = callback end
        tool_folds.setup(buf)
        vim.schedule = original_schedule

        vim.api.nvim_buf_delete(buf, { force = true })
        assert.equals(1, #scheduled)
        assert.has_no.errors(scheduled[1])
    end)

    it("hydrates a window only once from one model provider", function()
        local calls = 0
        local model = model_with("thinking", 2)
        local provider = function()
            calls = calls + 1
            return model
        end

        assert.is_true(tool_folds.hydrate_window(buf, win, provider))
        assert.is_false(tool_folds.hydrate_window(buf, win, provider))
        assert.equals(1, calls)
        vim.cmd("normal! zM")
        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(8, vim.fn.foldclosedend(7))
    end)

    it("replaces a persisted orphan fold with the exact initial projection", function()
        vim.api.nvim_buf_set_lines(buf, 6, 8, false, { "📝: summary", "" })
        vim.cmd("8,8fold")
        local model = model_with("summary", 1)

        assert.is_true(tool_folds.hydrate_window(buf, win, function() return model end))
        vim.cmd("normal! zM")

        assert.equals(7, vim.fn.foldclosed(7))
        assert.equals(7, vim.fn.foldclosedend(7))
        assert.equals(0, vim.fn.foldlevel(8))
    end)

    it("does not duplicate live folds when scheduled hydration runs afterward", function()
        -- #200: the model must describe the buffer it folds — verification now
        -- refuses a projection whose anchors are not really there. Give the
        -- appended tool_use block a real 🔧: marker to anchor on.
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "header", "", "💬: q", "", "🤖: a", "",
            "🧠: first", "thinking", "", "🔧: read id=x", "{}",
        })
        local model = model_with("thinking", 2)
        tool_folds.with_exchange_update(buf, model, 1, function()
            model:add_block(1, "tool_use", 2)
        end)

        assert.is_true(tool_folds.hydrate_window(buf, win, function() return model end))
        local ranges = require("parley.fold_projection").desired_folds(model, 1)
        assert.equals(1, vim.fn.foldlevel(ranges[1].start_0 + 1))
        assert.equals(1, vim.fn.foldlevel(ranges[2].start_0 + 1))
        assert.equals(0, vim.fn.foldlevel(ranges[2].end_0 + 2))
    end)

    it("folds recorded item rows when sections and exchanges have no gap", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "---", "topic: gaps", "file: gaps.md", "---", "",
            "💬: first", "", "🤖:[A]", "", "answer", "📝: first summary",
            "💬: second", "", "🤖:[A]", "", "📝: second summary", "",
        })

        tool_folds.apply_folds(buf)
        vim.cmd("normal! zM")

        assert.equals(11, vim.fn.foldclosed(11))
        assert.equals(11, vim.fn.foldclosedend(11))
        assert.equals(16, vim.fn.foldclosed(16))
        assert.equals(16, vim.fn.foldclosedend(16))
        assert.equals(0, vim.fn.foldlevel(17))
    end)

    it("keeps exactly one fold level across consecutive tool-loop appends", function()
        local model = model_with("thinking", 2)
        local second_win = vim.api.nvim_open_win(buf, false, {
            relative = "editor", row = 1, col = 1, width = 30, height = 8,
            style = "minimal",
        })
        vim.api.nvim_set_option_value("foldmethod", "manual", { win = second_win })
        local events = {}
        tool_folds._observer = function(event) events[#events + 1] = event end

        require("parley.tool_loop")._append_section_to_answer(buf, model, 1, {
            kind = "tool_use", name = "read_file", id = "call_1", input = { path = "x" },
        })
        local tool_use = require("parley.fold_projection").desired_folds(model, 1)[2]
        require("parley.tool_loop")._append_section_to_answer(buf, model, 1, {
            kind = "tool_result", name = "read_file", id = "call_1", content = "ok",
        })
        tool_folds._observer = nil

        local ranges = require("parley.fold_projection").desired_folds(model, 1)
        local tool_result = ranges[3]
        assert.equals(8, #events)
        for _, event in ipairs(events) do assert.equals(1, event.exchange_index) end
        for _, target in ipairs({ win, second_win }) do
            vim.api.nvim_win_call(target, function()
                vim.cmd("normal! zM")
                assert.equals(1, vim.fn.foldlevel(tool_use.start_0 + 1))
                assert.equals(1, vim.fn.foldlevel(tool_result.start_0 + 1))
                assert.equals(0, vim.fn.foldlevel(tool_result.end_0 + 2))
            end)
        end
        vim.api.nvim_win_close(second_win, true)
    end)
end)
