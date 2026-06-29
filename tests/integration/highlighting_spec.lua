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

describe("decoration provider cache", function()
    after_each(function()
        cleanup_extra_windows()
        cleanup_bufs()
    end)

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

        provider.on_win(nil, wins[1], buf, 0, 0)
        provider.on_win(nil, wins[2], buf, 70, 70)

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
        provider.on_win(nil, win, buf, 3, 7)

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

        provider.on_win(nil, win, buf, 0, 5)

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

        provider.on_win(nil, win, buf, 220, 240)

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
