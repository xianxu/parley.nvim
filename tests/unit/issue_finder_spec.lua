-- Unit tests for IssueFinder pure view-mode logic (#158, was #152).
--
-- IssueFinder is a float-picker UI feature; these specs cover the pure pieces
-- extracted from `M.open` so the view-mode behaviour is verifiable headlessly:
--   * includes_history  — which mode scans archived history
--   * filter_for_view   — which scanned issues survive each mode
--   * VIEW_LABELS       — the cycle labels / order
-- The cycle is 2-state (`issues → history`, `% 2`), partitioned by the
-- `archived` flag: view 0 shows workshop/issues/, view 1 shows the archive.

local parley = require("parley")
parley.setup({
    chat_dir = vim.fn.tempname() .. "-issue-finder-spec",
    providers = {},
    api_keys = {},
})

local issue_finder = require("parley.issue_finder")
local issues = require("parley.issues")

describe("IssueFinder view-mode logic", function()
    local function sample_issues()
        return {
            { id = "1", status = "open", archived = false },
            { id = "2", status = "working", archived = false },
            { id = "3", status = "done", archived = false },
            { id = "4", status = "wontfix", archived = false },
            { id = "5", status = "done", archived = true }, -- archived history file
            { id = "6", status = "open" }, -- no archived flag → counts as non-archived
        }
    end

    local function ids(list)
        local out = {}
        for _, issue in ipairs(list) do
            table.insert(out, issue.id)
        end
        return out
    end

    describe("includes_history", function()
        it("only view 1 (history) scans archived history", function()
            assert.is_false(issue_finder.includes_history(0))
            assert.is_true(issue_finder.includes_history(1))
        end)
    end)

    describe("filter_for_view", function()
        it("view 0 (issues) keeps non-archived items (incl. done-not-archived)", function()
            local got = ids(issue_finder.filter_for_view(0, sample_issues()))
            assert.same({ "1", "2", "3", "4", "6" }, got)
        end)

        it("view 1 (history) keeps only archived items", function()
            local got = ids(issue_finder.filter_for_view(1, sample_issues()))
            assert.same({ "5" }, got)
        end)

        it("treats a nil archived flag as non-archived (shows in issues, not history)", function()
            local only_nil = { { id = "x", status = "open" } }
            assert.same({ "x" }, ids(issue_finder.filter_for_view(0, only_nil)))
            assert.same({}, ids(issue_finder.filter_for_view(1, only_nil)))
        end)

        it("does not mutate the input list", function()
            local input = sample_issues()
            issue_finder.filter_for_view(1, input)
            assert.equals(6, #input)
        end)
    end)

    describe("sort_for_view", function()
        it("keeps issues view on status/ID ordering", function()
            local sorted = issue_finder.sort_for_view(0, {
                { id = "0003", status = "done", mtime = 300 },
                { id = "0002", status = "blocked", mtime = 200 },
                { id = "0001", status = "open", mtime = 100 },
            })

            assert.same({ "0001", "0002", "0003" }, ids(sorted))
        end)

        it("sorts history view by mtime ascending so newest is last", function()
            local sorted = issue_finder.sort_for_view(1, {
                { id = "0003", status = "done", mtime = 300 },
                { id = "0001", status = "done", mtime = 100 },
                { id = "0002", status = "done", mtime = 200 },
            })

            assert.same({ "0001", "0002", "0003" }, ids(sorted))
        end)

        it("uses ID as the deterministic history tie-breaker", function()
            local sorted = issue_finder.sort_for_view(1, {
                { id = "0003", status = "done", mtime = 100 },
                { id = "0001", status = "done", mtime = 100 },
                { id = "0002", status = "done", mtime = 100 },
            })

            assert.same({ "0001", "0002", "0003" }, ids(sorted))
        end)
    end)

    describe("VIEW_LABELS", function()
        it("labels the 2-state cycle issues → history", function()
            assert.equals("issues", issue_finder.VIEW_LABELS[0])
            assert.equals("history", issue_finder.VIEW_LABELS[1])
            assert.is_nil(issue_finder.VIEW_LABELS[2])
        end)
    end)
end)

describe("IssueFinder query persistence", function()
    local original_defer_fn
    local original_scan_issues
    local deferred
    local fake
    local picker_calls
    local picker_updates
    local scan_results

    local function cycle_view_mapping(opts)
        for _, mapping in ipairs(opts.mappings) do
            if mapping.key == "<Tab>" then
                return mapping
            end
        end
        error("missing <Tab> cycle-view mapping")
    end

    before_each(function()
        deferred = {}
        picker_calls = {}
        picker_updates = {}
        scan_results = {}
        fake = {
            _issue_finder = { opened = false, view_mode = 0 },
            config = {
                issues_dir = "/unused/issues",
                history_dir = "/unused/history",
                issue_finder_mappings = {},
            },
            float_picker = {
                open = function(opts)
                    table.insert(picker_calls, opts)
                    return {
                        update = function(items, tags)
                            table.insert(picker_updates, { items = items, tags = tags })
                        end,
                    }
                end,
            },
            helpers = {},
            logger = { warning = function() end },
            cmd = {},
            open_buf = function() end,
        }

        original_scan_issues = issues.scan_issues
        issues.scan_issues = function(dir, opts)
            if opts.include_history and scan_results[opts.history_dir_override] then
                return vim.deepcopy(scan_results[opts.history_dir_override])
            end
            if scan_results[dir] then
                return vim.deepcopy(scan_results[dir])
            end
            if opts.include_history then
                return { {
                    id = "000002",
                    status = "done",
                    title = "Archived",
                    slug = "archived",
                    path = "/tmp/archived.md",
                    archived = true,
                    mtime = 2,
                    created = "",
                } }
            end
            return { {
                id = "000001",
                status = "open",
                title = "Active",
                slug = "active",
                path = "/tmp/active.md",
                archived = false,
                created = "",
            } }
        end

        original_defer_fn = vim.defer_fn
        vim.defer_fn = function(fn)
            table.insert(deferred, fn)
        end
        fake.cmd.IssueFinder = function()
            issue_finder.open()
        end
        issue_finder.setup(fake)
    end)

    after_each(function()
        issues.scan_issues = original_scan_issues
        vim.defer_fn = original_defer_fn
        issue_finder.setup(parley)
    end)

    it("preserves the raw query after cancel and later invocation", function()
        issue_finder.open()
        picker_calls[1].on_query_change("  sticky {repo} query  ")
        picker_calls[1].on_cancel()

        issue_finder.open()

        assert.equals("  sticky {repo} query  ", fake._issue_finder.query)
        assert.equals("  sticky {repo} query  ", picker_calls[2].initial_query)
    end)

    it("preserves the query after selection and later invocation", function()
        issue_finder.open()
        picker_calls[1].on_query_change("needle")
        picker_calls[1].on_select(picker_calls[1].items[1])

        issue_finder.open()

        assert.equals("needle", picker_calls[2].initial_query)
    end)

    it("persists a cleared query", function()
        fake._issue_finder.query = "old query"
        issue_finder.open()
        picker_calls[1].on_query_change("")
        picker_calls[1].on_cancel()

        issue_finder.open()

        assert.equals("", fake._issue_finder.query)
        assert.equals("", picker_calls[2].initial_query)
    end)

    it("preserves the query through the view-cycle repaint", function()
        issue_finder.open()
        picker_calls[1].on_query_change("needle {repo}")
        local closed = false

        cycle_view_mapping(picker_calls[1]).fn(nil, function()
            closed = true
        end)

        assert.is_true(closed)
        assert.equals(1, #deferred)
        deferred[1]()
        assert.equals(2, #picker_calls)
        assert.matches("history", picker_calls[2].title)
        assert.equals("/tmp/archived.md", picker_calls[2].items[1].value)
        assert.equals("needle {repo}", picker_calls[2].initial_query)
    end)

    local function issue(id, repo_name, archived)
        return {
            id = id,
            status = archived and "done" or "open",
            title = repo_name .. " issue",
            slug = repo_name .. "-issue",
            path = "/tmp/" .. repo_name .. "-" .. id .. ".md",
            archived = archived == true,
            mtime = tonumber(id) or 0,
            created = "",
            repo_name = repo_name,
        }
    end

    local function use_super_repos(repos)
        local issue_roots = {}
        local history_roots = {}
        for _, repo in ipairs(repos) do
            table.insert(issue_roots, { dir = "/" .. tostring(repo.name) .. "/issues", repo_name = repo.label })
            table.insert(history_roots, { dir = "/" .. tostring(repo.name) .. "/history", repo_name = repo.label })
        end
        fake.super_repo = {
            expand_roots = function(subdir)
                if subdir == fake.config.issues_dir then
                    return issue_roots
                end
                if subdir == fake.config.history_dir then
                    return history_roots
                end
                return nil
            end,
        }
    end

    it("shows sorted repository facets for completely labelled super-repo roots", function()
        use_super_repos({
            { name = "zeta", label = "zeta" },
            { name = "alpha", label = "alpha" },
        })
        scan_results["/zeta/issues"] = { issue("000002", "zeta") }
        scan_results["/alpha/issues"] = { issue("000001", "alpha") }

        issue_finder.open()

        assert.is_table(picker_calls[1].tag_bar)
        assert.same({
            { label = "alpha", enabled = true },
            { label = "zeta", enabled = true },
        }, picker_calls[1].tag_bar.tags)
        assert.equals(2, #picker_calls[1].items)
    end)

    it("omits repository facets outside a complete multi-repo expansion", function()
        issue_finder.open()
        assert.is_nil(picker_calls[1].tag_bar)

        use_super_repos({
            { name = "alpha", label = "alpha" },
            { name = "missing", label = nil },
        })
        scan_results["/alpha/issues"] = { issue("000001", "alpha") }
        scan_results["/missing/issues"] = { issue("000002", "missing") }
        issue_finder.open()
        assert.is_nil(picker_calls[2].tag_bar)
        assert.equals(2, #picker_calls[2].items)

        use_super_repos({
            { name = "alpha-one", label = "alpha" },
            { name = "alpha-two", label = "alpha" },
        })
        scan_results["/alpha-one/issues"] = { issue("000003", "alpha") }
        scan_results["/alpha-two/issues"] = { issue("000004", "alpha") }
        issue_finder.open()
        assert.is_nil(picker_calls[3].tag_bar)
        assert.equals(2, #picker_calls[3].items)
    end)

    it("derives facets from roots even when one repo has no issues in the current view", function()
        use_super_repos({
            { name = "alpha", label = "alpha" },
            { name = "beta", label = "beta" },
        })
        scan_results["/alpha/issues"] = { issue("000001", "alpha") }
        scan_results["/beta/issues"] = {}

        issue_finder.open()

        assert.same({
            { label = "alpha", enabled = true },
            { label = "beta", enabled = true },
        }, picker_calls[1].tag_bar.tags)
    end)

    it("filters in place while preserving query and state across views and reopens", function()
        use_super_repos({
            { name = "alpha", label = "alpha" },
            { name = "beta", label = "beta" },
        })
        scan_results["/alpha/issues"] = { issue("000001", "alpha") }
        scan_results["/beta/issues"] = { issue("000002", "beta") }
        scan_results["/alpha/history"] = { issue("000003", "alpha", true) }
        scan_results["/beta/history"] = { issue("000004", "beta", true) }

        issue_finder.open()
        picker_calls[1].on_query_change("  exact {beta} query  ")
        picker_calls[1].tag_bar.on_toggle("alpha")

        assert.equals(1, #picker_updates[1].items)
        assert.matches("beta", picker_updates[1].items[1].value)
        assert.equals("  exact {beta} query  ", fake._issue_finder.query)

        cycle_view_mapping(picker_calls[1]).fn(nil, function() end)
        deferred[1]()
        assert.same({
            { label = "alpha", enabled = false },
            { label = "beta", enabled = true },
        }, picker_calls[2].tag_bar.tags)
        assert.equals(1, #picker_calls[2].items)
        assert.matches("beta", picker_calls[2].items[1].value)
        assert.equals("  exact {beta} query  ", picker_calls[2].initial_query)

        picker_calls[2].on_cancel()
        issue_finder.open()
        assert.is_false(fake._issue_finder.repo_facet_state.alpha)
    end)

    it("defaults new repos on and restores choices for temporarily absent repos", function()
        use_super_repos({
            { name = "alpha", label = "alpha" },
            { name = "beta", label = "beta" },
        })
        scan_results["/alpha/issues"] = { issue("000001", "alpha") }
        scan_results["/beta/issues"] = { issue("000002", "beta") }
        issue_finder.open()
        picker_calls[1].tag_bar.on_toggle("alpha")
        picker_calls[1].tag_bar.on_toggle("beta")
        picker_calls[1].on_cancel()

        use_super_repos({
            { name = "alpha", label = "alpha" },
            { name = "gamma", label = "gamma" },
        })
        scan_results["/gamma/issues"] = { issue("000003", "gamma") }
        issue_finder.open()
        assert.is_false(fake._issue_finder.repo_facet_state.alpha)
        assert.is_false(fake._issue_finder.repo_facet_state.beta)
        assert.is_true(fake._issue_finder.repo_facet_state.gamma)
        picker_calls[2].on_cancel()

        use_super_repos({
            { name = "beta", label = "beta" },
            { name = "gamma", label = "gamma" },
        })
        issue_finder.open()
        assert.is_false(fake._issue_finder.repo_facet_state.beta)
    end)

    it("reopens after NONE with ALL available to restore every row", function()
        use_super_repos({
            { name = "alpha", label = "alpha" },
            { name = "beta", label = "beta" },
        })
        scan_results["/alpha/issues"] = { issue("000001", "alpha") }
        scan_results["/beta/issues"] = { issue("000002", "beta") }

        issue_finder.open()
        picker_calls[1].tag_bar.on_none()
        assert.equals(0, #picker_updates[1].items)
        picker_calls[1].on_cancel()

        issue_finder.open()
        assert.equals(0, #picker_calls[2].items)
        assert.is_table(picker_calls[2].tag_bar)
        picker_calls[2].tag_bar.on_all()
        assert.equals(2, #picker_updates[2].items)
    end)
end)
