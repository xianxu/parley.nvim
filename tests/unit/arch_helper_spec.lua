-- Unit tests for tests/arch/arch_helper.lua
--
-- arch_helper provides architectural fitness functions for the parley
-- codebase. This spec covers the assert_pattern_scoping helper in both
-- literal-string and Lua-pattern modes, with comment skipping and
-- glob/list scope variants.

local arch = require("tests.arch.arch_helper")
local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-arch-" .. os.time()
vim.fn.mkdir(tmp, "p")

local function write(path, lines)
    vim.fn.writefile(lines, tmp .. "/" .. path)
end

describe("arch_helper.assert_pattern_scoping (literal)", function()
    before_each(function()
        vim.fn.delete(tmp, "rf")
        vim.fn.mkdir(tmp, "p")
    end)

    it("passes when pattern is absent from scope", function()
        write("a.lua", { "local x = 1" })
        assert.has_no.errors(function()
            arch.assert_pattern_scoping({
                pattern = "FORBIDDEN",
                scope = { tmp .. "/a.lua" },
                allow_only_in = {},
                rationale = "test rule",
            })
        end)
    end)

    it("fails when pattern appears in a non-allowed file", function()
        write("a.lua", { "FORBIDDEN call" })
        local ok, err = pcall(arch.assert_pattern_scoping, {
            pattern = "FORBIDDEN",
            scope = { tmp .. "/a.lua" },
            allow_only_in = {},
            rationale = "no FORBIDDEN allowed",
        })
        assert.is_false(ok)
        assert.matches("a%.lua:1", err)
        assert.matches("no FORBIDDEN allowed", err)
    end)

    it("passes when pattern appears only in allow_only_in files", function()
        write("a.lua", { "FORBIDDEN call" })
        write("b.lua", { "local x = 1" })
        assert.has_no.errors(function()
            arch.assert_pattern_scoping({
                pattern = "FORBIDDEN",
                scope = { tmp .. "/a.lua", tmp .. "/b.lua" },
                allow_only_in = { tmp .. "/a.lua" },
                rationale = "ok in a only",
            })
        end)
    end)
end)

describe("arch_helper.assert_pattern_scoping (lua pattern + comments)", function()
    before_each(function()
        vim.fn.delete(tmp, "rf")
        vim.fn.mkdir(tmp, "p")
    end)

    it("respects is_pattern = true (Lua pattern matching)", function()
        write("a.lua", { "vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})" })
        local ok = pcall(arch.assert_pattern_scoping, {
            pattern = "vim%.api%.",
            is_pattern = true,
            scope = { tmp .. "/a.lua" },
            allow_only_in = {},
            rationale = "no vim.api in pure files",
        })
        assert.is_false(ok)
    end)

    it("skips lines starting with -- when ignore_comments = true (default)", function()
        write("a.lua", { "-- mention of FORBIDDEN in a comment" })
        assert.has_no.errors(function()
            arch.assert_pattern_scoping({
                pattern = "FORBIDDEN",
                scope = { tmp .. "/a.lua" },
                allow_only_in = {},
                rationale = "comments don't count",
            })
        end)
    end)

    it("does NOT skip comments when ignore_comments = false", function()
        write("a.lua", { "-- mention of FORBIDDEN" })
        local ok = pcall(arch.assert_pattern_scoping, {
            pattern = "FORBIDDEN",
            scope = { tmp .. "/a.lua" },
            allow_only_in = {},
            rationale = "comments count too",
            ignore_comments = false,
        })
        assert.is_false(ok)
    end)

    it("scope can be a glob string", function()
        write("a.lua", { "FORBIDDEN" })
        write("b.lua", { "FORBIDDEN" })
        local ok = pcall(arch.assert_pattern_scoping, {
            pattern = "FORBIDDEN",
            scope = tmp .. "/*.lua",
            allow_only_in = {},
            rationale = "no forbidden",
        })
        assert.is_false(ok)
    end)
end)

-- #261 M1 review BR-6: a file-set guard that lists through the git index is
-- blind to the untracked file being written right now, so a new offender
-- passes until it is staged. Every arch spec lists through
-- arch_helper.worktree_files, or names untracked files explicitly.
describe("arch_helper.worktree_files", function()
    it("lists untracked files, not only the index", function()
        local probe = "lua/parley/zz_worktree_probe_" .. os.time() .. ".lua"
        vim.fn.writefile({ "return {}" }, probe)
        local ok, listed = pcall(arch.worktree_files, { "lua/**/*.lua" })
        vim.fn.delete(probe)
        assert(ok, listed)
        assert.is_true(vim.tbl_contains(listed, probe), "an untracked file was not listed")
    end)

    it("is how every arch spec lists files", function()
        local offenders = {}
        for _, file in ipairs(arch.worktree_files({ "tests/arch/*.lua" })) do
            if file ~= "tests/arch/arch_helper.lua" then
                for n, line in ipairs(vim.fn.readfile(file)) do
                    local index_ls = line:find("git ls-files", 1, true) and not line:find("--others", 1, true)
                    local index_grep = line:find("git grep", 1, true) and not line:find("--untracked", 1, true)
                    if index_ls or index_grep then offenders[#offenders + 1] = file .. ":" .. n end
                end
            end
        end
        assert.same({}, offenders,
            "list files with arch_helper.worktree_files; the git index cannot see an untracked file")
    end)
end)
