-- #384: frontmatter typeahead for enum values. The pure core: where the cursor
-- is, and which declared values match what is typed.
local enum = require("parley.frontmatter_enum")

describe("frontmatter_enum (#384)", function()
    local lines = { "---", "collaboration-mode: dis", "title: x", "---", "collaboration-mode: dis" }

    before_each(function()
        enum.declare("test-mode", { values = function() return { "alpha", "beta", "albatross" } end })
        enum.declare("test-scoped", {
            values = function() return { "one" } end,
            applies = function(path) return path:find("/scoped/", 1, true) ~= nil end,
        })
    end)

    it("finds the value of a declared key inside the frontmatter", function()
        local ctx = enum.context(lines, 2, #"collaboration-mode: dis")
        assert.same({ key = "collaboration-mode", start = #"collaboration-mode: ", partial = "dis" }, ctx)
    end)

    it("starts after the colon and its spaces, with an empty partial", function()
        local ctx = enum.context({ "---", "test-mode:", "---" }, 2, #"test-mode:")
        assert.same({ key = "test-mode", start = #"test-mode:", partial = "" }, ctx)
        ctx = enum.context({ "---", "test-mode:   al", "---" }, 2, #"test-mode:   al")
        assert.same({ key = "test-mode", start = #"test-mode:   ", partial = "al" }, ctx)
    end)

    it("offers nothing outside the frontmatter, on the key itself, or on an undeclared key", function()
        assert.is_nil(enum.context(lines, 5, #lines[5])) -- the body
        assert.is_nil(enum.context(lines, 1, 3)) -- the opening fence
        assert.is_nil(enum.context(lines, 2, 5)) -- inside the key name
        assert.is_nil(enum.context(lines, 3, #lines[3])) -- title: is not declared
        assert.is_nil(enum.context({ "---", "test-mode: a" }, 2, 12)) -- never closed
        assert.is_nil(enum.context({ "x", "---", "test-mode: a", "---" }, 3, 12)) -- not at the top
    end)

    it("filters the declared values by prefix", function()
        assert.same({ "alpha", "albatross" }, enum.candidates("test-mode", "al", "/any.md"))
        assert.same({ "alpha", "beta", "albatross" }, enum.candidates("test-mode", "", "/any.md"))
        assert.same({}, enum.candidates("test-mode", "z", "/any.md"))
        assert.same({}, enum.candidates("undeclared", "", "/any.md"))
    end)

    it("honors a key's applies(path)", function()
        assert.same({ "one" }, enum.candidates("test-scoped", "", "/repo/scoped/a.md"))
        assert.same({}, enum.candidates("test-scoped", "", "/repo/other/a.md"))
    end)

    it("draws collaboration-mode from the resolver's own list (one source)", function()
        local collaboration = require("parley.skills.review.collaboration")
        assert.same(collaboration.modes, enum.candidates("collaboration-mode", "", "/any.md"))
        for _, mode in ipairs(collaboration.modes) do
            local _, err = collaboration.resolve({ "---", "collaboration-mode: " .. mode, "---", "# T" })
            assert.is_nil(err, mode)
        end
        local _, err = collaboration.resolve({ "---", "collaboration-mode: nope", "---", "# T" })
        assert.is_not_nil(err)
    end)

    it("declares the issue status, for issue files only", function()
        assert.is_true(vim.tbl_contains(enum.keys(), "status"))
        assert.same({}, enum.candidates("status", "", "/repo/notes/a.md"))
    end)
end)
