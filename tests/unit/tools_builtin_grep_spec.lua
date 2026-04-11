-- Tests for lua/parley/tools/builtin/grep.lua

local grep_def = require("parley.tools.builtin.grep")
local handler = grep_def.handler

describe("grep tool", function()
    it("description advertises available grep version", function()
        assert.truthy(grep_def.description:match("ripgrep") or grep_def.description:match("grep"))
    end)

    it("finds matches with a simple pattern", function()
        local r = handler({ command = '"function M.new" lua/parley/exchange_model.lua' })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("function M.new"))
    end)

    it("supports ripgrep glob filter", function()
        local r = handler({ command = '--glob "*.lua" "function M" lua/parley' })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("%.lua"))
    end)

    it("returns no matches for non-matching pattern", function()
        local r = handler({ command = '"zzz_will_never_match_anything" ARCH.md' })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("no matches"))
    end)

    it("returns error for missing command", function()
        local r = handler({})
        assert.is_true(r.is_error)
        assert.truthy(r.content:match("missing"))
    end)

    it("case insensitive search works", function()
        local r = handler({ command = '-i "FUNCTION M" lua/parley/exchange_model.lua' })
        assert.is_false(r.is_error)
        assert.falsy(r.content:match("no matches"))
    end)
end)
