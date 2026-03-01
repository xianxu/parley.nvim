-- Integration tests for md module in lua/parley/md.lua
--
-- The md module provides markdown code block manipulation:
-- - copy_markdown_code_block: copies code block content to clipboard
-- - save_markdown_code_block: saves code block to file (when file attr present)
-- - display_diff: error paths (success path opens tabnew which can hang headless)
-- - repeat_last_command: error paths (success path opens terminal)
-- - copy_terminal_output: error paths
--
-- Strategy: Create scratch buffers with known content,
-- set cursor position, and verify behavior.
-- NOTE: Tests avoid functions that call vim.fn.input() or open terminals/tabs,
-- as these hang in headless Neovim.

local parley = require("parley")
parley.setup({
    chat_dir = "/tmp/parley-test-md-" .. os.time(),
    state_dir = "/tmp/parley-test-md-" .. os.time() .. "/state",
    providers = {},
    api_keys = {},
})

local md = require("parley.md")

describe("md", function()
    local buf
    local win

    -- Helper to create a buffer with given content and set cursor
    local function setup_buffer(lines, cursor_line)
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        -- Set the buffer in the current window
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        if cursor_line then
            vim.api.nvim_win_set_cursor(win, { cursor_line, 0 })
        end
    end

    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
    end)

    describe("Group A: copy_markdown_code_block", function()
        it("A1: copies code block content when cursor is inside block", function()
            setup_buffer({
                "Some text",
                "```python",
                "print('hello')",
                "x = 42",
                "```",
                "More text",
            }, 3) -- cursor on "print('hello')"

            md.copy_markdown_code_block()

            local clipboard = vim.fn.getreg("+")
            assert.is_truthy(clipboard:find("print"))
            assert.is_truthy(clipboard:find("x = 42"))
        end)

        it("A2: does not error when cursor is not in a code block", function()
            setup_buffer({
                "Just plain text",
                "No code blocks here",
            }, 1)

            -- Should not error
            local ok = pcall(md.copy_markdown_code_block)
            assert.is_true(ok)
        end)

        it("A3: handles code block with language specifier", function()
            setup_buffer({
                "```lua",
                "return 42",
                "```",
            }, 2)

            md.copy_markdown_code_block()

            local clipboard = vim.fn.getreg("+")
            assert.is_truthy(clipboard:find("return 42"))
        end)

        it("A4: handles code block with single line of content", function()
            setup_buffer({
                "```bash",
                "echo hello",
                "```",
            }, 2)

            md.copy_markdown_code_block()

            local clipboard = vim.fn.getreg("+")
            assert.is_truthy(clipboard:find("echo hello"))
        end)

        it("A5: copies only code between fences, not the fences themselves", function()
            setup_buffer({
                "```python",
                "line1",
                "line2",
                "```",
            }, 2)

            md.copy_markdown_code_block()

            local clipboard = vim.fn.getreg("+")
            assert.is_truthy(clipboard:find("line1"))
            -- Should not contain the ``` markers
            assert.is_falsy(clipboard:find("```"))
        end)

        it("A6: handles multiple code blocks, copies only the one under cursor", function()
            setup_buffer({
                "```lua",
                "first_block",
                "```",
                "",
                "```python",
                "second_block",
                "```",
            }, 6) -- cursor in second block

            md.copy_markdown_code_block()

            local clipboard = vim.fn.getreg("+")
            assert.is_truthy(clipboard:find("second_block"))
            assert.is_falsy(clipboard:find("first_block"))
        end)
    end)

    describe("Group B: save_markdown_code_block", function()
        local tmpdir

        before_each(function()
            local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
            tmpdir = "/tmp/parley-test-md-save-" .. random_suffix
            vim.fn.mkdir(tmpdir, "p")
        end)

        after_each(function()
            if tmpdir then
                vim.fn.delete(tmpdir, "rf")
            end
        end)

        it("B1: saves code block with file attribute to disk", function()
            local filename = "test_output.py"
            setup_buffer({
                '```python file="' .. filename .. '"',
                "print('saved')",
                "```",
            }, 2)

            -- Change cwd to tmpdir temporarily
            local original_cwd = vim.fn.getcwd()
            vim.cmd("cd " .. tmpdir)

            md.save_markdown_code_block()

            vim.cmd("cd " .. original_cwd)

            -- Verify file was created
            local content = vim.fn.readfile(tmpdir .. "/" .. filename)
            assert.is_true(#content > 0)
            assert.is_truthy(table.concat(content, "\n"):find("print"))
        end)

        -- NOTE: Cannot test the "no file attribute" case in headless mode
        -- because save_markdown_code_block calls vim.fn.input() which hangs.
    end)

    describe("Group C: display_diff error paths", function()
        -- NOTE: The success path (C3) opens tabnew + vsplit which can hang
        -- in headless Neovim. Only test error paths here.

        it("C1: does not crash when code block has no filename", function()
            setup_buffer({
                "```python",
                "x = 1",
                "```",
            }, 2)

            local ok = pcall(md.display_diff)
            assert.is_true(ok)
        end)

        it("C2: does not crash when no previous block with same filename exists", function()
            setup_buffer({
                '```python file="test.py"',
                "x = 1",
                "```",
            }, 2)

            local ok = pcall(md.display_diff)
            assert.is_true(ok)
        end)
    end)

    describe("Group D: repeat_last_command error paths", function()
        -- NOTE: The success path opens a terminal which hangs in headless mode.

        it("D1: does not crash when no previous commands exist", function()
            md._last_commands = nil
            md._last_cwd = nil

            local ok = pcall(md.repeat_last_command)
            assert.is_true(ok)
        end)

        it("D2: does not crash when commands list is empty", function()
            md._last_commands = {}
            md._last_cwd = nil

            local ok = pcall(md.repeat_last_command)
            assert.is_true(ok)
        end)
    end)

    describe("Group E: copy_terminal_output error paths", function()
        it("E1: does not crash when no terminal buffer exists", function()
            md._last_term_buf = nil

            local ok = pcall(md.copy_terminal_output)
            assert.is_true(ok)
        end)

        it("E2: does not crash when terminal buffer is invalid", function()
            md._last_term_buf = 99999 -- invalid buffer number

            local ok = pcall(md.copy_terminal_output)
            assert.is_true(ok)
        end)
    end)
end)
