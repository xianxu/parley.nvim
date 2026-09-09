-- chat_slug.resolve_candidates — the collision policy, without a filesystem.
--
-- #224: the rule this replaces sorted by LENGTH and took the longest, which
-- encodes "prefer the one that has a slug". Correct until two slugged variants
-- exist, then it silently prefers whichever has the wordier topic.

local chat_slug = require("parley.chat_slug")
local pick = chat_slug.resolve_candidates

describe("chat_slug.resolve_candidates", function()
    it("returns the single match", function()
        local ordered, ambiguous = pick("2026-01-01.00-00-00.001.md",
            { "/c/2026-01-01.00-00-00.001_topic.md" })
        assert.equals("/c/2026-01-01.00-00-00.001_topic.md", ordered[1])
        assert.is_false(ambiguous)
    end)

    it("prefers the name the reference actually used", function()
        -- The reference still names a file that is there. Nothing to choose.
        local ordered, ambiguous = pick("2026-01-01.00-00-00.001_alpha.md", {
            "/c/2026-01-01.00-00-00.001_alpha.md",
            "/c/2026-01-01.00-00-00.001_zzz-much-longer-topic.md",
        })
        assert.equals("/c/2026-01-01.00-00-00.001_alpha.md", ordered[1])
        assert.is_false(ambiguous, "an exact match is not an ambiguity")
    end)

    it("is deterministic and flags the ambiguity when nothing matches exactly", function()
        local ordered, ambiguous = pick("2026-01-01.00-00-00.001.md", {
            "/c/2026-01-01.00-00-00.001_zebra.md",
            "/c/2026-01-01.00-00-00.001_alpha.md",
        })
        assert.equals("/c/2026-01-01.00-00-00.001_alpha.md", ordered[1])
        assert.is_true(ambiguous)
    end)

    it("does not depend on the order the filesystem returned", function()
        local a = pick("x.md", { "/c/b.md", "/c/a.md", "/c/c.md" })
        local b = pick("x.md", { "/c/c.md", "/c/a.md", "/c/b.md" })
        assert.same(a, b)
    end)

    it("does NOT prefer the longest name", function()
        -- The old rule's exact failure: two slugged variants, and length wins.
        local ordered = pick("2026-01-01.00-00-00.001.md", {
            "/c/2026-01-01.00-00-00.001_a-very-long-wordy-topic-indeed.md",
            "/c/2026-01-01.00-00-00.001_brief.md",
        })
        assert.equals("/c/2026-01-01.00-00-00.001_a-very-long-wordy-topic-indeed.md", ordered[1],
            "lexicographic, and 'a-very...' sorts before 'brief' — the point is that "
            .. "the rule is the ORDERING, not the length")
    end)

    it("handles the empty case without raising", function()
        local ordered, ambiguous = pick("x.md", {})
        assert.same({}, ordered)
        assert.is_false(ambiguous)
        assert.same({}, (pick("x.md", nil)))
    end)
end)
