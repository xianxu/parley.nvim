local finder_scan = require("parley.finder_scan")
local records = require("parley.issue_finder_records")

local function identity(key, root_ordinal)
    return {
        key = key,
        source = {
            root_ordinal = root_ordinal or 1,
            unresolved_absolute = key,
        },
    }
end

local function candidate(overrides)
    local value = {
        path = "/repo/workshop/issues/000189-async-finders.md",
        name = "000189-async-finders.md",
        mtime = 100,
        lines = {
            "---",
            'id: "000189"',
            "status: working",
            "deps: [000188]",
            "created: 2026-07-15",
            "updated: 2026-07-16",
            "github_issue: 189",
            "---",
            "# Async finders",
        },
        archived = false,
        repo_name = "parley.nvim",
        identity = identity("/repo/workshop/issues/000189-async-finders.md"),
    }
    for key, item in pairs(overrides or {}) do
        value[key] = item
    end
    return value
end

describe("Issue finder records", function()
    it("adapts filename identity through the shared frontmatter and title parsers", function()
        local result = records.adapt(candidate())

        assert.equals("record", result.kind)
        assert.same({
            id = "000189",
            slug = "async-finders",
            title = "Async finders",
            status = "working",
            deps = { "000188" },
            created = "2026-07-15",
            updated = "2026-07-16",
            github_issue = "189",
            path = "/repo/workshop/issues/000189-async-finders.md",
            mtime = 100,
            archived = false,
            repo_name = "parley.nvim",
            identity = identity("/repo/workshop/issues/000189-async-finders.md"),
        }, result.value)
    end)

    it("skips Markdown files whose names do not carry an issue ID", function()
        local result = records.adapt(candidate({ name = "notes.md" }))
        assert.same({ kind = "skip" }, result)
    end)

    it("keeps a malformed but displayable issue with canonical defaults", function()
        local result = records.adapt(candidate({
            name = "000007-legacy.md",
            path = "/repo/workshop/issues/000007-legacy.md",
            identity = identity("/repo/workshop/issues/000007-legacy.md"),
            lines = { "# Legacy issue" },
            repo_name = nil,
        }))

        assert.equals("record", result.kind)
        assert.equals("000007", result.value.id)
        assert.equals("legacy", result.value.slug)
        assert.equals("Legacy issue", result.value.title)
        assert.equals("open", result.value.status)
        assert.same({}, result.value.deps)
    end)

    it("returns a registered static failure for malformed adapter payloads", function()
        local result = records.adapt(candidate({ lines = { "ok", false } }))
        assert.equals("failure", result.kind)
        assert.is_true(finder_scan.is_failure_kind(result.failure_kind))
    end)

    it("does not mutate its input", function()
        local input = candidate()
        local before = vim.deepcopy(input)
        records.adapt(input)
        assert.same(before, input)
    end)

    it("materializes issue and history views with deterministic vocabulary and path ties", function()
        local values = {
            records.adapt(candidate({
                path = "/z/000002-zeta.md",
                name = "000002-zeta.md",
                identity = identity("/z/000002-zeta.md", 2),
                lines = { "---", "status: done", "---", "# Zeta" },
                mtime = 300,
            })).value,
            records.adapt(candidate({
                path = "/b/000001-beta.md",
                name = "000001-beta.md",
                identity = identity("/b/000001-beta.md", 2),
                lines = { "---", "status: open", "---", "# Beta" },
                mtime = 200,
            })).value,
            records.adapt(candidate({
                path = "/a/000001-alpha.md",
                name = "000001-alpha.md",
                identity = identity("/a/000001-alpha.md", 1),
                lines = { "---", "status: open", "---", "# Alpha" },
                mtime = 200,
            })).value,
            records.adapt(candidate({
                path = "/history/000003-old.md",
                name = "000003-old.md",
                identity = identity("/history/000003-old.md"),
                lines = { "---", "status: done", "---", "# Old" },
                archived = true,
                mtime = 100,
            })).value,
        }

        local active = records.materialize(values, { archived = false })
        assert.same({ "/a/000001-alpha.md", "/b/000001-beta.md", "/z/000002-zeta.md" },
            vim.tbl_map(function(item) return item.path end, active))

        local history = records.materialize(values, { archived = true })
        assert.same({ "/history/000003-old.md" }, vim.tbl_map(function(item) return item.path end, history))
    end)

    it("lets the shared batcher contain adapter exceptions as static failures", function()
        local results = {}
        finder_scan.new_batcher({
            item_budget = 25,
            time_budget_ms = 5,
            now = function() return 0 end,
            schedule = function(callback) callback() end,
        }):run({ candidate() }, function()
            error("parser exploded")
        end, function(result)
            results[#results + 1] = result
        end, function() end)

        assert.equals("failure", results[1].kind)
        assert.equals(finder_scan.FAILURE_KIND.adapter_exception, results[1].failure_kind)
    end)
end)
