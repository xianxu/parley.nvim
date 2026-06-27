-- Tests for lua/parley/tools/builtin/chat_history_search.lua

local parley = require("parley")
local chat_history_search = require("parley.tools.builtin.chat_history_search")
local handler = chat_history_search.handler

local function write_file(path, content)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    local fh = assert(io.open(path, "w"))
    fh:write(content)
    fh:close()
end

describe("chat_history_search tool", function()
    local base
    local global_dir
    local repo_dir
    local sibling_dir

    before_each(function()
        base = vim.fn.tempname() .. "-parley-grep-memory"
        global_dir = base .. "/global"
        repo_dir = base .. "/parley.nvim/workshop/parley"
        sibling_dir = base .. "/brain/workshop/parley"

        write_file(global_dir .. "/aws-notes.md",
            "we talked about aws S3 lifecycle policies\nand bucket cors rules\n")
        write_file(repo_dir .. "/agent-design.md",
            "the agent should call chat_history_search\nwhen the user asks about AWS\n")
        write_file(sibling_dir .. "/infra.md",
            "running our pipelines on aws\nwith terraform\n")

        parley._state = {}
        parley.setup({
            chat_dir = global_dir,
            chat_roots = {
                { dir = global_dir, label = "global" },
                { dir = repo_dir, label = "parley.nvim" },  -- explicit label
                { dir = sibling_dir, label = "brain" },
            },
            state_dir = base .. "/state",
            providers = {},
            api_keys = {},
        })
    end)

    after_each(function()
        if base then vim.fn.delete(base, "rf") end
    end)

    it("description is non-empty", function()
        assert.is_string(chat_history_search.description)
        assert.is_true(#chat_history_search.description > 0)
    end)

    it("returns error for missing pattern", function()
        local r = handler({})
        assert.is_true(r.is_error)
        assert.truthy(r.content:match("pattern"))
    end)

    it("finds matches across all chat roots", function()
        local r = handler({ pattern = "aws" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("{global}"), "global root header missing:\n" .. r.content)
        assert.truthy(r.content:match("{parley%.nvim}"), "parley.nvim header missing")
        assert.truthy(r.content:match("{brain}"), "brain root header missing")
    end)

    it("rewrites paths to {repo}/<repo-relative> for /workshop/parley roots", function()
        local r = handler({ pattern = "terraform" })
        assert.is_false(r.is_error)
        -- For repo-style roots, anchor at the repo (parent of /workshop/parley)
        -- so the path renders the full repo-relative path.
        assert.truthy(r.content:match("{brain}/workshop/parley/infra%.md"),
            "expected {brain}/workshop/parley/infra.md prefix, got:\n" .. r.content)
    end)

    it("rewrites paths to {label}/<file> for non-repo roots", function()
        local r = handler({ pattern = "lifecycle" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("{global}/aws%-notes%.md"),
            "expected {global}/aws-notes.md prefix, got:\n" .. r.content)
    end)

    it("returns no-matches sentinel when nothing hits", function()
        local r = handler({ pattern = "zzz_will_never_match_anything" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("no matches"))
    end)

    it("respects the glob filter", function()
        write_file(global_dir .. "/decoy.txt", "aws should not match in txt\n")
        local r = handler({ pattern = "aws", glob = "*.md" })
        assert.is_false(r.is_error)
        assert.falsy(r.content:match("decoy%.txt"),
            "txt file leaked through *.md glob:\n" .. r.content)
    end)

    it("is case-insensitive by default", function()
        local r = handler({ pattern = "AWS" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("{global}") or r.content:match("{parley%.nvim}") or r.content:match("{brain}"))
    end)

    it("rejects injection-shaped numeric fields before process launch", function()
        for _, case in ipairs({
            { field = "before", value = "0; echo PARLEY_SENTINEL_149" },
            { field = "after", value = "$(echo PARLEY_SENTINEL_149)" },
            { field = "max_count", value = "1 | echo PARLEY_SENTINEL_149" },
        }) do
            local input = { pattern = "aws" }
            input[case.field] = case.value

            local r = handler(input)

            assert.is_true(r.is_error, case.field .. " should be rejected")
            assert.truthy(r.content:match(case.field), "error should name " .. case.field .. ": " .. r.content)
            assert.not_matches("PARLEY_SENTINEL_149", r.content)
        end
    end)

    it("rejects non-integer numeric context and count fields", function()
        for _, case in ipairs({
            { field = "before", value = -1 },
            { field = "before", value = 1.5 },
            { field = "after", value = -1 },
            { field = "after", value = 1.5 },
            { field = "max_count", value = -1 },
            { field = "max_count", value = 1.5 },
        }) do
            local input = { pattern = "aws" }
            input[case.field] = case.value

            local r = handler(input)

            assert.is_true(r.is_error, case.field .. " should be rejected")
            assert.truthy(r.content:match(case.field), "error should name " .. case.field .. ": " .. r.content)
        end
    end)

    it("accepts zero context and positive max_count", function()
        local r = handler({ pattern = "aws", before = 0, after = 0, max_count = 1 })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("{global}") or r.content:match("{parley%.nvim}") or r.content:match("{brain}"))
    end)
end)
