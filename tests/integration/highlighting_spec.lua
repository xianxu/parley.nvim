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
