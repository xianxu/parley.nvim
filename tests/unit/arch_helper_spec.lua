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
