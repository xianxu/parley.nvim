-- Unit tests for lua/parley/skill_runner.lua — compute_edits and apply_edits

local skill_runner = require("parley.skill_runner")

describe("compute_edits", function()
    it("applies a single edit", function()
        local result = skill_runner.compute_edits(
            "Hello world",
            {{ old_string = "world", new_string = "earth", explain = "changed" }}
        )
        assert.is_true(result.ok)
        assert.equals("Hello earth", result.content)
        assert.equals(1, #result.applied)
        assert.equals("changed", result.applied[1].explain)
    end)

    it("applies multiple edits bottom-up", function()
        local result = skill_runner.compute_edits(
            "aaa bbb ccc",
            {
                { old_string = "aaa", new_string = "AAA", explain = "first" },
                { old_string = "ccc", new_string = "CCC", explain = "third" },
            }
        )
        assert.is_true(result.ok)
        assert.equals("AAA bbb CCC", result.content)
        assert.equals(2, #result.applied)
    end)

    it("handles edits that change length", function()
        local result = skill_runner.compute_edits(
            "short long",
            {{ old_string = "short", new_string = "very very long", explain = "expanded" }}
        )
        assert.is_true(result.ok)
        assert.equals("very very long long", result.content)
    end)

    it("rejects missing old_string", function()
        local result = skill_runner.compute_edits(
            "Hello world",
            {{ old_string = "missing", new_string = "x", explain = "x" }}
        )
        assert.is_false(result.ok)
        assert.truthy(result.msg:find("not found"))
    end)

    it("rejects non-unique old_string", function()
        local result = skill_runner.compute_edits(
            "aa bb aa",
            {{ old_string = "aa", new_string = "cc", explain = "x" }}
        )
        assert.is_false(result.ok)
        assert.truthy(result.msg:find("not unique"))
    end)

    it("rejects invalid edit types", function()
        local result = skill_runner.compute_edits(
            "Hello",
            {{ old_string = 123, new_string = "x", explain = "x" }}
        )
        assert.is_false(result.ok)
        assert.truthy(result.msg:find("missing old_string"))
    end)

    it("handles empty edits list", function()
        local result = skill_runner.compute_edits("Hello", {})
        assert.is_true(result.ok)
        assert.equals("Hello", result.content)
        assert.equals(0, #result.applied)
    end)
end)

describe("apply_edits", function()
    it("reads, edits, and writes a file", function()
        local tmp = vim.fn.tempname()
        local f = io.open(tmp, "w")
        f:write("Hello world")
        f:close()

        local result = skill_runner.apply_edits(tmp, {
            { old_string = "world", new_string = "earth", explain = "test" },
        })
        assert.is_true(result.ok)
        assert.equals(1, #result.applied)

        local rf = io.open(tmp, "r")
        local content = rf:read("*a")
        rf:close()
        os.remove(tmp)
        assert.equals("Hello earth", content)
    end)

    it("returns error for missing file", function()
        local result = skill_runner.apply_edits("/nonexistent/path/file.txt", {
            { old_string = "x", new_string = "y", explain = "z" },
        })
        assert.is_false(result.ok)
        assert.truthy(result.msg:find("cannot open"))
    end)
end)
