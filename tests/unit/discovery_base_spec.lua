-- Unit tests for lua/parley/discovery/base.lua
--
-- The static, parley-shipped descriptor list: the universal types
-- (pensive, prose, continuation) + the parley-native ones the #116
-- source-map audit flagged as NOT datatype docs (chat, note, vision,
-- issue, plan). Pure data; dir-backed globs derived from config keys
-- (ARCH-DRY) rather than literals.

local base = require("parley.discovery.base")
local descriptor = require("parley.discovery.descriptor")

local function by_name(name)
    for _, d in ipairs(base.descriptors) do
        if d.name == name then
            return d
        end
    end
    return nil
end

describe("base.descriptors", function()
    it("is a list whose every entry is a valid descriptor", function()
        assert.is_table(base.descriptors)
        assert.is_true(#base.descriptors > 0)
        for _, d in ipairs(base.descriptors) do
            local ok, err = descriptor.validate(d)
            assert.is_true(ok, "invalid base descriptor '" .. tostring(d.name) .. "': " .. tostring(err))
        end
    end)

    it("every entry has scope = base", function()
        for _, d in ipairs(base.descriptors) do
            assert.are.equal("base", d.scope)
        end
    end)

    it("contains exactly the expected base nouns", function()
        local expected = { "chat", "note", "vision", "issue", "plan", "pensive", "prose", "continuation" }
        for _, name in ipairs(expected) do
            assert.is_not_nil(by_name(name), "missing base noun: " .. name)
        end
        assert.are.equal(#expected, #base.descriptors, "unexpected extra/missing base nouns")
    end)

    it("uses the audit-derived matcher kind per noun", function()
        assert.are.equal("frontmatter_present", by_name("chat").matcher.kind)
        assert.are.equal("file", by_name("chat").matcher.field)

        assert.are.equal("any", by_name("note").matcher.kind)
        assert.are.equal("any", by_name("plan").matcher.kind)
        assert.are.equal("any", by_name("vision").matcher.kind)

        assert.are.equal("filename", by_name("issue").matcher.kind)

        for _, name in ipairs({ "pensive", "prose", "continuation" }) do
            local m = by_name(name).matcher
            assert.are.equal("frontmatter", m.kind)
            assert.are.equal("type", m.field)
            assert.are.equal(name, m.value)
        end
    end)

    it("carries the correct extension per noun (vision → yaml, rest → md)", function()
        for _, d in ipairs(base.descriptors) do
            local want = (d.name == "vision") and "%.yaml$" or "%.md$"
            for _, glob in ipairs(d.locate) do
                assert.matches(want, glob, "wrong extension for " .. d.name .. ": " .. glob)
            end
        end
    end)

    it("derives dir-backed globs from config keys, not literals", function()
        local config = require("parley.config")
        -- issue/vision home in their config dirs; the registry is repo-relative
        -- (RegistryBuilder prefixes repo_root in Task 7).
        assert.matches("^" .. config.issues_dir .. "/", by_name("issue").locate[1])
        assert.matches("^" .. config.vision_dir .. "/", by_name("vision").locate[1])
    end)
end)
