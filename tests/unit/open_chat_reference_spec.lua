local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-open-chat-reference-" .. os.time()
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

describe("open_chat_reference", function()
    it("opens a wrapped @@chat-file@@ reference at the start of a markdown line", function()
        local chat_path = tmp_dir .. "/2026-03-24.12-34-56.123.md"
        vim.fn.writefile({
            "---",
            "topic: Wrapped Reference",
            "file: 2026-03-24.12-34-56.123.md",
            "---",
            "",
            "💬: hi",
            "🤖:[Agent] hello",
        }, chat_path)

        local opened_path = nil
        local original_open_buf = parley.open_buf
        parley.open_buf = function(path)
            opened_path = path
        end

        local ok = parley.open_chat_reference("@@" .. chat_path .. "@@", 1, false, "@@" .. chat_path .. "@@")

        parley.open_buf = original_open_buf

        assert.is_true(ok)
        assert.equals(chat_path, opened_path)
    end)
end)
