-- Integration tests for the inline term-definition feature (#161).
-- See workshop/issues/000161-inline-term-definition.md and its plan.

describe("emit_definition tool", function()
    before_each(function()
        require("parley.tools").register_builtins()
    end)

    it("is registered and selectable without raising", function()
        local reg = require("parley.tools")
        local ok, sel = pcall(function()
            return reg.select({ "emit_definition" })
        end)
        assert.is_true(ok)
        assert.is_not_nil(sel)
    end)

    it("does not advertise pager offset/limit params", function()
        local def = require("parley.tools.builtin.emit_definition")
        local props = def.input_schema.properties
        assert.is_nil(props.offset)
        assert.is_nil(props.limit)
        assert.is_not_nil(props.term)
        assert.is_not_nil(props.definition)
    end)
end)
