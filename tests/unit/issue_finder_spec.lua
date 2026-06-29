-- Unit tests for IssueFinder pure view-mode logic (#152).
--
-- IssueFinder is a float-picker UI feature; these specs cover the pure pieces
-- extracted from `M.open` so the view-mode behaviour is verifiable headlessly:
--   * includes_history  — which mode scans archived history
--   * filter_for_view   — which scanned issues survive each mode
--   * VIEW_LABELS       — the cycle labels / order
-- The cycle order is `all → active → all+history` so the FIRST <C-a> press
-- hides done items (Option B, #152).

local parley = require("parley")
parley.setup({
    chat_dir = vim.fn.tempname() .. "-issue-finder-spec",
    providers = {},
    api_keys = {},
})

local issue_finder = require("parley.issue_finder")
local issue_vocabulary = require("parley.issue_vocabulary")

describe("IssueFinder view-mode logic", function()
    before_each(function()
        -- Deterministic vocab: open=open, active={working,blocked}, terminal={done,...}
        issue_vocabulary.set_default_for_tests(issue_vocabulary.from_table({
            categories = {
                open = { "open" },
                active = { "working", "blocked" },
                terminal = { "done", "wontfix" },
            },
            lifecycle = {
                { from = "open", to = "working", event = "claim", guards = {} },
            },
        }))
    end)

    after_each(function()
        issue_vocabulary.reset_for_tests()
    end)

    local function sample_issues()
        return {
            { id = "1", status = "open", archived = false },
            { id = "2", status = "working", archived = false },
            { id = "3", status = "done", archived = false },
            { id = "4", status = "wontfix", archived = false },
            { id = "5", status = "done", archived = true }, -- archived history file
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
        it("only mode 2 (all+history) scans archived history", function()
            assert.is_false(issue_finder.includes_history(0))
            assert.is_false(issue_finder.includes_history(1))
            assert.is_true(issue_finder.includes_history(2))
        end)
    end)

    describe("filter_for_view", function()
        it("mode 0 (all, default) shows done items", function()
            local got = ids(issue_finder.filter_for_view(0, sample_issues()))
            assert.same({ "1", "2", "3", "4", "5" }, got)
        end)

        it("mode 1 (active) hides done/terminal and archived items", function()
            local got = ids(issue_finder.filter_for_view(1, sample_issues()))
            assert.same({ "1", "2" }, got)
        end)

        it("mode 2 (all+history) shows everything scanned", function()
            local got = ids(issue_finder.filter_for_view(2, sample_issues()))
            assert.same({ "1", "2", "3", "4", "5" }, got)
        end)

        it("does not mutate the input list", function()
            local input = sample_issues()
            issue_finder.filter_for_view(1, input)
            assert.equals(5, #input)
        end)
    end)

    describe("VIEW_LABELS", function()
        it("labels the cycle all → active → all+history", function()
            assert.equals("all", issue_finder.VIEW_LABELS[0])
            assert.equals("active", issue_finder.VIEW_LABELS[1])
            assert.equals("all+history", issue_finder.VIEW_LABELS[2])
        end)
    end)
end)
