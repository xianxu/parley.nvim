local primary_dir = vim.fn.tempname() .. "-parley-chat-move-primary"
local secondary_dir = vim.fn.tempname() .. "-parley-chat-move-secondary"
vim.fn.mkdir(primary_dir, "p")
vim.fn.mkdir(secondary_dir, "p")
vim.g.parley_test_mode = true

local parley = require("parley")
parley.setup({
    chat_dir = primary_dir,
    chat_dirs = { secondary_dir },
    state_dir = primary_dir .. "/state",
    providers = {},
    api_keys = {},
})

local function create_chat(filename)
    local path = primary_dir .. "/" .. filename
    local lines = {
        "---",
        "topic: Move Test",
        "file: " .. filename,
        "model: test-model",
        "provider: openai",
        "---",
        "",
        "💬: Hello",
    }
    vim.fn.writefile(lines, path)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, path)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_current_buf(buf)
    return buf, path
end

local function cleanup()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if name:match(vim.pesc(primary_dir)) or name:match(vim.pesc(secondary_dir)) then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
    end
    vim.fn.delete(primary_dir, "rf")
    vim.fn.delete(secondary_dir, "rf")
    vim.fn.mkdir(primary_dir, "p")
    vim.fn.mkdir(secondary_dir, "p")
end

describe("chat move", function()
    after_each(cleanup)

    it("moves the current chat to another registered chat directory", function()
        local buf, old_path = create_chat("2026-03-11-move-test.md")

        parley.cmd.ChatMove({ args = secondary_dir })

        local new_path = secondary_dir .. "/2026-03-11-move-test.md"
        assert.equals(0, vim.fn.filereadable(old_path))
        assert.equals(1, vim.fn.filereadable(new_path))
        assert.equals(vim.fn.resolve(new_path), vim.fn.resolve(vim.api.nvim_buf_get_name(buf)))
        assert.is_nil(parley.not_chat(buf, new_path))
    end)

    it("rejects moving chats to unregistered directories", function()
        local _, old_path = create_chat("2026-03-11-move-invalid.md")
        local target_dir = primary_dir .. "-other"

        local new_path, err = parley.move_chat(old_path, target_dir)

        assert.is_nil(new_path)
        assert.equals("target is not a registered chat directory: " .. target_dir, err)
        assert.equals(1, vim.fn.filereadable(old_path))
    end)
end)
