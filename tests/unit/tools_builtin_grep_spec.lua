-- Tests for lua/parley/tools/builtin/grep.lua

local grep_def = require("parley.tools.builtin.grep")
local handler = grep_def.handler

describe("grep tool", function()
    it("description advertises available grep version", function()
        assert.truthy(grep_def.description:match("ripgrep") or grep_def.description:match("grep"))
    end)

    it("finds matches with a simple pattern", function()
        local r = handler({ pattern = "function M.new", path = "lua/parley/exchange_model.lua" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("function M.new"))
    end)

    it("supports ripgrep glob filter", function()
        local r = handler({ pattern = "function M", path = "lua/parley", glob = "*.lua" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("%.lua"))
    end)

    it("returns no matches for non-matching pattern", function()
        local r = handler({ pattern = "zzz_will_never_match_anything", path = "ARCH.md" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("no matches"))
    end)

    it("returns error for missing pattern", function()
        local r = handler({})
        assert.is_true(r.is_error)
        assert.truthy(r.content:match("missing"))
    end)

    it("case insensitive search works", function()
        local r = handler({ pattern = "FUNCTION M", path = "lua/parley/exchange_model.lua", ignore_case = true })
        assert.is_false(r.is_error)
        assert.falsy(r.content:match("no matches"))
    end)

    it("defaults missing path to cwd", function()
        local r = handler({ pattern = "Architecture" })
        assert.is_false(r.is_error)
        assert.falsy(r.content:match("missing"))
    end)

    it("rejects shell metacharacters in flags", function()
        local r = handler({ pattern = "x", path = ".", flags = { ";", "echo", "PARLEY_SENTINEL_144" } })
        assert.is_true(r.is_error)
        assert.not_matches("missing.*command", r.content)
        assert.not_matches("PARLEY_SENTINEL_144", r.content)
    end)

    it("treats command substitution in the pattern as data", function()
        local r = handler({ pattern = "$(echo PARLEY_SENTINEL_144)", path = "." })
        assert.is_false(r.is_error)
        assert.not_matches("PARLEY_SENTINEL_144", r.content)
    end)

    it("rejects ripgrep command execution flags", function()
        for _, flag in ipairs({ "--pre", "--pre-glob", "--hostname-bin" }) do
            local r = handler({ pattern = "x", path = ".", flags = { flag, "echo PARLEY_SENTINEL_144" } })
            assert.is_true(r.is_error)
            assert.not_matches("missing.*command", r.content)
            assert.not_matches("PARLEY_SENTINEL_144", r.content)
        end
    end)

    it("rejects ripgrep arbitrary pattern-file flags", function()
        for _, flag in ipairs({ "-f", "--file" }) do
            local r = handler({ pattern = "x", path = ".", flags = { flag, "/etc/passwd" } })
            assert.is_true(r.is_error)
            assert.not_matches("missing.*command", r.content)
        end
    end)

    it("rejects legacy raw command fields", function()
        local r = handler({ pattern = "x", path = ".", command = ". ; echo PARLEY_SENTINEL_144" })
        assert.is_true(r.is_error)
        assert.not_matches("PARLEY_SENTINEL_144", r.content)
    end)
end)
