-- Integration tests for M.highlight_question_block
--
-- Verifies that the correct highlight groups are applied to the correct lines
-- in a chat buffer after calling highlight_question_block(buf).
--
-- We query applied highlights via vim.api.nvim_buf_get_extmarks with the
-- parley_question namespace.

local tmp_dir = vim.fn.tempname() .. "-parley-highlight"
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

-- Helper: create a scratch buffer with the given lines and apply highlighting.
local function highlighted_buf(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    parley.highlight_question_block(buf)
    return buf
end

-- Helper: get the highlight group name applied at (0-indexed) row in buf,
-- within the "parley_question" namespace.
-- Returns a table of hl_group strings found on that row.
local function get_highlights_on_line(buf, row)
    local ns = vim.api.nvim_get_namespaces()["parley_question"]
    if not ns then return {} end
    local marks = vim.api.nvim_buf_get_extmarks(buf, ns, { row, 0 }, { row, -1 }, { details = true })
    local groups = {}
    for _, mark in ipairs(marks) do
        local details = mark[4]
        if details and details.hl_group then
            table.insert(groups, details.hl_group)
        end
    end
    return groups
end

-- Helper: check if a specific hl_group is present on a line.
local function has_highlight(buf, row, group)
    local groups = get_highlights_on_line(buf, row)
    for _, g in ipairs(groups) do
        if g == group then return true end
    end
    return false
end

local function cleanup_bufs()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
    end
end

local function cleanup_extra_windows()
    local current = vim.api.nvim_get_current_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if win ~= current and vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, true)
        end
    end
end

local function capture_decoration_provider()
    local original = vim.api.nvim_set_decoration_provider
    local captured_provider = nil

    vim.api.nvim_set_decoration_provider = function(_, provider)
        captured_provider = provider
    end

    parley.setup_buf_handler()
    vim.api.nvim_set_decoration_provider = original

    return captured_provider
end

local function render_window(provider, ...)
    local args = { ... }
    local buf = args[2]
    local highlighter = require("parley.highlighter")
    local cache = highlighter._structure_cache(buf)
    if not cache or cache.dirty then
        local rebuilt, err = highlighter.rebuild_structure(buf)
        assert.is_truthy(rebuilt, err)
    end
    return provider.on_win(nil, unpack(args))
end

describe("highlight_question_block: question lines", function()
    after_each(cleanup_bufs)
    it("applies Question highlight to 💬: line (row 0)", function()
        local buf = highlighted_buf({
            "💬: What is the answer?",
            "🤖:[Agent] 42.",
        })
        assert.is_true(has_highlight(buf, 0, "ParleyQuestion"),
            "Expected 'ParleyQuestion' highlight on 💬: line")
    end)

    it("applies ParleyQuestion highlight to continuation lines of a question block", function()
        local buf = highlighted_buf({
            "💬: First line of question",
            "Continuation of question",
            "🤖:[Agent] Answer here.",
        })
        -- row 0 = question prefix, row 1 = continuation
        assert.is_true(has_highlight(buf, 0, "ParleyQuestion"))
        assert.is_true(has_highlight(buf, 1, "ParleyQuestion"),
            "Expected 'ParleyQuestion' highlight on continuation line")
    end)

    it("does NOT apply ParleyQuestion highlight to 🤖: answer lines", function()
        local buf = highlighted_buf({
            "💬: Question",
            "🤖:[Agent] Answer",
        })
        assert.is_false(has_highlight(buf, 1, "ParleyQuestion"),
            "Answer line should NOT have ParleyQuestion highlight")
    end)
end)

describe("highlight_question_block: thinking lines", function()
    after_each(cleanup_bufs)

    it("applies Think highlight to 📝: summary line", function()
        local buf = highlighted_buf({
            "💬: Question",
            "🤖:[Agent] Answer.",
            "📝: you asked about x, I answered with y",
        })
        assert.is_true(has_highlight(buf, 2, "ParleyThinking"),
            "Expected 'ParleyThinking' highlight on 📝: line")
    end)

    it("applies ParleyThinking highlight to 🧠: reasoning line", function()
        local buf = highlighted_buf({
            "💬: Question",
            "🤖:[Agent] Answer.",
            "🧠: user wants to understand topic",
        })
        assert.is_true(has_highlight(buf, 2, "ParleyThinking"),
            "Expected 'ParleyThinking' highlight on 🧠: line")
    end)
end)

describe("highlight_question_block: file reference lines", function()
    after_each(cleanup_bufs)

    it("applies FileLoading highlight to @@ file reference lines in a question block", function()
        local buf = highlighted_buf({
            "💬: Check this file",
            "@@/path/to/some/file.lua",
            "🤖:[Agent] Done.",
        })
        assert.is_true(has_highlight(buf, 1, "ParleyFileReference"),
            "Expected 'ParleyFileReference' highlight on @@ file reference line")
    end)

    it("does NOT apply ParleyFileReference highlight to @@ lines outside question blocks", function()
        local buf = highlighted_buf({
            "🤖:[Agent] See @@/some/file.lua here",
        })
        -- Row 0 is an answer line; ParleyFileReference should not be applied
        assert.is_false(has_highlight(buf, 0, "ParleyFileReference"),
            "ParleyFileReference should not appear on answer lines")
    end)
end)

