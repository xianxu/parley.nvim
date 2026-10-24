-- Lookup uncertainty must refuse native operators and explicit commands.
local parley = require("parley")
local Document = require("parley.document")
local base_tmp_dir = vim.fn.tempname() .. "-tag-refusal"
local seq, buffers = 0, {}
local core = require("parley.skills.review.chat_structure")
local notice = require("parley.review_notice")
local original_snapshot, original_show = core.snapshot, notice.show
local function reset_input()
    pcall(vim.cmd, "stopinsert")
    pcall(vim.cmd, "normal! \27")
end
local function prepped(lines)
    reset_input()
    parley.setup({ chat_dir = base_tmp_dir .. "/chat", state_dir = base_tmp_dir .. "/state",
        providers = {}, api_keys = {} })
    seq = seq + 1
    vim.fn.mkdir(parley.config.chat_dir, "p")
    local path = parley.config.chat_dir .. "/2026-10-23-tag-refusal-" .. seq .. ".md"
    vim.fn.writefile(lines, path)
    vim.cmd("silent edit! " .. vim.fn.fnameescape(path))
    local buf = vim.api.nvim_get_current_buf()
    buffers[#buffers + 1] = buf
    parley.prep_chat(buf, path)
    Document.attach(buf, { schedule = false })
    return buf
end
local function body(buf)
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

describe("review tag lookup refusal", function()
    after_each(function()
        core.snapshot, notice.show = original_snapshot, original_show
        reset_input()
        for index = #buffers, 1, -1 do
            local buf = buffers[index]
            local doc = Document.get(buf)
            if doc then pcall(Document.detach, doc) end
            if vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
        end
        buffers = {}
        vim.fn.delete(base_tmp_dir, "rf")
    end)
    it("refuses unknown tag association visibly without falling through to a native delete", function()
        local lines = { "# topic: tags", "- file: tags.md", "---", "", "💬: q", "🤖: [A]",
            "## Prior", "old", "@@chat@@", "## Tagged", "body", "", "## Next", "tail" }
        local core = require("parley.skills.review.chat_structure")
        local notice = require("parley.review_notice")
        local snapshot, show = core.snapshot, notice.show
        local notices = {}
        local ok, err = pcall(function()
            for _, keys in ipairs({ "dae", "die", "10GVjaed" }) do
                local buf = prepped(lines)
                core.snapshot = function() return nil, "native parser unavailable fixture" end
                notice.show = function(messages, title) notices[#notices + 1] = { messages = messages, title = title } end
                vim.api.nvim_win_set_cursor(0, { 10, 0 })
                vim.cmd("normal " .. keys)
                assert.same(lines, body(buf), keys)
                assert.equals("review: section unavailable", notices[#notices].title)
                assert.same({ "native parser unavailable fixture" }, notices[#notices].messages)
                core.snapshot, notice.show = snapshot, show
            end
            for _, action in ipairs({ { name = "DeleteEntity", row = 10, title = "review: section unavailable" },
                { name = "OpenFileUnderCursor", row = 9, title = "review: tag lookup unavailable" } }) do
                local buf = prepped(lines)
                core.snapshot = function() return nil, "native parser unavailable fixture" end
                notice.show = function(messages, title) notices[#notices + 1] = { messages = messages, title = title } end
                vim.api.nvim_win_set_cursor(0, { action.row, 0 })
                parley.cmd[action.name]()
                assert.equals(buf, vim.api.nvim_get_current_buf(), action.name)
                assert.same(lines, body(buf), action.name)
                assert.equals(action.title, notices[#notices].title)
                assert.same({ "native parser unavailable fixture" }, notices[#notices].messages)
                core.snapshot, notice.show = snapshot, show
            end
        end)
        core.snapshot, notice.show = snapshot, show
        assert.is_true(ok, tostring(err))
    end)

    it("refuses a real overlimit tagged section without changing its source", function()
        local lines = { "# topic: tags", "- file: tags.md", "---", "", "💬: q", "🤖: [A]",
            "@@chat@@", "## Tagged", string.rep("x", 1024 * 1024) }
        local buf = prepped(lines)
        local notice = require("parley.review_notice")
        local show, messages = notice.show, nil
        notice.show = function(value) messages = value end
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local ok, err = pcall(vim.cmd, "normal dae")
        notice.show = show
        assert.is_true(ok, tostring(err))
        assert.is_true(vim.deep_equal(lines, body(buf)), "overlimit source changed")
        assert.is_truthy(messages[1]:find("1 MiB", 1, true))
        notice.show = function(value) messages = value end
        local command_ok, command_err = pcall(function()
            parley.cmd.DeleteEntity()
            assert.is_true(vim.deep_equal(lines, body(buf)), "overlimit command delete changed source")
            assert.is_truthy(messages[1]:find("1 MiB", 1, true))
            vim.api.nvim_win_set_cursor(0, { 7, 0 })
            parley.cmd.OpenFileUnderCursor()
            assert.equals(buf, vim.api.nvim_get_current_buf(), "overlimit tag opened another buffer")
            assert.is_true(vim.deep_equal(lines, body(buf)), "overlimit reference changed source")
            assert.is_truthy(messages[1]:find("1 MiB", 1, true))
        end)
        notice.show = show
        assert.is_true(command_ok, tostring(command_err))
    end)

end)
