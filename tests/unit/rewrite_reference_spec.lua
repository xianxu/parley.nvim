-- chat_slug.rewrite_reference — read-repair's pure half (#224).
--
-- The one part of the old file-rewriting `_read_repair_reference` worth
-- keeping. Everything else it did (read the file, gsub every line, write it
-- back, force-reload the buffer) went away when the trigger moved to the
-- cursor: repair now edits the line you are looking at, in the buffer.

local rewrite = require("parley.chat_slug").rewrite_reference

describe("chat_slug.rewrite_reference", function()
    it("renames the reference in a 🌿: line", function()
        assert.equals(
            "🌿: 2026-01-01.00-00-00.001_topic.md: Light lag",
            rewrite("🌿: 2026-01-01.00-00-00.001.md: Light lag",
                "2026-01-01.00-00-00.001.md", "2026-01-01.00-00-00.001_topic.md"))
    end)

    it("renames inside an inline [🌿:…](file) link", function()
        assert.equals(
            "see [🌿:child](2026-01-01.00-00-00.001_topic.md) here",
            rewrite("see [🌿:child](2026-01-01.00-00-00.001.md) here",
                "2026-01-01.00-00-00.001.md", "2026-01-01.00-00-00.001_topic.md"))
    end)

    it("returns nil when the name is unchanged", function()
        -- nil is how the caller avoids dirtying a buffer for a no-op.
        assert.is_nil(rewrite("🌿: a.md: T", "a.md", "a.md"))
    end)

    it("returns nil when the reference is not on this line", function()
        assert.is_nil(rewrite("just prose", "a.md", "b.md"))
    end)

    it("does not interpolate a % in the replacement", function()
        -- Lua reads % in a gsub REPLACEMENT as a capture reference. Unescaped,
        -- this either raises or silently produces garbage — the trap that cost
        -- a round in #214.
        local out = rewrite("🌿: a.md: T", "a.md", "100%-sure.md")
        assert.equals("🌿: 100%-sure.md: T", out)
    end)

    it("does not treat the old name as a pattern", function()
        -- `.` in a filename is a Lua pattern wildcard if unescaped, so
        -- "aXmd" would match "a.md".
        assert.is_nil(rewrite("🌿: aXmd: T", "a.md", "b.md"))
    end)

    it("rewrites every occurrence on the line", function()
        assert.equals("a b.md c b.md",
            rewrite("a x.md c x.md", "x.md", "b.md"))
    end)
end)
