-- Integration tests for ParleyChatNew / M.cmd.ChatNew
--
-- Verifies that creating a new chat:
-- 1. Creates a file on disk in chat_dir
-- 2. The file has the expected template structure
-- 3. The resulting buffer is loaded

local tmp_dir = vim.fn.tempname() .. "-parley-new-chat"
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

local function cleanup()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if name:match(vim.pesc(tmp_dir)) then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
    end
    local files = vim.fn.glob(tmp_dir .. "/*.md", false, true)
    for _, f in ipairs(files) do
        vim.fn.delete(f)
    end
end

describe("ChatNew", function()
    after_each(cleanup)
    it("creates a .md file in chat_dir", function()
        parley.cmd.ChatNew({})
        -- Give the file system a moment (ChatNew is synchronous for file creation)
        local files = vim.fn.glob(tmp_dir .. "/*.md", false, true)
        assert.is_true(#files >= 1, "expected at least one .md file in chat_dir")
    end)

    it("created file has a timestamp-based name (YYYY-MM-DD format)", function()
        parley.cmd.ChatNew({})
        local files = vim.fn.glob(tmp_dir .. "/*.md", false, true)
        assert.is_true(#files >= 1)
        local basename = vim.fn.fnamemodify(files[#files], ":t")
        assert.is_truthy(basename:match("^%d%d%d%d%-%d%d%-%d%d"), 
            "filename should start with YYYY-MM-DD, got: " .. basename)
    end)

    it("created file contains a 💬: user prefix line", function()
        parley.cmd.ChatNew({})
        local files = vim.fn.glob(tmp_dir .. "/*.md", false, true)
        assert.is_true(#files >= 1)
        local content = table.concat(vim.fn.readfile(files[#files]), "\n")
        assert.is_truthy(content:match("💬:"), "file should contain the user prefix 💬:")
    end)

    it("created file contains a --- separator", function()
        parley.cmd.ChatNew({})
        local files = vim.fn.glob(tmp_dir .. "/*.md", false, true)
        assert.is_true(#files >= 1)
        local content = table.concat(vim.fn.readfile(files[#files]), "\n")
        assert.is_truthy(content:match("^%-%-%-$", 1) or content:match("\n%-%-%-\n"),
            "file should contain a --- separator line")
    end)

    it("created file contains the topic header line", function()
        parley.cmd.ChatNew({})
        local files = vim.fn.glob(tmp_dir .. "/*.md", false, true)
        assert.is_true(#files >= 1)
        local lines = vim.fn.readfile(files[#files])
        assert.is_truthy(lines[1]:match("^# topic:"), 
            "first line should be '# topic: ...', got: " .. tostring(lines[1]))
    end)

    it("created file contains a - file: header line", function()
        parley.cmd.ChatNew({})
        local files = vim.fn.glob(tmp_dir .. "/*.md", false, true)
        assert.is_true(#files >= 1)
        local lines = vim.fn.readfile(files[#files])
        local has_file_header = false
        for _, line in ipairs(lines) do
            if line:match("^%- file:") then
                has_file_header = true
                break
            end
        end
        assert.is_true(has_file_header, "file should contain a '- file:' header line")
    end)

    it("the new chat buffer passes not_chat validation", function()
        parley.cmd.ChatNew({})
        local files = vim.fn.glob(tmp_dir .. "/*.md", false, true)
        assert.is_true(#files >= 1)
        local path = files[#files]
        local resolved_path = vim.fn.resolve(path)
        -- Find the buffer that was opened (resolve both paths to handle symlinks on macOS)
        local chat_buf = nil
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) then
                local buf_name = vim.fn.resolve(vim.api.nvim_buf_get_name(buf))
                if buf_name == resolved_path then
                    chat_buf = buf
                    break
                end
            end
        end
        assert.is_not_nil(chat_buf, "chat buffer should be loaded (looked for: " .. resolved_path .. ")")
        local reason = parley.not_chat(chat_buf, resolved_path)
        assert.is_nil(reason, "not_chat should return nil for new chat, got: " .. tostring(reason))
    end)
end)
