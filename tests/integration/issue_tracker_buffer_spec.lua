-- #308: an opened details file shows the tracker's values in amber where its
-- card_mirror is stale (real git, real buffer, real autocmds).
local parley = require("parley")
parley.setup({
    chat_dir = vim.fn.tempname() .. "-issue-tracker-buffer-spec",
    providers = {},
    api_keys = {},
})

local issue_tracker = require("parley.issue_tracker")
local tracker_buffer = require("parley.issue_tracker_buffer")
local fixture = require("tests.helpers.tracker_repo")

local function marks(buf)
    local out = {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, tracker_buffer.NS, 0, -1, { details = true })) do
        local chunk = mark[4].virt_text[1]
        out[#out + 1] = { row = mark[2], text = vim.trim(chunk[1]), group = chunk[2] }
    end
    return out
end

describe("issue tracker buffer annotations", function()
    local repos

    before_each(function()
        issue_tracker.reset_for_tests()
        issue_tracker.fetch_enabled = true
        issue_tracker.fetch_interval_s = 0
        repos = fixture.create({
            ["000001-alpha.md"] = { status = "wontfix", title = "Alpha" },
        }, {
            ["000001-alpha.md"] = { status = "open", title = "Alpha" },
        })
    end)

    after_each(function()
        issue_tracker.fetch_interval_s = 60
        issue_tracker.fetch_enabled = false
        fixture.destroy(repos)
    end)

    it("annotates the stale status line and clears it once the mirror agrees", function()
        vim.cmd.edit(vim.fn.fnameescape(repos.reader .. "/workshop/issues/000001-alpha.md"))
        local buf = vim.api.nvim_get_current_buf()
        assert(vim.wait(10000, function() return #marks(buf) > 0 end, 10), "no tracker annotation appeared")
        assert.same({ { row = 2, text = "← tracker: wontfix", group = "ParleyIssueTracker" } }, marks(buf))

        vim.api.nvim_buf_set_lines(buf, 2, 3, false, { "status: wontfix" })
        vim.cmd("silent write")
        assert.same({}, marks(buf))
    end)

    it("repaints when a peer moves the card and the buffer is entered again", function()
        vim.cmd.edit(vim.fn.fnameescape(repos.reader .. "/workshop/issues/000001-alpha.md"))
        local buf = vim.api.nvim_get_current_buf()
        assert(vim.wait(10000, function() return #marks(buf) > 0 end, 10))
        assert(vim.wait(10000, function()
            return not issue_tracker._fetching_for_tests(repos.reader)
        end, 10), "the initial background fetch never settled")

        fixture.write_card(repos.writer, "000001-alpha.md", { status = "done", title = "Alpha" })
        vim.api.nvim_exec_autocmds("BufEnter", { buffer = buf })
        assert(vim.wait(10000, function()
            local m = marks(buf)
            return m[1] and m[1].text == "← tracker: done"
        end, 10), "the fetched card never repainted the buffer")
    end)

    it("leaves files outside a tracked issues home alone", function()
        vim.fn.delete(repos.reader .. "/workshop/issue-tracker.json")
        vim.cmd.edit(vim.fn.fnameescape(repos.reader .. "/workshop/issues/000001-alpha.md"))
        local buf = vim.api.nvim_get_current_buf()
        vim.wait(300)
        assert.same({}, marks(buf))
    end)
end)