describe("highlight_question_block: managed footnote footer", function()
    after_each(cleanup_bufs)

    it("uses a dedicated footnote highlight instead of open-question coloring", function()
        local buf = highlighted_buf({
            "💬: Define ASIN",
            "This question is still open.",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        })

        assert.is_true(has_highlight(buf, 3, "ParleyFootnote"),
            "Expected the managed footnote definition to use ParleyFootnote")
        assert.is_false(has_highlight(buf, 3, "ParleyQuestion"),
            "Managed footnote definition should not inherit open-question color")
    end)
end)

describe("decoration provider cache", function()
    after_each(function()
        cleanup_extra_windows()
        cleanup_bufs()
    end)

    for _, event_name in ipairs({ "BufUnload", "BufDelete" }) do
        it(event_name .. " invalidates LineReader observer state before handle reuse", function()
            capture_decoration_provider()
            local buf = vim.api.nvim_create_buf(false, true)
            local line_reader = require("parley.line_reader")
            local observed = 0
            local token = line_reader.set_observer(buf, function() observed = observed + 1 end)
            line_reader.record_work(buf, { operation = "before_teardown" })
            assert.equals(1, observed)

            vim.api.nvim_exec_autocmds(event_name, { buffer = buf })
            -- The same numeric key models a future Neovim handle reuse. Neither
            -- new work nor a stale token may reconnect to the old observer.
            line_reader.record_work(buf, { operation = "after_handle_reuse" })
            assert.equals(1, observed)
            assert.is_false(line_reader.clear_observer(buf, token))
        end)
    end

    it("keeps highlight caches isolated per window for the same buffer", function()
        local provider = capture_decoration_provider()
        assert.is_table(provider)
        assert.is_function(provider.on_win)
        assert.is_function(provider.on_line)

        local buf = vim.api.nvim_create_buf(false, true)
        local lines = {}
        for i = 1, 120 do
            lines[i] = ("filler line %03d"):format(i)
        end
        lines[1] = "💬: top question"
        lines[71] = "💬: lower question"
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        vim.cmd("vsplit")
        local wins = vim.api.nvim_tabpage_list_wins(0)
        assert.are.same(2, #wins)
        vim.api.nvim_win_set_buf(wins[1], buf)
        vim.api.nvim_win_set_buf(wins[2], buf)

        parley._parley_bufs[buf] = "chat"

        render_window(provider, wins[1], buf, 0, 0)
        render_window(provider, wins[2], buf, 70, 70)

        local original_set_extmark = vim.api.nvim_buf_set_extmark
        local extmarks = {}
        vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
            table.insert(extmarks, {
                row = row,
                hl_group = opts.hl_group,
            })
            return #extmarks
        end

        provider.on_line(nil, wins[1], buf, 0)
        provider.on_line(nil, wins[2], buf, 70)

        vim.api.nvim_buf_set_extmark = original_set_extmark

        local saw_top = false
        local saw_bottom = false
        for _, mark in ipairs(extmarks) do
            if mark.row == 0 and mark.hl_group == "ParleyQuestion" then
                saw_top = true
            end
            if mark.row == 70 and mark.hl_group == "ParleyQuestion" then
                saw_bottom = true
            end
        end

        assert.is_true(saw_top, "expected first split to keep its own viewport highlight cache")
        assert.is_true(saw_bottom, "expected second split to keep its own viewport highlight cache")
    end)

    it("attributes every provider read to decoration_redraw and performs no on_line read", function()
        local provider = capture_decoration_provider()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "💬: question" })
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        parley._parley_bufs[buf] = "chat"

        local line_reader = require("parley.line_reader")
        assert.is_truthy(require("parley.highlighter").rebuild_structure(buf))
        local events = {}
        line_reader.set_observer(buf, function(event) events[#events + 1] = event end)
        provider.on_win(nil, win, buf, 0, 0)
        local reads_after_compute = #events
        provider.on_line(nil, win, buf, 0)

        assert.is_true(reads_after_compute > 0)
        assert.equals(reads_after_compute, #events)
        for _, event in ipairs(events) do
            assert.equals("decoration_redraw", event.phase)
        end
        line_reader.clear_buffer(buf)
    end)

    it("computes a visible non-streaming reasoning opener with the shared phased reader", function()
        local provider = capture_decoration_provider()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "💬: question",
            "🤖:[Agent]",
            "🧠: visible opener",
            "continued reasoning",
            "🧠:[END]",
        })
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        parley._parley_bufs[buf] = "chat"

        local line_reader = require("parley.line_reader")
        assert.is_truthy(require("parley.highlighter").rebuild_structure(buf))
        local events = {}
        line_reader.set_observer(buf, function(event) events[#events + 1] = event end)
        local ok, err = pcall(provider.on_win, nil, win, buf, 2, 2)

        assert.is_true(ok, err)
        assert.is_true(#events > 0)
        for _, event in ipairs(events) do
            assert.equals("decoration_redraw", event.phase)
        end
        line_reader.clear_buffer(buf)
    end)

    it("dims thinking-block continuation lines when viewport top falls between 🧠: and 🧠:[END]", function()
        -- Regression: prior to the buffer-aware lookahead in
        -- reasoning_block_has_end_marker, this case rendered
        -- continuation lines in default color because the slice-based
        -- lookahead couldn't see [END] beyond prefix_lines / visible
        -- window. Symptom: clicking a line "fixed" it because the
        -- viewport scrolled and a different lookahead horizon hit.
        local provider = capture_decoration_provider()
        assert.is_table(provider)
        assert.is_function(provider.on_win)
        assert.is_function(provider.on_line)

        local buf = vim.api.nvim_create_buf(false, true)
        local lines = {
            "💬: question",
            "🤖:[Agent]",
            "🧠: opening line of reasoning",
            "Continuation paragraph one.",
            "",
            "Continuation paragraph two with a blank line above it.",
            "Continuation paragraph three.",
            "🧠:[END]",
            "",
            "Answer body.",
            "📝: summary",
        }
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        parley._parley_bufs[buf] = "chat"

        -- Viewport top sits AFTER 🧠: but BEFORE 🧠:[END]. Continuation
        -- paragraphs (rows 3-6, 0-indexed) and the [END] marker (row 7)
        -- are visible; the 🧠: opener (row 2) is in the bootstrap walk.
        -- toprow=3 (row index of "Continuation paragraph one."), botrow=7.
        render_window(provider, win, buf, 3, 7)

        local original_set_extmark = vim.api.nvim_buf_set_extmark
        local extmarks = {}
        vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
            table.insert(extmarks, { row = row, hl_group = opts.hl_group })
            return #extmarks
        end

        for _, row in ipairs({ 3, 4, 5, 6, 7 }) do
            provider.on_line(nil, win, buf, row)
        end

        vim.api.nvim_buf_set_extmark = original_set_extmark

        local thinking_rows = {}
        for _, mark in ipairs(extmarks) do
            if mark.hl_group == "ParleyThinking" then
                thinking_rows[mark.row] = true
            end
        end

        assert.is_true(thinking_rows[3] == true,
            "continuation paragraph one should be dimmed (ParleyThinking)")
        assert.is_true(thinking_rows[5] == true,
            "continuation paragraph two (after blank line) should be dimmed — explicit-end mode allows blanks inside")
        assert.is_true(thinking_rows[6] == true,
            "continuation paragraph three should be dimmed")
        assert.is_true(thinking_rows[7] == true,
            "🧠:[END] marker should be dimmed (closing delimiter)")
    end)

    it("dims streaming thinking-block continuation lines before 🧠:[END] is emitted", function()
        -- Optimistic-during-streaming: while tasker reports is_busy
        -- for this buffer, the highlighter assumes explicit-end mode
        -- so blank-line paragraph breaks inside the in-progress
        -- reasoning region stay dimmed. After streaming ends, normal
        -- lookahead resumes — legacy single-line 🧠: chats unaffected.
        local provider = capture_decoration_provider()
        assert.is_table(provider)

        local buf = vim.api.nvim_create_buf(false, true)
        -- Mid-stream snapshot: 🧠: opener + a few continuation lines
        -- with a paragraph break, but no 🧠:[END] yet.
        local lines = {
            "💬: question",
            "🤖:[Agent]",
            "🧠: opening line of reasoning",
            "Continuation paragraph one.",
            "",
            "Continuation paragraph two.",
        }
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        parley._parley_bufs[buf] = "chat"

        -- Stub is_busy → true to simulate an in-flight stream for buf.
        local tasker = require("parley.tasker")
        local original_is_busy = tasker.is_busy
        tasker.is_busy = function(b, _) return b == buf end

        render_window(provider, win, buf, 0, 5)

        local original_set_extmark = vim.api.nvim_buf_set_extmark
        local extmarks = {}
        vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
            table.insert(extmarks, { row = row, hl_group = opts.hl_group })
            return #extmarks
        end

        for _, row in ipairs({ 2, 3, 4, 5 }) do
            provider.on_line(nil, win, buf, row)
        end

        vim.api.nvim_buf_set_extmark = original_set_extmark
        tasker.is_busy = original_is_busy

        local thinking_rows = {}
        for _, mark in ipairs(extmarks) do
            if mark.hl_group == "ParleyThinking" then
                thinking_rows[mark.row] = true
            end
        end

        assert.is_true(thinking_rows[2] == true, "🧠: opener should be dimmed")
        assert.is_true(thinking_rows[3] == true, "first continuation should be dimmed mid-stream")
        assert.is_true(thinking_rows[5] == true,
            "continuation after blank line should stay dimmed mid-stream — optimistic explicit-end mode")
    end)


    it("restores question highlights when redraw starts inside a long unanswered question", function()
        local provider = capture_decoration_provider()
        assert.is_table(provider)
        assert.is_function(provider.on_win)
        assert.is_function(provider.on_line)

        local buf = vim.api.nvim_create_buf(false, true)
        local lines = { "💬: long question header" }
        for i = 1, 260 do
            lines[#lines + 1] = ("Question continuation line %03d. Another sentence to keep the row long enough."):format(i)
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        parley._parley_bufs[buf] = "chat"

        render_window(provider, win, buf, 220, 240)

        local original_set_extmark = vim.api.nvim_buf_set_extmark
        local extmarks = {}
        vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
            table.insert(extmarks, {
                row = row,
                hl_group = opts.hl_group,
            })
            return #extmarks
        end

        provider.on_line(nil, win, buf, 220)
        provider.on_line(nil, win, buf, 235)

        vim.api.nvim_buf_set_extmark = original_set_extmark

        local highlighted_rows = {}
        for _, mark in ipairs(extmarks) do
            if mark.hl_group == "ParleyQuestion" then
                highlighted_rows[mark.row] = true
            end
        end

        assert.is_true(highlighted_rows[220] == true,
            "expected question highlight when redraw begins inside a long unanswered question")
        assert.is_true(highlighted_rows[235] == true,
            "expected continuation lines in the viewport to keep question highlight state")
    end)

    it("does identical bounded work for matched 1000 and 5000 line viewports", function()
        local function measure(line_count)
            local provider = capture_decoration_provider()
            local buf = vim.api.nvim_create_buf(false, true)
            local lines = {}
            for row = 1, line_count do lines[row] = ("body %05d"):format(row) end
            lines[1] = "💬: question"
            lines[501] = "🧠: reasoning"
            lines[506] = "🧠:[END]"
            lines[line_count - 2] = "=== draft ==="
            lines[line_count - 1] = "=== end ==="
            lines[line_count] = "[^x]: footer"
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            parley._parley_bufs[buf] = "chat"
            local win = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_buf(win, buf)
            assert.is_truthy(require("parley.highlighter").rebuild_structure(buf))

            local events = {}
            local reader = require("parley.line_reader")
            reader.set_observer(buf, function(event) events[#events + 1] = event end)
            provider.on_win(nil, win, buf, 500, 509)
            assert.equals(1, #events)
            local top, bottom, total = 500, 509, line_count
            assert.are.same({ start_row = top, end_row = math.min(bottom + 1 + 20, total), strict = false },
                events[1].requested)
            assert.equals(30, events[1].lines_requested)
            assert.is_false(events[1].full_buffer)
            -- The exact sole call proves zero preceding-context reads (≤200),
            -- zero reasoning lookahead (≤500/opener), and no footer full-span discovery.

            events = {}
            vim.api.nvim_buf_set_lines(buf, 503, 504, false, { "ordinary changed prose" })
            local total_rows = 0
            local full_reads = 0
            for _, event in ipairs(events) do
                total_rows = total_rows + event.structure_rows_processed
                if event.full_buffer then full_reads = full_reads + 1 end
            end
            assert.equals(1, total_rows)
            assert.equals(0, full_reads)
            assert.is_true(require("parley.highlighter")._structure_cache(buf).renderable)
            return { requested = 30, structure_rows = total_rows }
        end

        assert.are.same(measure(1000), measure(5000))
    end)

    it("recomputes after scroll", function()
        local provider = capture_decoration_provider()
        local buf = vim.api.nvim_create_buf(false, true)
        local lines = {}
        for row = 1, 300 do lines[row] = ("body %03d"):format(row) end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        parley._parley_bufs[buf] = "chat"
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        assert.is_truthy(require("parley.highlighter").rebuild_structure(buf))
        local events = {}
        require("parley.line_reader").set_observer(buf, function(event) events[#events + 1] = event end)
        provider.on_win(nil, win, buf, 0, 9)
        provider.on_win(nil, win, buf, 100, 109)
        assert.equals(2, #events)
        assert.same({ start_row = 0, end_row = 30, strict = false }, events[1].requested)
        assert.same({ start_row = 100, end_row = 130, strict = false }, events[2].requested)
        assert.equals(30, events[2].lines_requested)
    end)

    it("marks structural edits dirty until lifecycle convergence rebuilds", function()
        local provider = capture_decoration_provider()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "💬: q", "body", "🤖: a" })
        parley._parley_bufs[buf] = "chat"
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        require("parley.buffer_lifecycle").setup(buf)
        vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "🧠: changed marker" })
        local cache = require("parley.highlighter")._structure_cache(buf)
        assert.is_true(cache.dirty)
        assert.is_false(provider.on_win(nil, win, buf, 0, 2))

        require("parley.buffer_lifecycle").converge(buf, "InsertLeave")
        cache = require("parley.highlighter")._structure_cache(buf)
        assert.is_false(cache.dirty)
        assert.is_true(cache.renderable)
        assert.is_nil(provider.on_win(nil, win, buf, 0, 2))
    end)

    it("keeps an unfinished reasoning paragraph busy only while streaming", function()
        local provider = capture_decoration_provider()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "🤖: answer", "🧠: thought", "", "continued",
        })
        parley._parley_bufs[buf] = "chat"
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        assert.is_truthy(require("parley.highlighter").rebuild_structure(buf))
        local tasker = require("parley.tasker")
        local original = tasker.is_busy
        local busy = true
        tasker.is_busy = function() return busy end
        local original_extmark = vim.api.nvim_buf_set_extmark
        local thinking = {}
        vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
            if opts.hl_group == "ParleyThinking" then thinking[row] = true end
            return 1
        end
        provider.on_win(nil, win, buf, 0, 3)
        provider.on_line(nil, win, buf, 3)
        assert.is_true(thinking[3])
        busy = false
        thinking = {}
        provider.on_win(nil, win, buf, 0, 3)
        provider.on_line(nil, win, buf, 3)
        vim.api.nvim_buf_set_extmark = original_extmark
        tasker.is_busy = original
        -- No mutation or rebuild is needed: busy is a redraw-time overlay.
        assert.is_nil(thinking[3])
        assert.is_false(require("parley.highlighter")._structure_cache(buf).dirty)
    end)

    it("keeps failed rebuilds unrenderable and retries transactionally", function()
        local highlighter = require("parley.highlighter")
        local model = require("parley.highlight_structure")
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "💬: q", "body" })
        parley._parley_bufs[buf] = "chat"
        assert.is_truthy(highlighter.rebuild_structure(buf))
        local prior = highlighter._structure_cache(buf).structure
        vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "🧠: structural replacement" })
        assert.is_true(highlighter._structure_cache(buf).dirty)
        local original = model.build
        model.build = function() error("forced rebuild failure") end
        local rebuilt, err = highlighter.rebuild_structure(buf)
        model.build = original
        assert.is_nil(rebuilt)
        assert.matches("forced rebuild failure", err)
        assert.equals(prior, highlighter._structure_cache(buf).structure)
        assert.is_true(highlighter._structure_cache(buf).dirty)
        assert.is_false(highlighter._structure_cache(buf).renderable)
        assert.is_truthy(highlighter.rebuild_structure(buf))
        assert.is_true(highlighter._structure_cache(buf).renderable)
    end)

    it("rejects an initial failed build and renders only after retry", function()
        local highlighter = require("parley.highlighter")
        local model = require("parley.highlight_structure")
        local provider = capture_decoration_provider()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "body" })
        parley._parley_bufs[buf] = "chat"
        local original = model.build
        model.build = function() error("initial build failure") end
        local rebuilt, err = highlighter.rebuild_structure(buf)
        model.build = original
        assert.is_nil(rebuilt)
        assert.matches("initial build failure", err)
        assert.is_nil(highlighter._structure_cache(buf))
        assert.is_false(provider.on_win(nil, vim.api.nvim_get_current_win(), buf, 0, 0))
        assert.is_truthy(highlighter.rebuild_structure(buf))
    end)

    it("sets up one shared build and attachment across reentry and windows", function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "body" })
        parley._parley_bufs[buf] = "markdown"
        local events = {}
        require("parley.line_reader").set_observer(buf, function(event) events[#events + 1] = event end)
        local lifecycle = require("parley.buffer_lifecycle")
        lifecycle.setup(buf)
        lifecycle.setup(buf)
        local builds = 0
        for _, event in ipairs(events) do
            if event.operation == "structure_build" then builds = builds + 1 end
        end
        assert.equals(1, builds)
        assert.is_true(require("parley.highlighter")._structure_cache(buf).attached)

        lifecycle.clear(buf)
        lifecycle.setup(buf)
        assert.is_true(require("parley.highlighter")._structure_cache(buf).attached)
    end)

    it("makes obsolete attached callbacks no-op after teardown", function()
        local highlighter = require("parley.highlighter")
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "body" })
        parley._parley_bufs[buf] = "chat"
        assert.is_truthy(highlighter.rebuild_structure(buf))
        local callback = highlighter._structure_cache(buf).on_lines
        highlighter.clear_structure(buf)
        assert.is_true(callback(nil, buf, 0, 0, 1, 1))
        assert.is_nil(highlighter._structure_cache(buf))
    end)

    local function real_lifecycle(notifications)
        local handlers = {}
        local highlighter = require("parley.highlighter")
        local lifecycle = require("parley.buffer_lifecycle")._new({
            is_valid = vim.api.nvim_buf_is_valid,
            create_autocmd = function(events, callback)
                for _, event in ipairs(events) do handlers[event] = callback end
            end,
            diagnostics = require("parley.diagnostic_refresh"),
            structure = {
                rebuild = highlighter.rebuild_structure,
                clear = highlighter.clear_structure,
            },
            notify = function(err) notifications[#notifications + 1] = err end,
        })
        return lifecycle, handlers
    end

    local function structural_lifecycle_fixture()
        local highlighter = require("parley.highlighter")
        local lifecycle, handlers = real_lifecycle({})
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "💬: q", "body" })
        parley._parley_bufs[buf] = "chat"
        lifecycle.setup(buf)
        return highlighter, lifecycle, handlers, buf
    end

    it("refreshes a normal completed API leg", function()
        local highlighter, lifecycle, _, buf = structural_lifecycle_fixture()
        vim.api.nvim_buf_set_lines(buf, 2, 2, false, { "🤖: streamed" })
        assert.is_true(highlighter._structure_cache(buf).dirty)
        lifecycle.finalize_mutated_api_leg(buf, true)
        assert.equals(3, #highlighter._structure_cache(buf).structure.fingerprints)
    end)

    local function prepare_undo_fixture()
        local highlighter, lifecycle, handlers, buf = structural_lifecycle_fixture()
        vim.bo[buf].undolevels = vim.bo[buf].undolevels
        vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "🧠: structural" })
        lifecycle.converge(buf, "TextChanged")
        return highlighter, lifecycle, handlers, buf
    end

    it("converges after undo", function()
        local highlighter, lifecycle, _, buf = prepare_undo_fixture()
        vim.api.nvim_buf_call(buf, function() vim.cmd("undo") end)
        assert.is_true(highlighter._structure_cache(buf).dirty)
        lifecycle.converge(buf, "undo")
        local undo_line = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] or ""
        assert.equals(require("parley.highlight_structure").fingerprint(undo_line),
            highlighter._structure_cache(buf).structure.fingerprints[2])
    end)

    it("converges after redo", function()
        local highlighter, lifecycle, _, buf = prepare_undo_fixture()
        vim.api.nvim_buf_call(buf, function() vim.cmd("undo") end)
        lifecycle.converge(buf, "undo")
        vim.api.nvim_buf_call(buf, function() vim.cmd("redo") end)
        assert.is_true(highlighter._structure_cache(buf).dirty)
        lifecycle.converge(buf, "redo")
        local redo_line = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] or ""
        assert.equals(require("parley.highlight_structure").fingerprint(redo_line),
            highlighter._structure_cache(buf).structure.fingerprints[2])
    end)

    it("converges after external edit", function()
        local highlighter, _, handlers, buf = structural_lifecycle_fixture()
        vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "🌿: external" })
        assert.is_true(highlighter._structure_cache(buf).dirty)
        handlers.BufWritePost({ buf = buf, event = "BufWritePost" })
        assert.equals("b", highlighter._structure_cache(buf).structure.fingerprints[2])
    end)

    it("shares structure across a second window", function()
        local _, lifecycle, handlers, buf = structural_lifecycle_fixture()
        lifecycle.setup(buf)
        handlers.BufEnter({ buf = buf, event = "BufEnter" })
        local shared = require("parley.highlighter")._structure_cache(buf).structure
        vim.cmd("vsplit")
        local wins = vim.api.nvim_tabpage_list_wins(0)
        vim.api.nvim_win_set_buf(wins[1], buf)
        vim.api.nvim_win_set_buf(wins[2], buf)
        local provider = capture_decoration_provider()
        provider.on_win(nil, wins[1], buf, 0, 1)
        provider.on_win(nil, wins[2], buf, 0, 1)
        assert.equals(shared, require("parley.highlighter")._structure_cache(buf).structure)
        cleanup_extra_windows()
    end)

    for _, case in ipairs({
        { event = "BufUnload", name = "clears on BufUnload" },
        { event = "BufDelete", name = "clears on BufDelete" },
    }) do
        it(case.name, function()
            local _, lifecycle, handlers, buf = structural_lifecycle_fixture()
            local highlighter = require("parley.highlighter")
            local obsolete = highlighter._structure_cache(buf).on_lines
            handlers[case.event]({ buf = buf, event = case.event })
            assert.is_nil(highlighter._structure_cache(buf))
            assert.is_true(obsolete(nil, buf, 0, 0, 1, 1))
            vim.api.nvim_buf_delete(buf, { force = true })
            assert.has_no.errors(function() handlers[case.event]({ buf = buf, event = case.event }) end)
            assert.has_no.errors(function() lifecycle.converge(buf, "obsolete") end)
        end)
    end

    it("retains one attachment and rebuild after teardown reentry", function()
        for _, event_name in ipairs({ "BufUnload", "BufDelete" }) do
            local lifecycle, handlers = real_lifecycle({})
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "💬: q", "body" })
            parley._parley_bufs[buf] = "chat"
            local line_reader = require("parley.line_reader")
            local builds = 0
            line_reader.set_observer(buf, function(event)
                if event.operation == "structure_build" then builds = builds + 1 end
            end)
            local original_attach = vim.api.nvim_buf_attach
            local attaches = 0
            vim.api.nvim_buf_attach = function(...)
                attaches = attaches + 1
                return original_attach(...)
            end
            lifecycle.setup(buf)
            lifecycle.setup(buf)
            handlers.BufEnter({ buf = buf, event = "BufEnter" })
            handlers.BufEnter({ buf = buf, event = "BufEnter" })
            vim.api.nvim_buf_attach = original_attach
            assert.equals(1, attaches, event_name)
            assert.equals(1, builds, event_name)

            handlers[event_name]({ buf = buf, event = event_name })
            assert.is_nil(require("parley.highlighter")._structure_cache(buf))

            builds = 0
            line_reader.set_observer(buf, function(event)
                if event.operation == "structure_build" then builds = builds + 1 end
            end)
            attaches = 0
            vim.api.nvim_buf_attach = function(...)
                attaches = attaches + 1
                return original_attach(...)
            end
            lifecycle.setup(buf)
            vim.api.nvim_buf_attach = original_attach
            assert.equals(1, attaches, event_name .. " reentry")
            assert.equals(1, builds, event_name .. " reentry")
        end
    end)

    it("retains the prior real cache across lifecycle rebuild failure and swaps on retry", function()
        local notifications = {}
        local lifecycle = real_lifecycle(notifications)
        local highlighter = require("parley.highlighter")
        local model = require("parley.highlight_structure")
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "💬: q", "body" })
        parley._parley_bufs[buf] = "chat"
        lifecycle.setup(buf)
        local prior = highlighter._structure_cache(buf).structure
        vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "🧠: replacement" })
        local original = model.build
        model.build = function() error("integrated candidate failure") end
        local ok, err = pcall(lifecycle.converge, buf, "InsertLeave")
        model.build = original
        assert.is_false(ok)
        assert.matches("integrated candidate failure", err)
        assert.matches("integrated candidate failure", notifications[1])
        assert.equals(prior, highlighter._structure_cache(buf).structure)
        assert.is_true(highlighter._structure_cache(buf).dirty)
        assert.is_false(highlighter._structure_cache(buf).renderable)
        assert.has_no.errors(function() lifecycle.converge(buf, "InsertLeave retry") end)
        assert.is_not.equals(prior, highlighter._structure_cache(buf).structure)
        assert.equals("r", highlighter._structure_cache(buf).structure.fingerprints[2])
    end)
