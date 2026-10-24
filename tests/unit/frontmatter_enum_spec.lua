-- #384: frontmatter typeahead for enum values. The pure core: where the cursor
-- is, and which declared values match what is typed.
local enum = require("parley.frontmatter_enum")

describe("frontmatter_enum (#384)", function()
    local lines = { "---", "test-mode: al", "title: x", "---", "test-mode: al" }

    before_each(function()
        enum.declare("test-mode", { values = function() return { "alpha", "beta", "albatross" } end })
        enum.declare("test-scoped", {
            values = function() return { "one" } end,
            applies = function(path) return path:find("/scoped/", 1, true) ~= nil end,
        })
    end)

    after_each(function()
        enum.undeclare("test-mode")
        enum.undeclare("test-scoped")
    end)

    it("finds the value of a declared key inside the frontmatter", function()
        local ctx = enum.context(lines, 2, #"test-mode: al")
        assert.same({ key = "test-mode", start = #"test-mode: ", partial = "al" }, ctx)
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

    it("offers no retired editorial keys while retaining declared owners", function()
        for _, key in ipairs({ "collaboration-mode", "presentation", "presentation-mode", "process-instruction", "processing-mode" }) do
            assert.same({}, enum.candidates(key, "", "/any.md"))
            assert.is_nil(enum.context({ "---", key .. ": ", "---" }, 2, #key + 2))
            assert.is_false(vim.tbl_contains(enum.keys(), key))
        end
        assert.is_true(vim.tbl_contains(enum.keys(), "status"))
    end)

    it("leaves no test key behind after teardown", function()
        enum.undeclare("test-mode")
        assert.is_false(vim.tbl_contains(enum.keys(), "test-mode"))
        assert.same({}, enum.candidates("test-mode", "", "/any.md"))
    end)

    describe("the issue status", function()
        local issues = require("parley.issues")
        local issue_vocabulary = require("parley.issue_vocabulary")
        local saved_dir, root

        before_each(function()
            saved_dir = issues.get_issues_dir
            root = vim.fn.resolve(vim.fn.tempname())
            vim.fn.mkdir(root .. "/repo/workshop/issues", "p")
            issues.get_issues_dir = function() return root .. "/repo/workshop/issues" end
        end)
        after_each(function()
            issues.get_issues_dir = saved_dir
            issue_vocabulary.reset_for_tests()
            vim.fn.delete(root, "rf")
        end)

        it("completes the vocabulary's statuses in issue files only", function()
            local issue = root .. "/repo/workshop/issues/000001-x.md"
            assert.same({ "working", "wontfix" }, enum.candidates("status", "wo", issue))
            assert.same(issues.status_values(), enum.candidates("status", "", issue))
            assert.same({}, enum.candidates("status", "", root .. "/repo/notes/a.md"))
            assert.same({}, enum.candidates("status", "", root .. "/repo/workshop/issues-old/a.md"))
            assert.same({}, enum.candidates("status", "", ""))
        end)

        it("matches an issue file reached through a symlinked workspace", function()
            vim.uv.fs_symlink(root .. "/repo", root .. "/link")
            assert.same({ "working", "wontfix" }, enum.candidates("status", "wo", root .. "/link/workshop/issues/000001-x.md"))
            issues.get_issues_dir = function() return root .. "/link/workshop/issues" end
            assert.same({ "working", "wontfix" }, enum.candidates("status", "wo", root .. "/repo/workshop/issues/000001-x.md"))
        end)
    end)
end)
