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
