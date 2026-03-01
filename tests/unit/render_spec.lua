-- Unit tests for lua/parley/render.lua
-- These tests are pure Lua: no vim API calls, no setup required.

local render = require("parley.render")

describe("render.template_replace", function()
    it("replaces a key with a string value", function()
        local result = render.template_replace("Hello {{name}}!", "{{name}}", "world")
        assert.equals("Hello world!", result)
    end)

    it("replaces all occurrences of a key", function()
        local result = render.template_replace("{{a}} and {{a}}", "{{a}}", "x")
        assert.equals("x and x", result)
    end)

    it("treats nil value as empty string", function()
        local result = render.template_replace("Hello {{name}}!", "{{name}}", nil)
        assert.equals("Hello !", result)
    end)

    it("treats table value as newline-joined string", function()
        local result = render.template_replace("lines: {{v}}", "{{v}}", { "a", "b", "c" })
        assert.equals("lines: a\nb\nc", result)
    end)

    it("does not mangle a literal percent sign in the value", function()
        local result = render.template_replace("val: {{v}}", "{{v}}", "50%")
        assert.equals("val: 50%", result)
    end)

    it("does not mangle a literal percent sign in the template", function()
        local result = render.template_replace("50% done {{v}}", "{{v}}", "now")
        assert.equals("50% done now", result)
    end)

    it("handles key not present in template gracefully", function()
        local result = render.template_replace("no match here", "{{missing}}", "value")
        assert.equals("no match here", result)
    end)

    it("handles empty template string", function()
        local result = render.template_replace("", "{{k}}", "v")
        assert.equals("", result)
    end)

    it("handles empty value string", function()
        local result = render.template_replace("{{k}} end", "{{k}}", "")
        assert.equals(" end", result)
    end)
end)

describe("render.template", function()
    it("replaces multiple keys in one call", function()
        local result = render.template("{{a}} + {{b}} = {{c}}", {
            ["{{a}}"] = "1",
            ["{{b}}"] = "2",
            ["{{c}}"] = "3",
        })
        assert.equals("1 + 2 = 3", result)
    end)

    it("handles an empty key_value_pairs table (no-op)", function()
        local result = render.template("unchanged", {})
        assert.equals("unchanged", result)
    end)

    it("handles table values in pairs", function()
        local result = render.template("items: {{list}}", {
            ["{{list}}"] = { "x", "y" },
        })
        assert.equals("items: x\ny", result)
    end)

    it("leaves keys unreplaced when not present in pairs table", function()
        -- A nil value in a Lua table is absent — the key simply won't be replaced.
        -- This tests that template doesn't crash when given a sparse/empty table.
        local result = render.template("prefix {{v}} suffix", {})
        assert.equals("prefix {{v}} suffix", result)
    end)
end)
