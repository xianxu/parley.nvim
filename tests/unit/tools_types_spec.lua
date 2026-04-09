-- Unit tests for lua/parley/tools/types.lua
--
-- Validators for the three provider-agnostic internal types used by the
-- tool-use loop: ToolDefinition, ToolCall, ToolResult.
--
-- Each validator returns `true` on success, or `(false, err_msg)` on
-- failure. Tests exercise both the happy path and every required-field
-- and type-mismatch rejection case.

local types = require("parley.tools.types")

describe("types.validate_definition", function()
    local function valid()
        return {
            name = "read_file",
            description = "Read a file from the working directory.",
            input_schema = { type = "object" },
            handler = function() end,
        }
    end

    it("accepts a minimal valid definition", function()
        local ok = types.validate_definition(valid())
        assert.is_true(ok)
    end)

    it("rejects non-table input", function()
        local ok, err = types.validate_definition("nope")
        assert.is_false(ok)
        assert.matches("table", err)
    end)

    it("rejects missing name", function()
        local def = valid()
        def.name = nil
        local ok, err = types.validate_definition(def)
        assert.is_false(ok)
        assert.matches("name", err)
    end)

    it("rejects empty string name", function()
        local def = valid()
        def.name = ""
        local ok, err = types.validate_definition(def)
        assert.is_false(ok)
        assert.matches("name", err)
    end)

    it("rejects non-string name", function()
        local def = valid()
        def.name = 42
        local ok, err = types.validate_definition(def)
        assert.is_false(ok)
        assert.matches("name", err)
    end)

    it("rejects missing description", function()
        local def = valid()
        def.description = nil
        local ok, err = types.validate_definition(def)
        assert.is_false(ok)
        assert.matches("description", err)
    end)

    it("rejects empty string description", function()
        local def = valid()
        def.description = ""
        local ok, err = types.validate_definition(def)
        assert.is_false(ok)
        assert.matches("description", err)
    end)

    it("rejects missing input_schema", function()
        local def = valid()
        def.input_schema = nil
        local ok, err = types.validate_definition(def)
        assert.is_false(ok)
        assert.matches("input_schema", err)
    end)

    it("rejects non-table input_schema", function()
        local def = valid()
        def.input_schema = "object"
        local ok, err = types.validate_definition(def)
        assert.is_false(ok)
        assert.matches("input_schema", err)
    end)

    it("rejects missing handler", function()
        local def = valid()
        def.handler = nil
        local ok, err = types.validate_definition(def)
        assert.is_false(ok)
        assert.matches("handler", err)
    end)

    it("rejects non-function handler", function()
        local def = valid()
        def.handler = "function"
        local ok, err = types.validate_definition(def)
        assert.is_false(ok)
        assert.matches("handler", err)
    end)
end)

describe("types.validate_call", function()
    local function valid()
        return {
            id = "toolu_01ABC",
            name = "read_file",
            input = { path = "foo.txt" },
        }
    end

    it("accepts a minimal valid call", function()
        assert.is_true(types.validate_call(valid()))
    end)

    it("accepts a call with empty input table", function()
        local c = valid()
        c.input = {}
        assert.is_true(types.validate_call(c))
    end)

    it("rejects non-table input to validator", function()
        local ok, err = types.validate_call("nope")
        assert.is_false(ok)
        assert.matches("table", err)
    end)

    it("rejects missing id", function()
        local c = valid()
        c.id = nil
        local ok, err = types.validate_call(c)
        assert.is_false(ok)
        assert.matches("id", err)
    end)

    it("rejects empty id", function()
        local c = valid()
        c.id = ""
        local ok, err = types.validate_call(c)
        assert.is_false(ok)
        assert.matches("id", err)
    end)

    it("rejects missing name", function()
        local c = valid()
        c.name = nil
        local ok, err = types.validate_call(c)
        assert.is_false(ok)
        assert.matches("name", err)
    end)

    it("rejects missing input", function()
        local c = valid()
        c.input = nil
        local ok, err = types.validate_call(c)
        assert.is_false(ok)
        assert.matches("input", err)
    end)

    it("rejects non-table input field", function()
        local c = valid()
        c.input = "path"
        local ok, err = types.validate_call(c)
        assert.is_false(ok)
        assert.matches("input", err)
    end)
end)

describe("types.validate_result", function()
    local function valid()
        return {
            id = "toolu_01ABC",
            content = "file contents here",
        }
    end

    it("accepts a result without is_error", function()
        assert.is_true(types.validate_result(valid()))
    end)

    it("accepts a result with is_error = false", function()
        local r = valid()
        r.is_error = false
        assert.is_true(types.validate_result(r))
    end)

    it("accepts a result with is_error = true", function()
        local r = valid()
        r.is_error = true
        assert.is_true(types.validate_result(r))
    end)

    it("accepts empty content string", function()
        local r = valid()
        r.content = ""
        assert.is_true(types.validate_result(r))
    end)

    it("rejects non-table input", function()
        local ok, err = types.validate_result(42)
        assert.is_false(ok)
        assert.matches("table", err)
    end)

    it("rejects missing id", function()
        local r = valid()
        r.id = nil
        local ok, err = types.validate_result(r)
        assert.is_false(ok)
        assert.matches("id", err)
    end)

    it("rejects empty id", function()
        local r = valid()
        r.id = ""
        local ok, err = types.validate_result(r)
        assert.is_false(ok)
        assert.matches("id", err)
    end)

    it("rejects missing content", function()
        local r = valid()
        r.content = nil
        local ok, err = types.validate_result(r)
        assert.is_false(ok)
        assert.matches("content", err)
    end)

    it("rejects non-string content", function()
        local r = valid()
        r.content = { "not", "a", "string" }
        local ok, err = types.validate_result(r)
        assert.is_false(ok)
        assert.matches("content", err)
    end)

    it("rejects non-boolean is_error", function()
        local r = valid()
        r.is_error = "yes"
        local ok, err = types.validate_result(r)
        assert.is_false(ok)
        assert.matches("is_error", err)
    end)
end)
