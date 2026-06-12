-- Unit tests for lua/parley/discovery/base.lua
--
-- The static, parley-shipped descriptor list: the universal types
-- (pensive, prose, continuation) + the parley-native ones the #116
-- source-map audit flagged as NOT datatype docs (chat, note, vision,
-- issue, plan). Pure data; dir-backed globs derived from config keys
-- (ARCH-DRY) rather than literals.

local base = require("parley.discovery.base")
local descriptor = require("parley.discovery.descriptor")
local config = require("parley.config")

-- base.build(config) is a pure function of the LIVE config (no load-time
-- snapshot), so user overrides of chat_dir/notes_dir reach the descriptors.
local descriptors = base.build(config)

local function by_name(name)
    for _, d in ipairs(descriptors) do
        if d.name == name then
            return d
        end
    end
    return nil
end

describe("base.build", function()
    it("is a list whose every entry is a valid descriptor", function()
        assert.is_table(descriptors)
        assert.is_true(#descriptors > 0)
        for _, d in ipairs(descriptors) do
            local ok, err = descriptor.validate(d)
            assert.is_true(ok, "invalid base descriptor '" .. tostring(d.name) .. "': " .. tostring(err))
        end
    end)

    it("every entry has scope = base", function()
        for _, d in ipairs(descriptors) do
            assert.are.equal("base", d.scope)
        end
    end)

    it("contains exactly the expected base nouns", function()
        local expected = { "chat", "note", "vision", "issue", "plan", "pensive", "prose", "continuation" }
        for _, name in ipairs(expected) do
            assert.is_not_nil(by_name(name), "missing base noun: " .. name)
        end
        assert.are.equal(#expected, #descriptors, "unexpected extra/missing base nouns")
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
        for _, d in ipairs(descriptors) do
            local want = (d.name == "vision") and "%.yaml$" or "%.md$"
            for _, glob in ipairs(d.locate) do
                assert.matches(want, glob, "wrong extension for " .. d.name .. ": " .. glob)
            end
        end
    end)

    it("derives dir-backed globs from config keys, not literals", function()
        -- issue/vision home in their config dirs; the registry is repo-relative
        -- (RegistryBuilder prefixes repo_root).
        assert.matches("^" .. config.issues_dir .. "/", by_name("issue").locate[1])
        assert.matches("^" .. config.vision_dir .. "/", by_name("vision").locate[1])
    end)

    it("reads the LIVE config — user overrides of chat_dir/notes_dir reach the descriptors", function()
        -- I2 regression: a load-time snapshot of defaults would ignore these.
        local overridden = vim.tbl_extend("force", config, {
            chat_dir = "/custom/chats",
            notes_dir = "/custom/notes",
        })
        local built = base.build(overridden)
        local function find(name)
            for _, d in ipairs(built) do
                if d.name == name then return d end
            end
        end
        assert.is_true(vim.tbl_contains(find("chat").locate, "/custom/chats/*.md"))
        assert.is_true(vim.tbl_contains(find("note").locate, "/custom/notes/*.md"))
    end)
end)
