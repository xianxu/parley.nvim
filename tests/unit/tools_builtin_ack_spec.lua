-- Tests for lua/parley/tools/builtin/ack.lua

local ack_def = require("parley.tools.builtin.ack")
local handler = ack_def.handler

local function require_ack()
    if ack_def.available == false then
        pending("ack is not installed")
    end
end

describe("ack tool", function()
    it("finds matches with structured pattern and path fields", function()
        require_ack()
        local r = handler({ pattern = "function M.new", path = "lua/parley/exchange_model.lua" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("function M.new"))
    end)

    it("rejects legacy raw command fields", function()
        require_ack()
        local r = handler({ pattern = "x", path = ".", command = ". ; echo PARLEY_SENTINEL_144" })
        assert.is_true(r.is_error)
        assert.not_matches("PARLEY_SENTINEL_144", r.content)
    end)

    it("treats command substitution text in the pattern as data", function()
        require_ack()
        local r = handler({ pattern = "$(echo PARLEY_SENTINEL_144)", path = "." })
        assert.is_false(r.is_error)
        assert.not_matches("PARLEY_SENTINEL_144", r.content)
    end)

    it("treats dash-leading patterns as data, not options", function()
        require_ack()
        local r = handler({ pattern = "--files", path = "lua/parley/config.lua" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("no matches"))
    end)

    it("rejects raw flags escape hatch", function()
        require_ack()
        local r = handler({ pattern = "x", path = ".", flags = { "--pager=sh" } })
        assert.is_true(r.is_error)
    end)
end)
