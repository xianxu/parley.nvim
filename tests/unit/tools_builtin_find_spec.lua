-- Tests for lua/parley/tools/builtin/find.lua

local find_def = require("parley.tools.builtin.find")
local handler = find_def.handler

describe("find tool", function()
    it("finds files by structured name and type fields", function()
        local r = handler({ path = "lua/parley", name = "*.lua", type = "f" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("config%.lua"))
    end)

    it("does not accept a raw flags escape hatch", function()
        local r = handler({ path = ".", flags = { "-exec", "echo", "PARLEY_SENTINEL_144", ";" } })
        assert.is_true(r.is_error)
        assert.not_matches("missing.*command", r.content)
        assert.not_matches("PARLEY_SENTINEL_144", r.content)
    end)

    it("rejects action and write predicates as unknown structured fields", function()
        for _, field in ipairs({ "-exec", "-execdir", "-ok", "-okdir", "-delete", "-fprint", "-fprintf", "-fls" }) do
            local r = handler({ path = ".", [field] = "PARLEY_SENTINEL_144" })
            assert.is_true(r.is_error)
            assert.not_matches("PARLEY_SENTINEL_144", r.content)
        end
    end)

    it("treats command substitution text in name as data", function()
        local r = handler({ path = ".", name = "$(echo PARLEY_SENTINEL_144)" })
        assert.is_false(r.is_error)
        assert.not_matches("PARLEY_SENTINEL_144", r.content)
    end)
end)
