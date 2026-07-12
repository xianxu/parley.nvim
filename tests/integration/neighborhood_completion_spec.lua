local parley = require("parley")
local neighborhood = require("parley.neighborhood")

local tmpdir = vim.fn.tempname() .. "-neighborhood-completion"
local repo = tmpdir .. "/repo"
local repo_chat = repo .. "/workshop/parley"
vim.fn.mkdir(repo_chat, "p")
vim.fn.mkdir(repo .. "/lua/parley", "p")
vim.fn.writefile({ "readme" }, repo .. "/README.md")
vim.fn.writefile({ "-- init" }, repo .. "/lua/parley/init.lua")

parley.setup({
    chat_dir = repo_chat,
    state_dir = tmpdir .. "/state",
    providers = {},
    api_keys = {},
})
parley.config.repo_root = repo
parley.config.repo_chat_dir = "workshop/parley"

local function make_chat()
    local path = repo_chat .. "/2026-06-29.topic.md"
    local lines = {
        "---",
        "topic: Test",
        "file: 2026-06-29.topic.md",
        "model: test-model",
        "provider: openai",
        "---",
        "",
        "💬: open REA",
    }
    vim.fn.writefile(lines, path)
    vim.cmd("edit! " .. vim.fn.fnameescape(path))
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    return buf, path
end

describe("neighborhood completion", function()
    local saved_cmp

    before_each(function()
        saved_cmp = package.loaded.cmp
    end)

    after_each(function()
        parley.config.repo_root = repo
        package.loaded.cmp = saved_cmp
        pcall(vim.cmd, "bwipeout!")
    end)

    it("attaches once to repo markdown and leaves non-repo markdown untouched", function()
        vim.fn.mkdir(repo .. "/docs", "p")
        local path = repo .. "/docs/note.md"
        vim.fn.writefile({ "note" }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        local buf = vim.api.nvim_get_current_buf()
        parley.prep_md(buf)
        assert.is_true(vim.b[buf].parley_completion_attached)
        local policy = vim.b[buf].parley_root_policy
        parley.prep_md(buf)
        assert.same(policy, vim.b[buf].parley_root_policy)

        pcall(vim.cmd, "bwipeout!")
        parley.config.repo_root = nil
        local outside = tmpdir .. "/outside.md"
        vim.fn.writefile({ "outside" }, outside)
        vim.cmd("edit! " .. vim.fn.fnameescape(outside))
        buf = vim.api.nvim_get_current_buf()
        parley.prep_md(buf)
        assert.is_nil(vim.b[buf].parley_completion_attached)
        assert.equals("", vim.bo[buf].completefunc)
    end)

    it("attaches a chat-local completefunc rooted at the neighborhood", function()
        local buf, path = make_chat()

        parley.prep_chat(buf, path)

        assert.equals("v:lua.require'parley.neighborhood'.completefunc", vim.bo[buf].completefunc)

        local readme_items = neighborhood.completefunc(0, "REA")
        assert.same({ "README.md" }, readme_items)

        local lua_items = neighborhood.completefunc(0, "lua/parley/in")
        assert.same({ "lua/parley/init.lua" }, lua_items)
    end)

    it("finds the start column for the current path token", function()
        local buf, path = make_chat()

        parley.prep_chat(buf, path)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "open lua/parley/in" })
        vim.api.nvim_win_set_cursor(0, { 1, #"open lua/parley/in" })

        assert.equals(#"open ", neighborhood.completefunc(1, ""))
    end)

    it("omits escaping and dangling authoritative candidates without fallback", function()
        local first, second, outside = repo .. "/first", repo .. "/second", tmpdir .. "/outside"
        vim.fn.mkdir(first, "p")
        vim.fn.mkdir(second, "p")
        vim.fn.mkdir(outside, "p")
        vim.fn.writefile({ "outside" }, outside .. "/same.md")
        vim.fn.writefile({ "second" }, second .. "/same.md")
        vim.loop.fs_symlink(outside .. "/same.md", first .. "/same.md")
        vim.loop.fs_symlink(outside .. "/missing.md", first .. "/dangling.md")
        local policy = { write_root = first, read_roots = { first, second } }
        assert.same({}, neighborhood.completion_candidates(policy, "same"))
        assert.same({}, neighborhood.completion_candidates(policy, "dangling"))
    end)

    it("configures the policy-backed Parley completion source", function()
        local captured
        local registered
        local setup_count = 0
        local register_count = 0
        package.loaded.cmp = {
            config = {
                sources = function(sources)
                    return sources
                end,
            },
            setup = {
                buffer = function(config)
                    captured = config
                    setup_count = setup_count + 1
                end,
            },
            register_source = function(name, source)
                registered = { name = name, source = source }
                register_count = register_count + 1
            end,
        }

        local buf, path = make_chat()

        parley.prep_chat(buf, path)
        vim.wait(100, function()
            return captured ~= nil
        end)

        assert.is_not_nil(captured)
        assert.same({ "parley_path", "buffer" }, { captured.sources[1].name, captured.sources[2].name })
        assert.equals("parley_path", registered.name)
        local before_repeat = setup_count
        neighborhood.attach_completion(buf)
        vim.wait(20)
        assert.equals(before_repeat, setup_count)
        assert.equals(1, register_count)
        local items
        registered.source:complete({ context = { bufnr = buf, cursor_before_line = "REA" } },
            function(result) items = result end)
        assert.equals("README.md", items[1].word)
    end)
end)
