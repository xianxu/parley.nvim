-- #308: the Issue Finder folds tracker cards into its rows (real disk scan,
-- real git, stub picker).
local parley = require("parley")
parley.setup({
    chat_dir = vim.fn.tempname() .. "-issue-finder-tracker-spec",
    providers = {},
    api_keys = {},
})

local issue_finder = require("parley.issue_finder")
local issue_tracker = require("parley.issue_tracker")
local default_config = require("parley.config")
local fixture = require("tests.helpers.tracker_repo")

describe("IssueFinder tracker overlay", function()
    local repos, updates, selected_value

    local function open_finder(issues_dir)
        local fake = {
            _issue_finder = { opened = false, view_mode = 0, query = "" },
            _finder_dependencies = { schedule = vim.schedule },
            config = {
                issues_dir = issues_dir,
                history_dir = default_config.history_dir,
                issue_finder_mappings = {},
            },
            float_picker = {
                open = function()
                    return {
                        update = function(items, _, next_selection)
                            updates[#updates + 1] = { items = items, next_selection = next_selection }
                        end,
                        set_status = function() end,
                        current_query = function() return "" end,
                        selected = function() return selected_value and { value = selected_value } or nil end,
                        is_closed = function() return false end,
                        close = function() end,
                    }
                end,
            },
            helpers = {},
            logger = { warning = function() end, debug = function() end },
            cmd = {},
            open_buf = function() end,
        }
        issue_finder.setup(fake)
        issue_finder.open()
    end

    local function last_items()
        return updates[#updates].items
    end

    local function row(items, id)
        for _, item in ipairs(items) do
            if item.issue.id == id then
                return item
            end
        end
    end

    before_each(function()
        updates, selected_value = {}, nil
        issue_tracker.reset_for_tests()
        issue_tracker.fetch_enabled = true
        issue_tracker.fetch_interval_s = 0
        repos = fixture.create({
            ["000001-alpha.md"] = { status = "wontfix", title = "Alpha" },
            ["000002-beta.md"] = { status = "open", title = "Beta" },
        }, {
            ["000001-alpha.md"] = { status = "open", title = "Alpha" },
        })
    end)

    after_each(function()
        issue_finder.setup(parley)
        issue_tracker.fetch_interval_s = 60
        issue_tracker.fetch_enabled = false
        fixture.destroy(repos)
    end)

    it("shows the card status in the tracker highlight and sorts by it", function()
        open_finder(repos.reader .. "/workshop/issues")
        assert(vim.wait(10000, function()
            local items = #updates > 0 and last_items()
            local alpha = items and row(items, "000001")
            return alpha and alpha.issue.status == "wontfix"
        end, 10), "tracker cards never reached the finder")

        local items = last_items()
        local alpha = row(items, "000001")
        assert.truthy(alpha.display:find("[wontfix]", 1, true))
        assert.same({ { 0, #"[wontfix]", "ParleyIssueTracker" } }, alpha.highlights)
        local beta = row(items, "000002")
        assert.same({}, beta.highlights)
        -- the open issue sorts ahead of the terminal one, by card status
        assert.equals("000002", items[1].issue.id)
    end)

    it("repaints when a background fetch moves the tracker, keeping the selection", function()
        open_finder(repos.reader .. "/workshop/issues")
        assert(vim.wait(10000, function()
            local alpha = #updates > 0 and row(last_items(), "000001")
            return alpha and alpha.issue.status == "wontfix"
        end, 10))
        selected_value = row(last_items(), "000002").value

        -- A peer moves #2's card; the next finder open fetches it.
        fixture.write_card(repos.writer, "000002-beta.md", { status = "working", title = "Beta" })
        updates = {}
        open_finder(repos.reader .. "/workshop/issues")
        assert(vim.wait(10000, function()
            local beta = #updates > 0 and row(last_items(), "000002")
            return beta and beta.issue.status == "working"
        end, 10), "fetched card never reached the finder")
        assert.equals(selected_value, updates[#updates].next_selection)
    end)

    it("repaints when another view's read finds a moved tip", function()
        issue_tracker.fetch_interval_s = 3600
        open_finder(repos.reader .. "/workshop/issues")
        assert(vim.wait(10000, function()
            local alpha = #updates > 0 and row(last_items(), "000001")
            return alpha and alpha.issue.status == "wontfix"
        end, 10))

        assert(vim.wait(10000, function() return not issue_tracker._busy_for_tests(repos.reader) end, 10))
        fixture.write_card(repos.writer, "000002-beta.md", { status = "working", title = "Beta" })
        fixture.git(repos.reader, { "fetch", "-q", "origin", "issue-tracker" })
        issue_tracker.load(repos.reader, function() end) -- e.g. an issue buffer's BufEnter
        assert(vim.wait(10000, function()
            local beta = row(last_items(), "000002")
            return beta and beta.issue.status == "working"
        end, 10), "the finder never heard of the move")
    end)

    it("leaves an untracked repository's rows as they are", function()
        vim.fn.delete(repos.reader .. "/workshop/issue-tracker.json")
        open_finder(repos.reader .. "/workshop/issues")
        assert(vim.wait(5000, function() return #updates > 0 end, 10))
        vim.wait(200)
        local alpha = row(last_items(), "000001")
        assert.equals("open", alpha.issue.status)
        assert.same({}, alpha.highlights)
    end)
end)