end)

describe("timezone diagnostics", function()
    after_each(function()
        local ok, tz = pcall(require, "parley.timezone_diagnostics")
        if ok and tz.diag_namespace then
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(buf) then
                    pcall(vim.diagnostic.reset, tz.diag_namespace(), buf)
                end
            end
        end
        cleanup_bufs()
    end)

    it("publishes local-time diagnostics in its own namespace and clears stale diagnostics", function()
        local tz = require("parley.timezone_diagnostics")
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "User: meet at 2026-04-18T00:00:00Z",
        })

        tz.refresh_buffer(buf, {
            to_local = function()
                return {
                    year = 2026,
                    month = 4,
                    day = 17,
                    hour = 17,
                    min = 0,
                    sec = 0,
                }
            end,
        })

        local diagnostics = vim.diagnostic.get(buf, { namespace = tz.diag_namespace() })
        assert.equals(1, #diagnostics)
        assert.equals(0, diagnostics[1].lnum)
        assert.equals(14, diagnostics[1].col)
        assert.equals(34, diagnostics[1].end_col)
        assert.equals("parley-timezone", diagnostics[1].source)
        assert.equals("local time: 2026-04-17 17:00:00", diagnostics[1].message)
        local diag_config = vim.diagnostic.config(nil, tz.diag_namespace())
        assert.same({ current_line = true }, diag_config.virtual_lines)
        assert.equals(false, diag_config.virtual_text)

        local skill_ns = require("parley.skill_render").diag_namespace()
        assert.are_not.equal(skill_ns, tz.diag_namespace())

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "💬: meet later" })
        tz.refresh_buffer(buf, {
            to_local = function()
                error("no timestamps remain")
            end,
        })

        assert.equals(0, #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }))
    end)

    it("refreshes diagnostics for registered buffers on text changes", function()
        local tz = require("parley.timezone_diagnostics")
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
        parley._parley_bufs[buf] = "markdown"
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "no timestamp yet" })
        require("parley.buffer_lifecycle").setup(buf)

        vim.cmd("doautocmd TextChanged")
        vim.wait(100, function()
            return #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }) == 0
        end)
        assert.equals(0, #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }))

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "Now 2026-04-18T00:00:00Z",
        })
        vim.cmd("doautocmd TextChanged")
        vim.wait(100, function()
            return #vim.diagnostic.get(buf, { namespace = tz.diag_namespace() }) == 1
        end)

        local diagnostics = vim.diagnostic.get(buf, { namespace = tz.diag_namespace() })
        assert.equals(1, #diagnostics)
        assert.equals(4, diagnostics[1].col)
    end)
