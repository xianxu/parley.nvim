-- Unit tests for lua/parley/discovery/descriptor.lua
--
-- TypeDescriptor is everything deterministic code needs about one type:
--   { name, label, scope, locate, matcher, blurb }
-- `validate(desc)` returns (true) on success or (false, err) on failure,
-- mirroring the tools/types.lua validator style. Matcher-kind validation
-- delegates to matcher.KINDS (ARCH-DRY — single source of known kinds).

local descriptor = require("parley.discovery.descriptor")

local function valid()
    return {
        name = "pensive",
        label = "Pensive",
        scope = "base",
        locate = { "**/*.md" },
        matcher = { kind = "frontmatter", field = "type", value = "pensive" },
        blurb = "per-topic thinking note; find by `type: pensive`",
    }
end

describe("descriptor.validate", function()
    it("accepts a fully-formed descriptor", function()
        local ok, err = descriptor.validate(valid())
        assert.is_true(ok)
        assert.is_nil(err)
    end)

    it("rejects non-table input", function()
        local ok, err = descriptor.validate("nope")
        assert.is_false(ok)
        assert.matches("table", err)
    end)

    it("rejects a missing name", function()
        local d = valid()
        d.name = nil
        local ok, err = descriptor.validate(d)
        assert.is_false(ok)
        assert.matches("name", err)
    end)

    it("rejects a missing locate", function()
        local d = valid()
        d.locate = nil
        local ok, err = descriptor.validate(d)
        assert.is_false(ok)
        assert.matches("locate", err)
    end)

    it("rejects an empty locate list", function()
        local d = valid()
        d.locate = {}
        local ok, err = descriptor.validate(d)
        assert.is_false(ok)
        assert.matches("locate", err)
    end)

    it("rejects a missing matcher", function()
        local d = valid()
        d.matcher = nil
        local ok, err = descriptor.validate(d)
        assert.is_false(ok)
        assert.matches("matcher", err)
    end)

    it("rejects a scope outside {base, local}", function()
        local d = valid()
        d.scope = "wild"
        local ok, err = descriptor.validate(d)
        assert.is_false(ok)
        assert.matches("scope", err)
    end)

    it("accepts scope = local", function()
        local d = valid()
        d.scope = "local"
        assert.is_true(descriptor.validate(d))
    end)

    it("rejects a matcher whose kind is not in matcher.KINDS", function()
        local d = valid()
        d.matcher = { kind = "bogus" }
        local ok, err = descriptor.validate(d)
        assert.is_false(ok)
        assert.matches("matcher", err)
    end)
end)
