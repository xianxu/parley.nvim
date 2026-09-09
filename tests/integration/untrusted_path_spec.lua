-- Transcript-derived paths must never reach a shell (#225).
--
-- `vim.fn.expand()` runs backtick commands. A chat buffer holds MODEL OUTPUT,
-- so every path lifted out of one — an @@reference, a 🌿: link, an inline
-- [🌿:…](file) — is attacker-influenced text arriving at a command-execution
-- sink. This was reproduced end-to-end before the fix: a chat line
-- `@@`touch <path>`@@` created the file when <M-o> was pressed on it.
--
-- Each test drives a real entry point and asserts three things: the marker file
-- was not created, the call did NOT raise, and the refusal was reported.
--
-- The first version asserted only the marker, inside a bare `pcall`. That
-- oracle cannot tell "refused cleanly" from "the interpreter blew up" — and the
-- guard did in fact crash two callers, which the close review found by running
-- the code (#225 C2). An absent side effect is not evidence of correct
-- behaviour; it is evidence that *something* stopped.

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

-- Drive `fn` with the warning log captured, asserting it neither raised nor
-- executed. Returns the warnings so a caller can check the wording.
local function refuses(fn, marker, what)
    local warnings = {}
    local real = parley.logger.warning
    parley.logger.warning = function(msg) warnings[#warnings + 1] = tostring(msg) end
    local ok, err = pcall(fn)
    parley.logger.warning = real
    assert.is_true(ok, what .. " raised instead of refusing: " .. tostring(err))
    if marker then assert_not_executed(marker, what) end
    return table.concat(warnings, "\n")
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
        local warned = refuses(parley.cmd.OpenFileUnderCursor, marker, "OpenFileUnderCursor")
        parley.cmd.ResolveRefOrGotoFile = real

        assert.is_truthy(warned:match("[Rr]efusing"), "no refusal reported: " .. warned)
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
        local warned = refuses(parley.cmd.OpenFileUnderCursor, marker, "the 🌿: chain")

        -- It degrades to "not found" rather than an explicit refusal: the path
        -- is returned unexpanded, so the ordinary not-found branch reports it.
        -- What matters is that it neither ran nor raised.
        assert.is_truthy(warned:match("not found"), "no diagnostic at all: " .. warned)
    end)

    it("resolve_chat_path refuses a ~-prefixed transcript path, and stays total", function()
        local p, marker = payload(".md")
        local got
        refuses(function() got = parley.resolve_chat_path("~/" .. p, chat_dir) end,
            marker, "resolve_chat_path")
        -- TOTAL: it must still return a string. Returning nil here is what
        -- crashed two callers that index the result (#225 C2).
        assert.equals("string", type(got))
    end)

    it("the 🌿: and inline-link arms return a usable path, not nil", function()
        -- The C2 regression precisely: both arms index resolve_chat_path's
        -- result, so a nil return is a Lua error rather than a warning.
        local p1 = select(1, payload(".md"))
        assert.equals("string", type(parley.resolve_chat_path("~/" .. p1, chat_dir)))
        local p2 = select(1, payload(".md"))
        assert.equals("string", type(parley.resolve_chat_path(p2, chat_dir)))
    end)

    it("the outline tree walk refuses a hostile branch path", function()
        -- The site the round-1 sweep missed: outline.lua had a byte-identical
        -- copy of chat_respond's resolver, reachable from <M-t> (#225 C3).
        local p, marker = payload(".md")
        local basename = "2026-09-08.20-00-00.010_outline.md"
        local path = chat_dir .. "/" .. basename
        vim.fn.writefile({
            "---", "topic: T", "file: " .. basename, "model: m", "provider: openai", "---",
            "", "🌿: ~/" .. p .. ": Child", "", "💬: hi", "", "🤖:[A] hello",
        }, path)
        vim.cmd("silent! %bwipeout!")
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        local buf = vim.api.nvim_get_current_buf()
        local outline = require("parley.outline")

        refuses(function()
            outline._build_tree_outline_items(buf, path, parley.config)
        end, marker, "the outline tree walk")
    end)

    -- The @@-content-INCLUSION path (chat_respond), a different consumer of the
    -- same transcript text than the navigation chain above.
    it("the content-inclusion helpers refuse", function()
        local p1, m1 = payload()
        refuses(function() assert.is_false(helpers.is_directory(p1)) end, m1, "is_directory")

        local p2, m2 = payload(".md")
        refuses(function() assert.is_nil(helpers.read_file_content(p2)) end, m2, "read_file_content")

        local p3, m3 = payload()
        refuses(function() assert.same({}, helpers.find_files(p3, "*.md", false)) end, m3, "find_files")

        local p4, m4 = payload()
        refuses(function() helpers.process_directory_pattern(p4 .. "/**/*.md") end,
            m4, "process_directory_pattern")
    end)

    it("prepare_dir refuses rather than creating one, and returns nil like its siblings", function()
        local p, marker = payload()
        local got
        refuses(function() got = helpers.prepare_dir(p) end, marker, "prepare_dir")
        assert.is_nil(got)
    end)
end)
