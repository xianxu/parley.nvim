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

    it("keeps the caller's SEARCH ORDER when nothing matches exactly, and says so", function()
        -- The caller passes matches in search order — the reference's own
        -- directory first, then the chat roots — and sorts within each
        -- directory. That order is the tie-break, because a `sub/<ts>.md`
        -- reference whose target was renamed must resolve inside `sub/`
        -- (#224 BR-14). Sorting full paths here would hand it whichever root
        -- sorts first, which is what this function used to do.
        local ordered, ambiguous = pick("2026-01-01.00-00-00.001.md", {
            "/root2/sub/2026-01-01.00-00-00.001_renamed.md",   -- reference's own dir
            "/root1/2026-01-01.00-00-00.001_unrelated.md",     -- a chat root
        })
        assert.equals("/root2/sub/2026-01-01.00-00-00.001_renamed.md", ordered[1])
        assert.is_true(ambiguous, "two non-exact matches is still an ambiguity worth reporting")
    end)

    it("does not reorder within what it was given", function()
        -- Determinism is the CALLER's job now (it sorts each directory's hits);
        -- this function must not undo it.
        local given = { "/c/b.md", "/c/a.md", "/c/c.md" }
        assert.same(given, (pick("x.md", given)))
    end)

    it("does NOT prefer the longest name", function()
        -- The old rule's exact failure: two slugged variants, and length wins.
        -- Here the longer name is passed SECOND, so a length rule would move it
        -- to the front and this would go red.
        local ordered = pick("2026-01-01.00-00-00.001.md", {
            "/c/2026-01-01.00-00-00.001_brief.md",
            "/c/2026-01-01.00-00-00.001_a-very-long-wordy-topic-indeed.md",
        })
        assert.equals("/c/2026-01-01.00-00-00.001_brief.md", ordered[1],
            "length must not outrank the order the caller supplied")
    end)

    it("handles the empty case without raising", function()
        local ordered, ambiguous = pick("x.md", {})
        assert.same({}, ordered)
        assert.is_false(ambiguous)
        assert.same({}, (pick("x.md", nil)))
    end)
end)
