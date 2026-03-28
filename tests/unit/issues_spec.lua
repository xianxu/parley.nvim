-- Unit tests for lua/parley/issues.lua pure functions
--
-- Tests parse_frontmatter, parse_deps_value, next_runnable,
-- cycle_status_value, topo_sort, slugify, extract_title, format_deps

local tmp_dir = "/tmp/parley-test-issues-" .. os.time()

-- Bootstrap parley (needed for chat_parser dependency)
local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

local issues = require("parley.issues")

--------------------------------------------------------------------------------
-- slugify
--------------------------------------------------------------------------------

describe("slugify", function()
    it("converts title to lowercase slug", function()
        assert.equals("auth-token-refresh", issues.slugify("Auth Token Refresh"))
    end)

    it("handles special characters", function()
        assert.equals("fix-bug-123", issues.slugify("Fix bug #123!"))
    end)

    it("collapses multiple dashes", function()
        assert.equals("a-b", issues.slugify("a   b"))
    end)

    it("strips leading/trailing dashes", function()
        assert.equals("hello", issues.slugify("--hello--"))
    end)

    it("handles empty string", function()
        assert.equals("", issues.slugify(""))
    end)
end)

--------------------------------------------------------------------------------
-- parse_deps_value
--------------------------------------------------------------------------------

describe("parse_deps_value", function()
    it("parses empty brackets", function()
        assert.same({}, issues.parse_deps_value("[]"))
    end)

    it("parses single dep", function()
        assert.same({ "0001" }, issues.parse_deps_value("[0001]"))
    end)

    it("parses multiple deps", function()
        assert.same({ "0001", "0003" }, issues.parse_deps_value("[0001, 0003]"))
    end)

    it("parses without brackets", function()
        assert.same({ "0001", "0002" }, issues.parse_deps_value("0001, 0002"))
    end)

    it("handles nil", function()
        assert.same({}, issues.parse_deps_value(nil))
    end)

    it("handles empty string", function()
        assert.same({}, issues.parse_deps_value(""))
    end)

    it("trims whitespace", function()
        assert.same({ "0001", "0002" }, issues.parse_deps_value("[ 0001 , 0002 ]"))
    end)
end)

--------------------------------------------------------------------------------
-- parse_frontmatter
--------------------------------------------------------------------------------

describe("parse_frontmatter", function()
    it("returns nil for empty lines", function()
        assert.is_nil(issues.parse_frontmatter({}))
    end)

    it("returns nil for no frontmatter", function()
        assert.is_nil(issues.parse_frontmatter({ "# Title", "", "Content" }))
    end)

    it("parses minimal frontmatter", function()
        local lines = { "---", "status: open", "---", "", "# Title" }
        local fm = issues.parse_frontmatter(lines)
        assert.is_not_nil(fm)
        assert.equals("open", fm.status)
        assert.same({}, fm.deps)
        assert.equals(3, fm.header_end)
    end)

    it("parses full frontmatter", function()
        local lines = {
            "---",
            "status: blocked",
            "deps: [0001, 0003]",
            "created: 2026-03-28",
            "updated: 2026-03-29",
            "---",
            "",
            "# Some issue",
        }
        local fm = issues.parse_frontmatter(lines)
        assert.is_not_nil(fm)
        assert.equals("blocked", fm.status)
        assert.same({ "0001", "0003" }, fm.deps)
        assert.equals("2026-03-28", fm.created)
        assert.equals("2026-03-29", fm.updated)
        assert.equals(6, fm.header_end)
    end)

    it("defaults status to open when missing", function()
        local lines = { "---", "deps: []", "---" }
        local fm = issues.parse_frontmatter(lines)
        assert.equals("open", fm.status)
    end)

    it("handles empty deps", function()
        local lines = { "---", "status: done", "deps: []", "---" }
        local fm = issues.parse_frontmatter(lines)
        assert.same({}, fm.deps)
    end)

    it("parses github_issue field", function()
        local lines = { "---", "status: open", "github_issue: 42", "deps: []", "---" }
        local fm = issues.parse_frontmatter(lines)
        assert.equals("42", fm.github_issue)
    end)

    it("github_issue is nil when absent", function()
        local lines = { "---", "status: open", "deps: []", "---" }
        local fm = issues.parse_frontmatter(lines)
        assert.is_nil(fm.github_issue)
    end)
end)

--------------------------------------------------------------------------------
-- extract_title
--------------------------------------------------------------------------------

describe("extract_title", function()
    it("extracts title after frontmatter", function()
        local lines = { "---", "status: open", "---", "", "# My Issue Title" }
        assert.equals("My Issue Title", issues.extract_title(lines, 3))
    end)

    it("returns empty for no heading", function()
        local lines = { "---", "status: open", "---", "", "No heading here" }
        assert.equals("", issues.extract_title(lines, 3))
    end)

    it("skips lines before header_end", function()
        local lines = { "---", "# Not This", "---", "", "# Real Title" }
        assert.equals("Real Title", issues.extract_title(lines, 3))
    end)
end)

--------------------------------------------------------------------------------
-- cycle_status_value
--------------------------------------------------------------------------------

describe("cycle_status_value", function()
    it("cycles open to blocked", function()
        assert.equals("blocked", issues.cycle_status_value("open"))
    end)

    it("cycles blocked to done", function()
        assert.equals("done", issues.cycle_status_value("blocked"))
    end)

    it("cycles done to open", function()
        assert.equals("open", issues.cycle_status_value("done"))
    end)

    it("defaults unknown to open", function()
        assert.equals("open", issues.cycle_status_value("unknown"))
    end)
end)

