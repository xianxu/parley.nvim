-- Unit tests for lua/parley/discovery/matcher.lua
--
-- Matcher is a tagged-union predicate over (path, frontmatter_table)
-- deciding whether a file is an instance of a type. PURE: no IO.
--
-- The discriminator taxonomy (from the #116 source-map audit):
--   frontmatter          — fm[field] == value      (the datatype `type:` docs)
--   frontmatter_present  — fm[field] ~= nil          (chat: header `file:`, no type:)
--   filename             — basename matches pattern  (issue: NNNNNN-*.md)
--   any                  — always true; locate glob alone discriminates

local matcher = require("parley.discovery.matcher")

describe("matcher.match — frontmatter kind", function()
    local m = { kind = "frontmatter", field = "type", value = "pensive" }

    it("matches when fm[field] == value", function()
        assert.is_true(matcher.match(m, "any/path.md", { type = "pensive" }))
    end)

    it("rejects a different value", function()
        assert.is_false(matcher.match(m, "any/path.md", { type = "prose" }))
    end)

    it("rejects an absent field", function()
        assert.is_false(matcher.match(m, "any/path.md", {}))
    end)
end)

describe("matcher.match — frontmatter_present kind", function()
    local m = { kind = "frontmatter_present", field = "file" }

    it("matches when the field is present (any value)", function()
        assert.is_true(matcher.match(m, "chat.md", { file = "x" }))
    end)

    it("rejects when the field is absent", function()
        assert.is_false(matcher.match(m, "chat.md", {}))
    end)
end)

describe("matcher.match — filename kind", function()
    local m = { kind = "filename", pattern = "^%d%d%d%d%d%d%-" }

    it("matches a basename matching the pattern", function()
        assert.is_true(matcher.match(m, "workshop/issues/000128-x.md", {}))
    end)

    it("rejects a basename not matching the pattern", function()
        assert.is_false(matcher.match(m, "notes/foo.md", {}))
    end)

    -- The predicate is basename-only and does NOT distinguish issue from plan;
    -- both share the NNNNNN-slug convention. Disambiguation is the `locate`
    -- glob's job. Invariant: a `filename` matcher is only sound WITHIN its
    -- descriptor's `locate` scope.
    it("also matches a plan basename (issue/plan share the convention)", function()
        assert.is_true(matcher.match(m, "workshop/plans/000116-x-plan.md", {}))
    end)
end)

describe("matcher.match — any kind", function()
    it("is always true", function()
        local m = { kind = "any" }
        assert.is_true(matcher.match(m, "whatever.md", {}))
        assert.is_true(matcher.match(m, "x.yaml", { type = "anything" }))
    end)
end)

describe("matcher.match — malformed matcher", function()
    it("errors on an unknown kind (fail-loud: a malformed matcher is a bug)", function()
        assert.has_error(function()
            matcher.match({ kind = "bogus" }, "x.md", {})
        end)
    end)
end)

describe("matcher.KINDS", function()
    it("exposes the known kinds for validation reuse", function()
        assert.is_table(matcher.KINDS)
        assert.is_true(matcher.KINDS.frontmatter)
        assert.is_true(matcher.KINDS.frontmatter_present)
        assert.is_true(matcher.KINDS.filename)
        assert.is_true(matcher.KINDS.any)
        assert.is_nil(matcher.KINDS.bogus)
    end)
end)
