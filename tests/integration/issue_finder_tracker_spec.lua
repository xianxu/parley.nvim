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
local issue_cards = require("parley.issue_cards")
local issues = require("parley.issues")

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

-- #309: cards with no details in this checkout get their own rows.
describe("IssueFinder card-only issues", function()
    local repos, updates, picker_options, warnings, opened

    local function open_finder(view_mode, super_repo)
        updates, warnings, opened = {}, {}, {}
        local fake = {
            _issue_finder = { opened = false, view_mode = view_mode or 0, query = "" },
            _finder_dependencies = { schedule = vim.schedule },
            -- Absolute dirs: a relative history_dir would resolve through the real
            -- parley's project_root() to this repository.
            config = {
                issues_dir = repos.reader .. "/workshop/issues",
                history_dir = repos.reader .. "/workshop/history/issues",
                issue_finder_mappings = {},
            },
            super_repo = super_repo,
            float_picker = {
                open = function(options)
                    picker_options = options
                    return {
                        update = function(items)
                            updates[#updates + 1] = { items = items }
                        end,
                        set_status = function() end,
                        current_query = function() return "" end,
                        selected = function() return nil end,
                        is_closed = function() return false end,
                        close = function() end,
                    }
                end,
            },
            helpers = {},
            logger = {
                warning = function(message) warnings[#warnings + 1] = message end,
                debug = function() end,
            },
            cmd = {},
            open_buf = function(path) opened[#opened + 1] = path end,
        }
        issue_finder.setup(fake)
        issue_finder.open()
        return fake
    end

    local function ids(items)
        local out = {}
        for _, item in ipairs(items) do
            out[#out + 1] = item.issue.id
        end
        return out
    end

    local function wait_items(predicate, what)
        assert(vim.wait(10000, function()
            return #updates > 0 and predicate(updates[#updates].items)
        end, 10), "timed out waiting for " .. what)
        return updates[#updates].items
    end

    local function find(items, id)
        for _, item in ipairs(items) do
            if item.issue.id == id then return item end
        end
    end

    local function mapping(id)
        local keys = require("parley.keybinding_registry").keys_for(id, {})
        for _, entry in ipairs(picker_options.mappings) do
            if vim.deep_equal(entry.key, keys) then return entry.fn end
        end
        error("no mapping for " .. id)
    end

    before_each(function()
        issue_tracker.reset_for_tests()
        issue_tracker.fetch_enabled = true
        issue_tracker.fetch_interval_s = 0
        repos = fixture.create({
            ["000001-alpha.md"] = { status = "wontfix", title = "Alpha" },
            ["000002-beta.md"] = { status = "open", title = "Beta" },
            ["000005-remote.md"] = { status = "open", title = "Remote only", problem = "Why" },
            ["000009-archived.md"] = { status = "done", title = "Archived" },
            ["000011-gone.md"] = { status = "done", title = "Gone" },
        }, {
            ["000001-alpha.md"] = { status = "open", title = "Alpha" },
            ["000005-remote.md"] = false,
            ["000009-archived.md"] = { status = "done", title = "Archived", dir = "workshop/history/issues" },
            ["000011-gone.md"] = false,
        })
        fixture.details_on_branch(repos, "000005-remote", "000005-remote.md", { status = "open", title = "Remote only" })
    end)

    after_each(function()
        issue_finder.setup(parley)
        issue_tracker.fetch_interval_s = 60
        issue_tracker.fetch_enabled = false
        vim.cmd("silent! %bwipeout!")
        fixture.destroy(repos)
    end)

    local function has_card_row(items)
        local remote = find(items, "000005")
        return remote ~= nil and remote.issue.card_only == true
    end

    it("adds one card-only row per card without local details, sorted by card status", function()
        open_finder(0)
        local items = wait_items(has_card_row, "the card-only row")
        assert.same({ "000002", "000005", "000001" }, ids(items))
        local remote = find(items, "000005")
        assert.equals(issue_cards.card_ref(repos.reader, "000005"), remote.value)
        assert.truthy(remote.display:find("000005🔒 Remote only", 1, true))
        assert.same({ { 0, #remote.display, "ParleyIssueTracker" } }, remote.highlights)
        assert.truthy(remote.search_text:find("Remote only", 1, true))
        local alpha = find(items, "000001")
        assert.is_nil(alpha.issue.card_only)
        assert.equals(repos.reader .. "/workshop/issues/000001-alpha.md", alpha.value)
    end)

    it("joins archived details by id; only detail-less finished cards are card-only", function()
        open_finder(1)
        local items = wait_items(function(list) return find(list, "000011") ~= nil end, "the finished card")
        assert.same({ "000009", "000011" }, (function()
            local list = ids(items)
            table.sort(list)
            return list
        end)())
        assert.is_nil(find(items, "000009").issue.card_only)
        assert.is_true(find(items, "000011").issue.card_only)
    end)

    it("opens a card-only row as the card view in the source window", function()
        local source = vim.api.nvim_get_current_win()
        open_finder(0)
        local items = wait_items(has_card_row, "the card-only row")
        picker_options.on_select(find(items, "000005"))
        assert.equals(source, vim.api.nvim_get_current_win())
        assert.equals(issue_cards.card_ref(repos.reader, "000005"),
            vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
        assert.same({}, opened)
        picker_options.on_select(find(items, "000002"))
        assert.same({ repos.reader .. "/workshop/issues/000002-beta.md" }, opened)
    end)

    it("refuses delete and status cycling on a card-only row", function()
        open_finder(0)
        local items = wait_items(has_card_row, "the card-only row")
        local remote = find(items, "000005")
        local closed = false
        mapping("if_delete")(remote, function() closed = true end, {
            suspend_for_external_ui = function() error("delete prompt opened") end,
        })
        mapping("if_cycle_status")(remote, function() closed = true end)
        assert.is_false(closed)
        assert.same({ issues.card_only_warning("000005"), issues.card_only_warning("000005") }, warnings)
        assert.equals(0, vim.fn.filereadable(repos.reader .. "/workshop/issues/000005-remote.md"))
    end)

    it("finds card-only issues after a first fetch in a checkout without the tracker ref", function()
        fixture.git(repos.reader, { "update-ref", "-d", "refs/remotes/origin/issue-tracker" })
        open_finder(0)
        wait_items(has_card_row, "the bootstrapped card-only row")
    end)

    it("filters card-only rows with the repo facet", function()
        local other = repos.base .. "/other/workshop/issues"
        vim.fn.mkdir(other, "p")
        vim.fn.writefile(vim.split(fixture.details_text("000003-other.md", { status = "open", title = "Other" }), "\n"),
            other .. "/000003-other.md")
        local super_repo = {
            expand_roots = function(dir)
                if dir:find("history", 1, true) then
                    return { { dir = dir, repo_name = "reader" } }
                end
                return { { dir = dir, repo_name = "reader" }, { dir = other, repo_name = "other" } }
            end,
        }
        open_finder(0, super_repo)
        local items = wait_items(has_card_row, "the card-only row")
        assert.truthy(find(items, "000003"))
        picker_options.tag_bar.on_toggle("reader")
        items = updates[#updates].items
        assert.is_nil(find(items, "000005"))
        assert.truthy(find(items, "000003"))
    end)

    it("joins against the dirs the finder scans, not a re-derivation of them", function()
        -- The super-repo puts this repository's history somewhere the config
        -- value does not name; 000009's details live only there.
        local archive = repos.reader .. "/archive/issues"
        vim.fn.mkdir(archive, "p")
        vim.fn.rename(repos.reader .. "/workshop/history/issues/000009-archived.md", archive .. "/000009-archived.md")
        local super_repo = {
            expand_roots = function(dir)
                if dir:find("history", 1, true) then
                    return { { dir = archive, repo_name = "reader" } }
                end
                return { { dir = dir, repo_name = "reader" } }
            end,
        }
        open_finder(1, super_repo)
        local items = wait_items(function(list) return find(list, "000011") ~= nil end, "the finished card")
        local rows = 0
        for _, item in ipairs(items) do
            if item.issue.id == "000009" then
                rows = rows + 1
                assert.is_nil(item.issue.card_only)
            end
        end
        assert.equals(1, rows)
    end)

    it("counts only the files the scan turns into rows as local details", function()
        -- The scan skips a name with an empty slug, so it must not hide the card.
        vim.fn.writefile({ "---", "id: 000005", "---" }, repos.reader .. "/workshop/issues/000005-.md")
        open_finder(0)
        wait_items(has_card_row, "the card-only row despite a skipped file")
    end)

    it("adds no card-only rows for an untracked repository", function()
        vim.fn.delete(repos.reader .. "/workshop/issue-tracker.json")
        open_finder(0)
        assert(vim.wait(5000, function() return #updates > 0 end, 10))
        vim.wait(200)
        for _, item in ipairs(updates[#updates].items) do
            assert.is_nil(item.issue.card_only)
        end
    end)
end)
