-- Unit tests for lua/parley/discovery/merge.lua — the PURE heart of base ∪
-- local composition, tested directly without rg or temp fixtures.

local merge = require("parley.discovery.merge")

describe("merge.expand_locate", function()
    it("returns globs unchanged when there are no roots (global mode)", function()
        assert.are.same({ "**/*.md", "workshop/issues/*.md" }, merge.expand_locate({ "**/*.md", "workshop/issues/*.md" }, {}))
    end)

    it("prefixes repo-relative globs with each root", function()
        assert.are.same(
            { "/a/workshop/issues/*.md", "/b/workshop/issues/*.md" },
            merge.expand_locate({ "workshop/issues/*.md" }, { "/a", "/b" })
        )
    end)

    it("passes absolute globs through once, unprefixed", function()
        assert.are.same(
            { "/global/chats/*.md" },
            merge.expand_locate({ "/global/chats/*.md" }, { "/a", "/b" })
        )
    end)

    it("mixes relative (expanded) and absolute (passthrough) globs", function()
        assert.are.same(
            { "/a/workshop/parley/*.md", "/b/workshop/parley/*.md", "/global/chats/*.md" },
            merge.expand_locate({ "workshop/parley/*.md", "/global/chats/*.md" }, { "/a", "/b" })
        )
    end)

    it("dedupes identical expanded globs", function()
        assert.are.same(
            { "/a/x/*.md" },
            merge.expand_locate({ "x/*.md" }, { "/a", "/a" })
        )
    end)
end)

describe("merge.dedupe_compose", function()
    local function d(name)
        return { name = name }
    end

    it("keeps first occurrence, in order (base wins ties)", function()
        local base = { d("chat"), d("note") }
        local local1 = { d("widget"), d("chat") } -- chat collides with base
        local got = merge.dedupe_compose({ base, local1 })
        local names = vim.tbl_map(function(x) return x.name end, got)
        assert.are.same({ "chat", "note", "widget" }, names)
        -- the surviving chat is the base one (first), not local1's
        assert.are.equal(base[1], got[1])
    end)

    it("dedupes a name appearing across multiple local lists → once", function()
        local got = merge.dedupe_compose({ {}, { d("widget") }, { d("widget"), d("gadget") } })
        local names = vim.tbl_map(function(x) return x.name end, got)
        assert.are.same({ "widget", "gadget" }, names)
    end)

    it("returns an empty list for no input lists", function()
        assert.are.same({}, merge.dedupe_compose({}))
    end)
end)
