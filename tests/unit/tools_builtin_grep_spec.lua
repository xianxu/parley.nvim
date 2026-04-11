-- Tests for lua/parley/tools/builtin/grep.lua

local grep_def = require("parley.tools.builtin.grep")
local handler = grep_def.handler

describe("grep tool", function()
    it("finds matches with a simple pattern", function()
        local r = handler({ pattern = "function M.new", path = "lua/parley" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("exchange_model%.lua"))
    end)

    it("returns path:line: format", function()
        local r = handler({ pattern = "function M.new", path = "lua/parley" })
        assert.is_false(r.is_error)
        -- Should match format like "path:123:line content"
        assert.truthy(r.content:match("[^:]+:%d+:"))
    end)

    it("supports glob filter", function()
        local r = handler({ pattern = "function", path = "lua/parley", glob = "*.lua" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("%.lua:%d+:"))
    end)

    it("returns no matches message for non-matching pattern", function()
        -- Search in a specific small file to avoid matching this test file
        local r = handler({ pattern = "zzz_will_never_match", path = "ARCH.md" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("no matches"))
    end)

    it("returns error for missing pattern", function()
        local r = handler({})
        assert.is_true(r.is_error)
        assert.truthy(r.content:match("missing"))
    end)

    it("case insensitive search works", function()
        local r = handler({ pattern = "FUNCTION M", path = "lua/parley", case_sensitive = false })
        assert.is_false(r.is_error)
        -- Should find matches since case is ignored
        assert.falsy(r.content:match("no matches"))
    end)
end)