end)

describe("markdown footnote diagnostics", function()
    after_each(function()
        local ok, skill_render = pcall(require, "parley.skill_render")
        if ok and skill_render.diag_namespace then
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(buf) then
                    pcall(vim.diagnostic.reset, skill_render.diag_namespace(), buf)
                end
            end
        end
        cleanup_bufs()
    end)

    it("publishes persisted managed footnotes as Parley diagnostics", function()
        local skill_render = require("parley.skill_render")
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "here is ASIN[^asin] in context",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        })

        skill_render.refresh_footnote_diagnostics(buf)

        local diagnostics = vim.diagnostic.get(buf, { namespace = skill_render.diag_namespace() })
        assert.equals(1, #diagnostics)
        assert.equals(0, diagnostics[1].lnum)
        assert.equals(8, diagnostics[1].col)
        assert.equals(19, diagnostics[1].end_col)
        assert.equals("parley-footnote", diagnostics[1].source)
        assert.is_true(diagnostics[1].message:find("ASIN", 1, true) ~= nil)
        assert.is_true(diagnostics[1].message:find("Amazon Standard Identification Number.", 1, true) ~= nil)
    end)

    it("rehydrates the inline term/reference highlight for persisted footnotes", function()
        local skill_render = require("parley.skill_render")
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "Use EC2[^ec2] for virtual machines.",
            "",
            "[^ec2]: EC2 is Elastic Compute Cloud.",
        })

        skill_render.refresh_footnote_diagnostics(buf)

        local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
        local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, { details = true })
        assert.equals(1, #marks)
        assert.equals(0, marks[1][2])
        assert.equals(4, marks[1][3])
        assert.equals(0, marks[1][4].end_row)
        assert.equals(13, marks[1][4].end_col)
        assert.equals("DiffChange", marks[1][4].hl_group)
    end)

    it("rehydrates a multi-word structured footnote anchor highlight", function()
        local skill_render = require("parley.skill_render")
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "We optimize against Advertising Cost of Sales[^acos] in the policy.",
            "",
            [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
        })

        skill_render.refresh_footnote_diagnostics(buf)

        local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
        local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, { details = true })
        assert.equals(1, #marks)
        assert.equals(0, marks[1][2])
        assert.equals(20, marks[1][3])
        assert.equals(0, marks[1][4].end_row)
        assert.equals(52, marks[1][4].end_col)
        assert.equals("DiffChange", marks[1][4].hl_group)
    end)

    it("rehydrates an unstructured slug-derived multi-word footnote anchor highlight", function()
        local skill_render = require("parley.skill_render")
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "Lambda runs serverless functions[^serverless-functions] without servers.",
            "",
            "[^serverless-functions]: Function-as-a-service compute without server management.",
        })

        skill_render.refresh_footnote_diagnostics(buf)

        local hl_ns = vim.api.nvim_get_namespaces().parley_footnote_hl
        local marks = vim.api.nvim_buf_get_extmarks(buf, hl_ns, 0, -1, { details = true })
        assert.equals(1, #marks)
        assert.equals(0, marks[1][2])
        assert.equals(12, marks[1][3])
        assert.equals(0, marks[1][4].end_row)
        assert.equals(55, marks[1][4].end_col)
        assert.equals("DiffChange", marks[1][4].hl_group)
    end)

    it("refreshes footnote diagnostics on markdown text changes without clearing other Parley diagnostics", function()
        local skill_render = require("parley.skill_render")
        local ns = skill_render.diag_namespace()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
        parley._parley_bufs[buf] = "markdown"
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "no footnote yet",
        })
        vim.diagnostic.set(ns, buf, { {
            lnum = 0,
            col = 0,
            message = "review diagnostic",
            severity = vim.diagnostic.severity.INFO,
            source = "parley-skill",
        } })
        require("parley.buffer_lifecycle").setup(buf)

        vim.cmd("doautocmd TextChanged")
        vim.wait(100, function()
            local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
            return #diagnostics == 1 and diagnostics[1].source == "parley-skill"
        end)

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "here is ASIN[^asin] in context",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        })
        vim.cmd("doautocmd TextChanged")
        vim.wait(100, function()
            local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
            return #diagnostics == 2
        end)

        local by_source = {}
        for _, diagnostic in ipairs(vim.diagnostic.get(buf, { namespace = ns })) do
            by_source[diagnostic.source] = diagnostic
        end
        assert.is_not_nil(by_source["parley-skill"])
        assert.is_not_nil(by_source["parley-footnote"])
        assert.equals(8, by_source["parley-footnote"].col)

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "footnote removed" })
        vim.cmd("doautocmd TextChanged")
        vim.wait(100, function()
            local diagnostics = vim.diagnostic.get(buf, { namespace = ns })
            return #diagnostics == 1 and diagnostics[1].source == "parley-skill"
        end)
    end)

    it("renders managed footnote footers with ParleyFootnote in markdown buffers", function()
        local provider = capture_decoration_provider()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "here is ASIN[^asin] in context",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        })
        parley._parley_bufs[buf] = "markdown"

        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        render_window(provider, win, buf, 0, 2)

        local original_set_extmark = vim.api.nvim_buf_set_extmark
        local extmarks = {}
        vim.api.nvim_buf_set_extmark = function(_, _, row, _, opts)
            table.insert(extmarks, { row = row, hl_group = opts.hl_group })
            return #extmarks
        end

        provider.on_line(nil, win, buf, 2)

        vim.api.nvim_buf_set_extmark = original_set_extmark

        local highlighted = {}
        for _, mark in ipairs(extmarks) do
            if mark.hl_group == "ParleyFootnote" then
                highlighted[mark.row] = true
            end
        end
        assert.is_true(highlighted[2], "Expected markdown footnote definition to use ParleyFootnote")
    end)
