-- Transcript-derived paths must never reach a shell (#225).
--
-- `vim.fn.expand()` runs backtick commands. A chat buffer holds MODEL OUTPUT,
-- so every path lifted out of one — an @@reference, a 🌿: link, an inline
-- [🌿:…](file) — is attacker-influenced text arriving at a command-execution
-- sink. This was reproduced end-to-end before the fix: a chat line
-- `@@`touch <path>`@@` created the file when <M-o> was pressed on it.
--
-- Each test drives a real entry point and asserts the marker file was NOT
-- created. They fail loudly rather than silently if the guard is removed,
-- because the payload is a real `touch`.

local tmp_dir = vim.fn.tempname() .. "-parley-untrusted"
local chat_dir = tmp_dir .. "/chats"
vim.fn.mkdir(chat_dir, "p")

local parley = require("parley")
local helpers = require("parley.helper")
parley.setup({
    chat_dir = chat_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

local counter = 0
-- Returns (payload, marker_path). The payload is a path-shaped string that
-- creates `marker` if it is ever handed to vim.fn.expand.
local function payload(suffix)
    counter = counter + 1
    local marker = tmp_dir .. "/PWNED-" .. counter
    return "`touch " .. marker .. " && echo /nope`" .. (suffix or ""), marker
end

local function assert_not_executed(marker, what)
    vim.wait(50, function() return vim.fn.filereadable(marker) == 1 end)
    assert.equals(0, vim.fn.filereadable(marker), what .. " executed a shell command")
end

local function write_chat(basename, body)
    local path = chat_dir .. "/" .. basename
    local lines = {
        "---", "topic: T", "file: " .. basename, "model: m", "provider: openai", "---",
        "", "💬: hi", "", "🤖:[A] hello",
    }
    for _, l in ipairs(body or {}) do lines[#lines + 1] = l end
    vim.fn.writefile(lines, path)
    return path
end

describe("helper.expand_path", function()
    it("refuses a path containing a backtick", function()
        local p, marker = payload()
        assert.is_nil(helpers.expand_path(p))
        assert_not_executed(marker, "expand_path")
    end)

    it("still expands the ordinary cases", function()
        assert.equals(vim.fn.expand("~"), helpers.expand_path("~"))
        assert.equals("/tmp/plain.md", helpers.expand_path("/tmp/plain.md"))
    end)

    it("refuses a non-string rather than raising", function()
        assert.is_nil(helpers.expand_path(nil))
        assert.is_nil(helpers.expand_path(42))
    end)
end)

describe("the sinks a transcript path can reach", function()
    it("<M-o> on an @@`cmd`@@ line refuses and does not fall through", function()
        local p, marker = payload()
        local line = "@@" .. p .. "@@"
        local chat = write_chat("2026-09-08.20-00-00.001_atref.md", { "", line })

        vim.cmd("silent! %bwipeout!")
        vim.cmd("edit " .. vim.fn.fnameescape(chat))
        local buf = vim.api.nvim_get_current_buf()
        for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if l == line then vim.api.nvim_win_set_cursor(0, { i, 3 }) end
        end

        local gf_calls = 0
        local real = parley.cmd.ResolveRefOrGotoFile
        parley.cmd.ResolveRefOrGotoFile = function() gf_calls = gf_calls + 1 end
        local ok, err = pcall(parley.cmd.OpenFileUnderCursor)
        parley.cmd.ResolveRefOrGotoFile = real
        assert(ok, err)

        assert_not_executed(marker, "OpenFileUnderCursor")
        -- "failed", not "none": the cursor IS on a reference and we refused it.
        -- Falling through would hide the refusal behind gf.
        assert.equals(0, gf_calls)
    end)

    it("a 🌿: reference line refuses", function()
        local p, marker = payload(".md")
        local line = "🌿: ~/" .. p .. ": Topic"
        local chat = write_chat("2026-09-08.20-00-00.002_branch.md", { "", line })

        vim.cmd("silent! %bwipeout!")
        vim.cmd("edit " .. vim.fn.fnameescape(chat))
        local buf = vim.api.nvim_get_current_buf()
        for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if l == line then vim.api.nvim_win_set_cursor(0, { i, 5 }) end
        end
        pcall(parley.cmd.OpenFileUnderCursor)

        assert_not_executed(marker, "the 🌿: chain")
    end)

    it("resolve_chat_path refuses a ~-prefixed transcript path", function()
        local p, marker = payload(".md")
        parley.resolve_chat_path("~/" .. p, chat_dir)
        assert_not_executed(marker, "resolve_chat_path")
    end)

    -- The @@-content-INCLUSION path (chat_respond), a different consumer of the
    -- same transcript text than the navigation chain above.
    it("the content-inclusion helpers refuse", function()
        local p1, m1 = payload()
        assert.is_false(helpers.is_directory(p1))
        assert_not_executed(m1, "is_directory")

        local p2, m2 = payload(".md")
        assert.is_nil(helpers.read_file_content(p2))
        assert_not_executed(m2, "read_file_content")

        local p3, m3 = payload()
        assert.same({}, helpers.find_files(p3, "*.md", false))
        assert_not_executed(m3, "find_files")

        local p4, m4 = payload()
        helpers.process_directory_pattern(p4 .. "/**/*.md")
        assert_not_executed(m4, "process_directory_pattern")
    end)

    it("prepare_dir refuses rather than creating one", function()
        local p, marker = payload()
        helpers.prepare_dir(p)
        assert_not_executed(marker, "prepare_dir")
    end)
end)
