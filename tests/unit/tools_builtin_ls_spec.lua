-- Tests for lua/parley/tools/builtin/ls.lua

local ls_def = require("parley.tools.builtin.ls")
local handler = ls_def.handler

describe("ls tool", function()
    it("lists a path with a safe flag array", function()
        local r = handler({ path = "lua/parley", flags = { "-l" } })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("config%.lua"))
    end)

    it("accepts compact allowlisted short flags", function()
        local r = handler({ path = "lua/parley", flags = { "-lah" } })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("config%.lua"))
    end)

    it("rejects shell metacharacters in flags", function()
        local r = handler({ path = ".", flags = { "-l; echo PARLEY_SENTINEL_144" } })
        assert.is_true(r.is_error)
        assert.not_matches("missing.*command", r.content)
        assert.not_matches("PARLEY_SENTINEL_144", r.content)
    end)

    it("rejects pipeline-shaped flag fragments", function()
        local r = handler({ path = ".", flags = { "|", "wc" } })
        assert.is_true(r.is_error)
        assert.not_matches("missing.*command", r.content)
    end)

    it("rejects long flags and value forms", function()
        local r = handler({ path = ".", flags = { "--color=always" } })
        assert.is_true(r.is_error)
        assert.not_matches("missing.*command", r.content)
    end)

    it("rejects legacy raw command fields", function()
        local r = handler({ path = ".", command = ". ; echo PARLEY_SENTINEL_144" })
        assert.is_true(r.is_error)
        assert.not_matches("PARLEY_SENTINEL_144", r.content)
    end)
end)
