-- Unit tests for lua/parley/skill_edits.lua
--
-- compute_edits is the single source of the batch-edit transform (salvaged
-- from skill_runner.lua). PURE: validate + apply a list of {old_string,
-- new_string, explain} edits to a content string. The propose_edits tool
-- handler (IO) wraps it; the v1 skill_runner.apply_edits delegates to it.

local skill_edits = require("parley.skill_edits")

describe("skill_edits.compute_edits", function()
    it("applies multiple edits (reverse-position order) and reports them", function()
        local content = "alpha beta gamma"
        local res = skill_edits.compute_edits(content, {
            { old_string = "alpha", new_string = "ALPHA", explain = "upcase a" },
            { old_string = "gamma", new_string = "GAMMA", explain = "upcase g" },
        })
        assert.is_true(res.ok)
        assert.are.equal("ALPHA beta GAMMA", res.content)
        assert.are.equal(2, #res.applied)
        -- each applied edit carries pos + the strings + explanation
        for _, e in ipairs(res.applied) do
            assert.is_number(e.pos)
            assert.is_string(e.old_string)
            assert.is_string(e.new_string)
            assert.is_string(e.explain)
        end
    end)

    it("fails when old_string is not found", function()
        local res = skill_edits.compute_edits("hello world", {
            { old_string = "absent", new_string = "x", explain = "e" },
        })
        assert.is_false(res.ok)
        assert.matches("not found", res.msg)
    end)

    it("fails when old_string is not unique", function()
        local res = skill_edits.compute_edits("ab ab", {
            { old_string = "ab", new_string = "X", explain = "e" },
        })
        assert.is_false(res.ok)
        assert.matches("not unique", res.msg)
    end)

    it("fails when an edit is missing old_string/new_string", function()
        local res = skill_edits.compute_edits("hello", {
            { old_string = "hello", explain = "no new_string" },
        })
        assert.is_false(res.ok)
    end)

    it("does not mutate on failure (atomic)", function()
        -- a valid first edit + a failing second → whole batch rejected
        local res = skill_edits.compute_edits("one two", {
            { old_string = "one", new_string = "1", explain = "ok" },
            { old_string = "absent", new_string = "x", explain = "bad" },
        })
        assert.is_false(res.ok)
        assert.is_nil(res.content)
    end)
end)
