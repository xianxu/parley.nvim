-- Unit tests for lua/parley/skills/review/mode.lua
--
-- A Mode is a review mode parsed from a modes/<name>.md sub-file: YAML
-- frontmatter (behavior flags: scope / deletions / frontier) + a markdown
-- prompt body. mode.parse(content) is PURE — no IO. See issue #133.

local mode = require("parley.skills.review.mode")

describe("review.mode.parse", function()
    it("splits frontmatter flags from body", function()
        local m = mode.parse(table.concat({
            "---",
            "name: developmental",
            "scope: whole-doc",
            "deletions: apply-with-gutter-why",
            "frontier: off",
            "---",
            "You are a developmental editor.",
            "Restructure freely.",
        }, "\n"))
        assert.are.equal("developmental", m.name)
        assert.are.equal("whole-doc", m.scope)
        assert.are.equal("apply-with-gutter-why", m.deletions)
        assert.are.equal("off", m.frontier)
        assert.are.equal("You are a developmental editor.\nRestructure freely.", m.body)
    end)

    it("defaults missing flags (markers-only / propose-strike / on)", function()
        local m = mode.parse("---\nname: x\n---\nbody")
        assert.are.equal("markers-only", m.scope)
        assert.are.equal("propose-strike", m.deletions)
        assert.are.equal("on", m.frontier)
    end)

    it("rejects an unknown flag value", function()
        local m, err = mode.parse("---\nname: x\nscope: sideways\n---\nb")
        assert.is_nil(m)
        assert.is_truthy(err:match("scope"))
    end)

    it("returns error when frontmatter is missing", function()
        local m, err = mode.parse("no frontmatter here")
        assert.is_nil(m)
        assert.is_truthy(err)
    end)

    it("requires a name", function()
        local m, err = mode.parse("---\nscope: whole-doc\n---\nbody")
        assert.is_nil(m)
        assert.is_truthy(err:match("name"))
    end)
end)

describe("review.mode.directives", function()
    it("renders whole-doc + apply-with-gutter-why + frontier off", function()
        local d = mode.directives({ name = "x", scope = "whole-doc", deletions = "apply-with-gutter-why", frontier = "off", body = "" })
        assert.is_truthy(d:lower():find("whole document", 1, true))
        assert.is_truthy(d:lower():find("reason", 1, true))      -- apply-with-gutter-why
        assert.is_falsy(d:lower():find("settled", 1, true))      -- frontier off → no frontier line
    end)

    it("renders markers-only + propose-strike + frontier on", function()
        local d = mode.directives({ name = "x", scope = "markers-only", deletions = "propose-strike", frontier = "on", body = "" })
        assert.is_truthy(d:find("markers", 1, true))             -- markers-only scope
        assert.is_truthy(d:lower():find("strike", 1, true))      -- propose-strike
        assert.is_truthy(d:lower():find("settled", 1, true))     -- frontier on
    end)

    it("renders 'apply' deletions as silent", function()
        local d = mode.directives({ name = "x", scope = "whole-doc", deletions = "apply", frontier = "on", body = "" })
        assert.is_truthy(d:lower():find("silently", 1, true))
    end)
end)
