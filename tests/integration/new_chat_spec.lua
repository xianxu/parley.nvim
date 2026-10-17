-- Integration tests for ParleyChatNew / M.cmd.ChatNew
--
-- Verifies that creating a new chat:
-- 1. Creates a file on disk in chat_dir
-- 2. The file has the expected template structure
-- 3. The resulting buffer is loaded

local tmp_dir = vim.fn.tempname() .. "-parley-new-chat"
local secondary_dir = vim.fn.tempname() .. "-parley-new-chat-secondary"
vim.fn.mkdir(tmp_dir, "p")
vim.fn.mkdir(secondary_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    chat_dirs = { secondary_dir },
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
    local secondary_files = vim.fn.glob(secondary_dir .. "/*.md", false, true)
    for _, f in ipairs(secondary_files) do
        vim.fn.delete(f)
    end
end

describe("ChatNew", function()
    local original_template = parley.config.chat_template
    after_each(function()
        parley.config.chat_template = original_template
        cleanup()
    end)
    for _, template_name in ipairs({ "short_chat_template", "chat_template" }) do
        it("declares collaboration in new root and child chats using " .. template_name, function()
            parley.config.chat_template = require("parley.defaults")[template_name]
            local root = parley.new_chat()
            local root_path = vim.api.nvim_buf_get_name(root)
            local child_path = tmp_dir .. "/2026-10-17.01-02-03.004_child.md"
            parley.create_child_chat(child_path, "Child", root, "A question")
            for _, path in ipairs({ root_path, child_path }) do
                local fm = require("parley.frontmatter").parse(vim.fn.readfile(path))
                assert.is_not_nil(fm)
                assert.equals("collaboration", fm.fields["collaboration-mode"])
            end
        end)
    end

    it("opens a legacy chat without adding collaboration metadata", function()
        local path = tmp_dir .. "/2026-10-16.01-02-03.004_legacy.md"
        local original = { "---", "topic: Legacy", "file: " .. vim.fn.fnamemodify(path, ":t"),
            "---", "", "💬: Existing question", "", "🤖: Existing answer" }
        vim.fn.writefile(original, path)
        local buf = parley.open_buf(path)
        assert.is_nil(parley.not_chat(buf, path))
        assert.same(original, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        assert.same(original, vim.fn.readfile(path))
    end)

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

    it("created file starts with front matter and contains topic line", function()
        parley.cmd.ChatNew({})
        local files = vim.fn.glob(tmp_dir .. "/*.md", false, true)
        assert.is_true(#files >= 1)
        local lines = vim.fn.readfile(files[#files])
        assert.equals("---", lines[1], "first line should be front matter opener")
        local has_topic = false
        for i = 1, math.min(#lines, 10) do
            if lines[i]:match("^topic:") then
                has_topic = true
                break
            end
        end
        assert.is_true(has_topic, "front matter should contain 'topic:' line")
    end)

    it("created file contains a file: front matter line", function()
        parley.cmd.ChatNew({})
        local files = vim.fn.glob(tmp_dir .. "/*.md", false, true)
        assert.is_true(#files >= 1)
        local path = files[#files]
        local basename = vim.fn.fnamemodify(path, ":t")
        local lines = vim.fn.readfile(path)
        local file_header = nil
        for _, line in ipairs(lines) do
            if line:match("^file:") then
                file_header = line
                break
            end
        end
        assert.is_not_nil(file_header, "file should contain a 'file:' front matter line")
        assert.equals("file: " .. basename, file_header)
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

    it("creates new chats only in the primary chat_dir when secondary roots are configured", function()
        parley.cmd.ChatNew({})
        local primary_files = vim.fn.glob(tmp_dir .. "/*.md", false, true)
        local secondary_files = vim.fn.glob(secondary_dir .. "/*.md", false, true)
        assert.equals(1, #primary_files)
        assert.equals(0, #secondary_files)
    end)
end)
