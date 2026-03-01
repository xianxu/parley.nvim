-- Integration tests for M.not_chat in lua/parley/init.lua
--
-- not_chat(buf, file_name) returns nil if the buffer is a valid chat file,
-- or a reason string if it is not.
-- Requires the Neovim runtime (vim.api, vim.fn).

local tmp_dir = vim.fn.tempname() .. "-parley-not-chat"
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

-- Build a minimal valid chat buffer in tmp_dir and return (buf, file_path).
local function make_chat_buf(filename)
    local path = tmp_dir .. "/" .. filename
    local lines = {
        "# topic: Test",
        "- file: " .. filename,
        "- model: test-model",
        "- provider: openai",
        "---",
        "",
        "💬: Hello",
    }
    vim.fn.writefile(lines, path)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, path)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    return buf, path
end

local function cleanup_bufs()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            local listed = vim.api.nvim_get_option_value("buflisted", { buf = buf })
            if not listed then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
    end
end

describe("not_chat: valid chat files", function()
    after_each(cleanup_bufs)
    it("returns nil for a properly formatted chat file in chat_dir", function()
        local buf, path = make_chat_buf("2026-02-28.test.md")
        local result = parley.not_chat(buf, path)
        assert.is_nil(result)
    end)
end)

describe("not_chat: invalid files", function()
    after_each(cleanup_bufs)

    it("returns a reason string for a file outside chat_dir", function()
        local buf = vim.api.nvim_create_buf(false, true)
        local path = "/tmp/some-random-file.lua"
        vim.api.nvim_buf_set_name(buf, path)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "-- just lua" })
        local result = parley.not_chat(buf, path)
        assert.is_string(result)
        assert.is_truthy(#result > 0)
    end)

    it("returns a reason for a file in chat_dir without timestamp format", function()
        local path = tmp_dir .. "/no-timestamp.md"
        local lines = {
            "# topic: Test",
            "- file: no-timestamp.md",
            "- model: test",
            "- provider: openai",
            "---",
            "",
            "💬: hi",
        }
        vim.fn.writefile(lines, path)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, path)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        local result = parley.not_chat(buf, path)
        assert.is_string(result)
    end)

    it("returns a reason for a file that is too short (< 5 lines)", function()
        local path = tmp_dir .. "/2026-02-28.short.md"
        local lines = { "# topic: Short", "---" }
        vim.fn.writefile(lines, path)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, path)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        local result = parley.not_chat(buf, path)
        assert.is_string(result)
    end)

    it("returns a reason for a file missing the topic header", function()
        local path = tmp_dir .. "/2026-02-28.no-topic.md"
        local lines = {
            "not a topic line",
            "- file: 2026-02-28.no-topic.md",
            "- model: test",
            "- provider: openai",
            "---",
            "",
            "💬: hi",
        }
        vim.fn.writefile(lines, path)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, path)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        local result = parley.not_chat(buf, path)
        assert.is_string(result)
    end)

    it("returns a reason for a file missing the file header", function()
        local path = tmp_dir .. "/2026-02-28.no-file-header.md"
        local lines = {
            "# topic: Test",
            "no file header here",
            "- model: test",
            "- provider: openai",
            "---",
            "",
            "💬: hi",
        }
        vim.fn.writefile(lines, path)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, path)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        local result = parley.not_chat(buf, path)
        assert.is_string(result)
    end)
end)
