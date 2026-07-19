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

    it("builds initial folds from semantic model blocks without clearing an unrelated fold", function()
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
        assert.equals(25, vim.fn.foldclosed(25))
        assert.equals(26, vim.fn.foldclosedend(25))
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
