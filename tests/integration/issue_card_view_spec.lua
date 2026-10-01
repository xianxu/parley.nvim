-- #309: a tracker card with no details in this checkout opens as a read-only
-- scratch view (real git through the tracker fixture, real buffers).
local parley = require("parley")
parley.setup({
    chat_dir = vim.fn.tempname() .. "-issue-card-view-spec",
    providers = {},
    api_keys = {},
})

local issue_tracker = require("parley.issue_tracker")
local issue_card_view = require("parley.issue_card_view")
local issue_cards = require("parley.issue_cards")
local issues = require("parley.issues")
local fixture = require("tests.helpers.tracker_repo")

local function wait_for(predicate, what)
    assert(vim.wait(10000, predicate, 10), "timed out waiting for " .. what)
end

local function lines(buf)
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function has_line(buf, text)
    return vim.tbl_contains(lines(buf), text)
end

describe("issue card view", function()
    local repos, warnings, real_warning

    before_each(function()
        issue_tracker.reset_for_tests()
        issue_tracker.fetch_enabled = true
        issue_tracker.fetch_interval_s = 0
        warnings = {}
        real_warning = parley.logger.warning
        parley.logger.warning = function(message) warnings[#warnings + 1] = message end
        repos = fixture.create({
            ["000001-alpha.md"] = { status = "open", title = "Alpha" },
            ["000005-remote.md"] = { status = "open", title = "Remote only", problem = "Why it matters" },
        }, { ["000005-remote.md"] = false })
    end)

    after_each(function()
        parley.logger.warning = real_warning
        issue_tracker.fetch_interval_s = 60
        issue_tracker.fetch_enabled = false
        vim.cmd("silent! %bwipeout!")
        fixture.destroy(repos)
    end)

    local function open_settled()
        local buf = issue_card_view.open(repos.reader, "000005")
        wait_for(function()
            local status = issue_tracker.status(repos.reader)
            return has_line(buf, "Why it matters") and status and not status.fetching
                and lines(buf)[1]:find("fetched", 1, true) ~= nil
        end, "the card view to settle")
        return buf
    end

    it("shows the card read-only with its provenance and source ref", function()
        local buf = open_settled()
        assert.equals(buf, vim.api.nvim_get_current_buf())
        assert.equals(issue_cards.card_ref(repos.reader, "000005"), vim.api.nvim_buf_get_name(buf))
        assert.equals("nofile", vim.bo[buf].buftype)
        assert.is_false(vim.bo[buf].modifiable)
        assert.is_true(vim.bo[buf].readonly)
        local first = lines(buf)[1]
        assert.truthy(first:find("card only · read only", 1, true))
        assert.truthy(first:find("origin/issue-tracker @ ", 1, true))
        assert.truthy(has_line(buf, "# Remote only"))
        assert.truthy(has_line(buf, "## Problem"))
        assert.truthy(has_line(buf, "status: open"))
        assert.falsy(has_line(buf, "## Spec"))
        local marks = vim.api.nvim_buf_get_extmarks(buf, issue_card_view.NS, 0, -1, { details = true })
        assert.equals(1, #marks)
        assert.equals(0, marks[1][2])
        assert.equals("ParleyIssueTracker", marks[1][4].hl_group)
        assert.equals(0, vim.fn.filereadable(repos.reader .. "/workshop/issues/000005-remote.md"))
    end)

    it("renders without readonly warnings", function()
        vim.v.warningmsg = ""
        open_settled()
        assert.equals("", vim.v.warningmsg)
    end)

    it("reuses one buffer per card while shown, and wipes it once hidden", function()
        local buf = open_settled()
        vim.cmd("split | enew") -- the card stays displayed in the other window
        assert.equals(buf, issue_card_view.open(repos.reader, "000005"))
        vim.cmd("only | enew")
        assert.is_false(vim.api.nvim_buf_is_valid(buf))
    end)

    it("refuses buffer-scoped issue mutations", function()
        local buf = open_settled()
        local before = lines(buf)
        issues.cmd_issue_status()
        issues.cmd_issue_decompose()
        assert.same(before, lines(buf))
        assert.equals(2, #warnings)
        for _, message in ipairs(warnings) do
            assert.equals(issues.card_only_warning("000005"), message)
        end
    end)

    it("repaints when a fetch brings a newer card", function()
        local buf = open_settled()
        fixture.write_card(repos.writer, "000005-remote.md",
            { status = "working", title = "Remote only", problem = "Why it matters" })
        issue_tracker.refresh(repos.reader)
        wait_for(function() return has_line(buf, "status: working") end, "the moved card")
    end)

    it("keeps the card and reports a failed fetch", function()
        local buf = open_settled()
        fixture.git(repos.reader, { "remote", "set-url", "origin", repos.base .. "/missing.git" })
        issue_card_view.open(repos.reader, "000005")
        wait_for(function() return lines(buf)[1]:find("last fetch failed", 1, true) ~= nil end,
            "the failure to show")
        assert.truthy(has_line(buf, "Why it matters"))
        assert.falsy(lines(buf)[1]:find("· fetched", 1, true))
    end)
end)
