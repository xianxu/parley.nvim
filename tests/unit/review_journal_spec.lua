-- Unit tests for lua/parley/skills/review/journal.lua — the PURE serialize /
-- parse / diff / drift layer of the self-contained review journal (#133).

local J = require("parley.skills.review.journal")

describe("review.journal", function()
    it("serialize→parse round-trips an entry's machine fields", function()
        local e = {
            round = 1, ts = "2026-06-18T10:00:00", mode = "copy-editing", side = "agent",
            hash = "deadbeef", explains = { "fixed typo" }, diff = "@@ -1 +1 @@\n-a\n+b",
        }
        local parsed = J.parse(J.serialize_entry(e))
        assert.are.equal(1, parsed.entries[1].round)
        assert.are.equal("copy-editing", parsed.entries[1].mode)
        assert.are.equal("agent", parsed.entries[1].side)
        assert.are.equal("deadbeef", parsed.entries[1].hash)
        assert.is_truthy(parsed.entries[1].diff:find("+b", 1, true))
    end)

    it("parses multiple rounds in order", function()
        local t = J.serialize_entry({ round = 1, ts = "t1", mode = "none", side = "human", hash = "h1", diff = "d1" })
            .. J.serialize_entry({ round = 2, ts = "t2", mode = "proofreading", side = "agent", hash = "h2", diff = "d2" })
        local p = J.parse(t)
        assert.are.equal(2, #p.entries)
        assert.are.equal(1, p.entries[1].round)
        assert.are.equal(2, p.entries[2].round)
        assert.are.equal("proofreading", p.entries[2].mode)
    end)

    it("survives a 3-backtick code fence inside the diff (4-backtick journal fence)", function()
        local diff = "@@ -1 +3 @@\n+```lua\n+local x = 1\n+```"
        local p = J.parse(J.serialize_entry({ round = 1, ts = "t", mode = "none", side = "agent", hash = "h", diff = diff }))
        assert.are.equal(1, #p.entries)
        assert.is_truthy(p.entries[1].diff:find("local x = 1", 1, true))
    end)

    it("parses the base snapshot + hash", function()
        local p = J.parse(J.serialize_base("hello\nworld", "basehash"))
        assert.are.equal("hello\nworld", p.base)
        assert.are.equal("basehash", p.base_hash)
    end)

    it("is_drift: false when content matches recorded hash, true when it differs", function()
        local h = J.hash("the canonical content")
        assert.is_false(J.is_drift(h, "the canonical content"))
        assert.is_true(J.is_drift(h, "tampered content"))
    end)

    it("diff produces a unified diff of old→new", function()
        local d = J.diff("line a\n", "line b\n")
        assert.is_truthy(d:find("a", 1, true))
        assert.is_truthy(d:find("b", 1, true))
    end)
end)
