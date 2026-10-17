-- Unit tests for lua/parley/skill_edits.lua
--
-- compute_edits is the single source of the batch-edit transform (salvaged
-- from the deleted skill_runner.lua). PURE: validate + apply a list of
-- {old_string, new_string, explain} edits to a content string. The propose_edits
-- tool handler (IO) is its one caller.

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

-- #369: positions are found against the original content and applied from the
-- back, so two spans that overlap would splice bytes outside either span.
describe("skill_edits.compute_edits overlapping spans", function()
    local function edit(old, new) return { old_string = old, new_string = new, explain = "e" } end
    local function refused(content, edits)
        local res = skill_edits.compute_edits(content, edits)
        assert.is_false(res.ok)
        assert.is_nil(res.content)
        assert.same({}, res.applied)
        assert.matches("overlap", res.msg)
        return res
    end

    it("refuses the #369 reproducer instead of consuming the next heading", function()
        local res = refused("alpha\n# Chat\nsecret", { edit("alpha", "x"), edit("pha", "") })
        assert.matches("edits #1 and #2 overlap", res.msg)
    end)

    -- Strategy: each overlap shape in both batch orders; the message names the
    -- edits by their place in the batch.
    local shapes = {
        { "containment", "abcdef", "bcde", "cd" },
        { "partial overlap", "abcdef", "abcd", "cdef" },
        { "identical spans", "abcdef", "cd", "cd" },
        { "same start", "abcdef", "abc", "abcd" },
    }
    for _, shape in ipairs(shapes) do
        it("refuses " .. shape[1] .. " in either order", function()
            refused(shape[2], { edit(shape[3], "X"), edit(shape[4], "Y") })
            refused(shape[2], { edit(shape[4], "Y"), edit(shape[3], "X") })
        end)
    end

    it("names the overlapping pair among other edits", function()
        local res = refused("one two three", { edit("one", "1"), edit("three", "3"), edit("hree", "") })
        assert.matches("edits #2 and #3 overlap", res.msg)
    end)

    it("still applies adjacent and disjoint spans", function()
        local adjacent = skill_edits.compute_edits("abcdef", { edit("def", "D"), edit("abc", "A") })
        assert.is_true(adjacent.ok)
        assert.equals("AD", adjacent.content)
        local disjoint = skill_edits.compute_edits("alpha\n# Chat\nsecret", { edit("alpha", "x"), edit("secret", "s") })
        assert.is_true(disjoint.ok)
        assert.equals("x\n# Chat\ns", disjoint.content)
    end)
end)