--------------------------------------------------------------------------------
-- next_runnable
--------------------------------------------------------------------------------

describe("next_runnable", function()
    it("returns nil for empty list", function()
        assert.is_nil(issues.next_runnable({}))
    end)

    it("returns single open issue with no deps", function()
        local result = issues.next_runnable({
            { id = "0001", status = "open", deps = {} },
        })
        assert.equals("0001", result.id)
    end)

    it("skips done issues", function()
        local result = issues.next_runnable({
            { id = "0001", status = "done", deps = {} },
            { id = "0002", status = "open", deps = {} },
        })
        assert.equals("0002", result.id)
    end)

    it("skips blocked issues", function()
        local result = issues.next_runnable({
            { id = "0001", status = "blocked", deps = {} },
            { id = "0002", status = "open", deps = {} },
        })
        assert.equals("0002", result.id)
    end)

    it("skips open issue with unmet dep", function()
        local result = issues.next_runnable({
            { id = "0001", status = "open", deps = { "0002" } },
            { id = "0002", status = "open", deps = {} },
        })
        assert.equals("0002", result.id)
    end)

    it("returns open issue when deps are done", function()
        local result = issues.next_runnable({
            { id = "0001", status = "done", deps = {} },
            { id = "0002", status = "open", deps = { "0001" } },
        })
        assert.equals("0002", result.id)
    end)

    it("handles diamond dependency", function()
        -- 0003 depends on 0001 and 0002; 0001 done, 0002 not done
        local result = issues.next_runnable({
            { id = "0001", status = "done", deps = {} },
            { id = "0002", status = "open", deps = {} },
            { id = "0003", status = "open", deps = { "0001", "0002" } },
        })
        assert.equals("0002", result.id)
    end)

    it("returns nil when all deps unmet (circular)", function()
        local result = issues.next_runnable({
            { id = "0001", status = "open", deps = { "0002" } },
            { id = "0002", status = "open", deps = { "0001" } },
        })
        assert.is_nil(result)
    end)

    it("returns nil when all issues are done", function()
        local result = issues.next_runnable({
            { id = "0001", status = "done", deps = {} },
            { id = "0002", status = "done", deps = {} },
        })
        assert.is_nil(result)
    end)

    it("picks oldest open issue first", function()
        local result = issues.next_runnable({
            { id = "0003", status = "open", deps = {} },
            { id = "0001", status = "open", deps = {} },
            { id = "0002", status = "open", deps = {} },
        })
        assert.equals("0001", result.id)
    end)

    it("advances past current_id", function()
        local all = {
            { id = "0001", status = "open", deps = {} },
            { id = "0002", status = "open", deps = {} },
            { id = "0003", status = "open", deps = {} },
        }
        assert.equals("0002", issues.next_runnable(all, "0001").id)
        assert.equals("0003", issues.next_runnable(all, "0002").id)
    end)

    it("cycles back to first when at end", function()
        local all = {
            { id = "0001", status = "open", deps = {} },
            { id = "0002", status = "open", deps = {} },
        }
        assert.equals("0001", issues.next_runnable(all, "0002").id)
    end)

    it("cycles back when current_id is past all runnable", function()
        local all = {
            { id = "0001", status = "open", deps = {} },
            { id = "0002", status = "done", deps = {} },
        }
        assert.equals("0001", issues.next_runnable(all, "0002").id)
    end)

    it("returns nil with current_id when no runnable", function()
        local all = {
            { id = "0001", status = "done", deps = {} },
        }
        assert.is_nil(issues.next_runnable(all, "0001"))
    end)
end)

--------------------------------------------------------------------------------
-- topo_sort
--------------------------------------------------------------------------------

describe("topo_sort", function()
    it("sorts open before blocked before done", function()
        local sorted = issues.topo_sort({
            { id = "0001", status = "done", deps = {} },
            { id = "0002", status = "blocked", deps = {} },
            { id = "0003", status = "open", deps = {} },
        })
        assert.equals("0003", sorted[1].id) -- open
        assert.equals("0002", sorted[2].id) -- blocked
        assert.equals("0001", sorted[3].id) -- done
    end)

    it("sorts by ID within same status", function()
        local sorted = issues.topo_sort({
            { id = "0003", status = "open", deps = {} },
            { id = "0001", status = "open", deps = {} },
            { id = "0002", status = "open", deps = {} },
        })
        assert.equals("0001", sorted[1].id)
        assert.equals("0002", sorted[2].id)
        assert.equals("0003", sorted[3].id)
    end)

    it("handles empty list", function()
        assert.same({}, issues.topo_sort({}))
    end)
end)

--------------------------------------------------------------------------------
-- format_deps
--------------------------------------------------------------------------------

describe("format_deps", function()
    it("formats empty deps", function()
        assert.equals("[]", issues.format_deps({}))
    end)

    it("formats single dep", function()
        assert.equals("[0001]", issues.format_deps({ "0001" }))
    end)

    it("formats multiple deps", function()
        assert.equals("[0001, 0003]", issues.format_deps({ "0001", "0003" }))
    end)

    it("handles nil", function()
        assert.equals("[]", issues.format_deps(nil))
    end)
end)
