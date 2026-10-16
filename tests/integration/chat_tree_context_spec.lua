-- #233 over real files: the request context is the chat tree in depth-first
-- order, cut at the exchange being submitted. Files are read from their loaded
-- buffer when there is one, so an unsaved child is seen as the operator sees it.
local tmp_dir = vim.fn.tempname() .. "-parley-chat-tree"
local chat_dir = tmp_dir .. "/chats"
vim.fn.mkdir(chat_dir, "p")

local parley = require("parley")
parley.setup({ chat_dir = chat_dir, state_dir = tmp_dir .. "/state", providers = {}, api_keys = {} })
local chat_respond = require("parley.chat_respond")

local function write_chat(basename, body)
    local path = chat_dir .. "/" .. basename
    local lines = { "---", "topic: T", "file: " .. basename, "model: m", "provider: openai", "---", "" }
    vim.list_extend(lines, body)
    vim.fn.writefile(lines, path)
    return vim.fn.resolve(path)
end

local function parse(path)
    local lines = parley.helpers.chat_lines(path)
    return parley.chat_parser.parse_chat(lines, parley.chat_parser.find_header_end(lines), parley.config)
end

-- The questions of the context for submitting exchange `cut` of `path`.
local function questions(path, cut)
    local parsed = parse(path)
    local sequence = chat_respond._tree_sequence(path, parsed, cut, parsed)
    local out = {}
    for _, item in ipairs(sequence) do out[#out + 1] = vim.trim(item.exchange.question.content) end
    return out, sequence
end

describe("chat context over a real chat tree (#233)", function()
    local root, aside, nested, later
    before_each(function()
        -- root: R1, an inline <M-i> aside in R1's answer, then R2 with a 🌿: branch.
        root = write_chat("2026-10-16.09-00-00.001.md", {
            "💬: R1", "", "🤖:[A]", "answer one, see [🌿:aside](2026-10-16.09-01-00.002.md)", "",
            "💬: R2", "", "🤖:[A]", "answer two", "",
            "🌿: 2026-10-16.09-03-00.004.md: Later", "",
            "💬: R3", "",
        })
        aside = write_chat("2026-10-16.09-01-00.002.md", {
            "🌿: 2026-10-16.09-00-00.001.md: Root", "",
            "💬: A1", "", "🤖:[A]", "aside answer", "",
            "🌿: 2026-10-16.09-02-00.003.md: Nested", "",
        })
        nested = write_chat("2026-10-16.09-02-00.003.md", {
            "🌿: 2026-10-16.09-01-00.002.md: Aside", "",
            "💬: AA1", "", "🤖:[A]", "nested answer", "",
        })
        later = write_chat("2026-10-16.09-03-00.004.md", {
            "🌿: 2026-10-16.09-00-00.001.md: Root", "",
            "💬: L1", "",
        })
    end)
    after_each(function()
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_get_name(b):find(chat_dir, 1, true) then
                vim.api.nvim_buf_delete(b, { force = true })
            end
        end
    end)

    it("sends the aside, and its nested aside, to the next question in the root", function()
        assert.same({ "R1", "A1", "AA1", "R2" }, questions(root, 2))
    end)

    it("gives a later branch every subtree to its left", function()
        assert.same({ "R1", "A1", "AA1", "R2", "L1" }, questions(later, 1))
    end)

    it("sends nothing to the right of the cut", function()
        assert.same({ "R1", "A1" }, questions(aside, 1)) -- not AA1, R2 or the later branch
    end)

    it("reads an unsaved child from its buffer", function()
        vim.cmd("edit " .. vim.fn.fnameescape(aside))
        local buf = vim.api.nvim_get_current_buf()
        local row = vim.fn.search("aside answer")
        vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { "edited, not saved" })
        vim.cmd("buffer #")
        local _, sequence = questions(root, 2)
        local answer = vim.trim(sequence[2].exchange.answer.content)
        assert.equals("edited, not saved", answer)
        assert.equals(nested, sequence[3].file)
    end)
end)