end)

describe("markdown chat reference rendering", function()
    after_each(function()
        cleanup_extra_windows()
        cleanup_bufs()
    end)

    it("refreshes 🌿: branch lines with the chat topic in markdown buffers", function()
        local chat_path = tmp_dir .. "/2026-03-24.12-34-56.123.md"
        vim.fn.writefile({
            "---",
            "topic: Rendered Topic",
            "file: 2026-03-24.12-34-56.123.md",
            "---",
            "",
            "💬: hi",
            "🤖:[Agent] hello",
        }, chat_path)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "🌿: " .. chat_path .. ": New chat",
        })
        vim.api.nvim_win_set_buf(0, buf)
        parley._parley_bufs[buf] = "markdown"

        parley.highlight_chat_branch_refs(buf)
        vim.wait(700, function()
            local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
            return line == "🌿: " .. chat_path .. ": Rendered Topic"
        end)

        local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
        assert.equals("🌿: " .. chat_path .. ": Rendered Topic", line)
    end)

    it("does not rewrite 🌿: lines pointing to non-chat files in markdown buffers", function()
        local plain_path = tmp_dir .. "/plain-note.md"
        vim.fn.writefile({
            "# Plain note",
            "",
            "topic: not a chat transcript",
        }, plain_path)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "🌿: " .. plain_path .. ": New chat",
        })
        vim.api.nvim_win_set_buf(0, buf)
        parley._parley_bufs[buf] = "markdown"

        parley.highlight_chat_branch_refs(buf)
        vim.wait(700)

        local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
        assert.equals("🌿: " .. plain_path .. ": New chat", line)
    end)

    it("refreshes from the updated topic in an open unsaved chat buffer", function()
        local chat_path = tmp_dir .. "/2026-03-24.12-34-56.456.md"
        vim.fn.writefile({
            "---",
            "topic: New chat",
            "file: 2026-03-24.12-34-56.456.md",
            "---",
            "",
            "💬: hi",
            "🤖:[Agent] hello",
        }, chat_path)

        local chat_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(chat_buf, chat_path)
        vim.api.nvim_buf_set_lines(chat_buf, 0, -1, false, {
            "---",
            "topic: Actual topic",
            "file: 2026-03-24.12-34-56.456.md",
            "---",
            "",
            "💬: hi",
            "🤖:[Agent] hello",
        })

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "🌿: " .. chat_path .. ": New chat",
        })
        vim.api.nvim_win_set_buf(0, buf)
        parley._parley_bufs[buf] = "markdown"

        parley.highlight_chat_branch_refs(buf)
        vim.wait(700, function()
            local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
            return line == "🌿: " .. chat_path .. ": Actual topic"
        end)

        local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
        assert.equals("🌿: " .. chat_path .. ": Actual topic", line)
    end)
end)
