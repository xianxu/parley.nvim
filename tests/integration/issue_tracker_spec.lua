-- #308: the tracker reader against real git — a bare remote and two clones,
-- with an orphan `issue-tracker` branch carrying cards (ARCH-MOCK: the real
-- binary behind the same seam, no function-call mocks).
local tracker = require("parley.issue_tracker")
local fixture = require("tests.helpers.tracker_repo")

local function wait_for(predicate)
    assert(vim.wait(10000, predicate, 10), "timed out waiting for the tracker")
end

local function load(root)
    local result, done = nil, false
    tracker.load(root, function(cards)
        result, done = cards, true
    end)
    wait_for(function() return done end)
    return result
end

describe("issue_tracker", function()
    local repos, git_calls

    before_each(function()
        tracker.reset_for_tests()
        tracker.fetch_interval_s = 0
        tracker.fetch_enabled = true
        git_calls = {}
        tracker._on_git = function(argv)
            git_calls[#git_calls + 1] = argv[4]
        end
        repos = fixture.create({
            ["000001-alpha.md"] = { status = "open", title = "Alpha" },
            ["000002-beta.md"] = { status = "working", title = "Beta" },
        })
    end)

    after_each(function()
        tracker._on_git = nil
        tracker.fetch_interval_s = 60
        tracker.fetch_enabled = false
        fixture.destroy(repos)
    end)

    local function count(subcommand)
        local n = 0
        for _, name in ipairs(git_calls) do
            if name == subcommand then n = n + 1 end
        end
        return n
    end

    it("reads every card from the last-fetched tracker ref", function()
        local cards = load(repos.reader)
        assert.equals("open", cards["000001"].fields.status)
        assert.equals("Beta", cards["000002"].title)
    end)

    local function refresh(root)
        local settled = false
        tracker.refresh(root, function() settled = true end)
        wait_for(function() return settled end)
    end

    local function subscriber(alive)
        local seen = {}
        tracker.subscribe(repos.reader, {
            notify = function(cards) seen[#seen + 1] = cards end,
            alive = alive or function() return true end,
        })
        return seen
    end

    it("notifies every live subscriber of a moved tip, and stays quiet otherwise", function()
        assert.equals("open", load(repos.reader)["000001"].fields.status)
        local first, second = subscriber(), subscriber()
        fixture.write_card(repos.writer, "000001-alpha.md", { status = "done", title = "Alpha" })

        refresh(repos.reader)
        assert.equals(1, #first)
        assert.equals(1, #second)
        assert.equals("done", second[1]["000001"].fields.status)

        refresh(repos.reader)
        assert.equals(1, #first)
    end)

    it("notifies subscribers when a plain load sees a ref another checkout fetched", function()
        tracker.fetch_interval_s = 3600
        load(repos.reader)
        local seen = subscriber()
        fixture.write_card(repos.writer, "000002-beta.md", { status = "done", title = "Beta" })
        fixture.git(repos.reader, { "fetch", "-q", "origin", "issue-tracker" })
        load(repos.reader)
        assert.equals(1, #seen)
        assert.equals("done", seen[1]["000002"].fields.status)
    end)

    it("drops subscribers whose view closed", function()
        load(repos.reader)
        local open = true
        local seen = subscriber(function() return open end)
        open = false
        fixture.write_card(repos.writer, "000001-alpha.md", { status = "done", title = "Alpha" })
        refresh(repos.reader)
        assert.equals(0, #seen)
    end)

    it("keeps the last good cards when a re-read fails", function()
        load(repos.reader)
        local blob = vim.trim(fixture.git(repos.reader, { "rev-parse", "origin/issue-tracker:issue-tracker.json" }))
        fixture.git(repos.reader, { "update-ref", "refs/remotes/origin/issue-tracker", blob })
        local cards = load(repos.reader)
        assert.equals("open", cards["000001"].fields.status)
    end)

    it("throttles fetches inside the interval", function()
        tracker.fetch_interval_s = 3600
        load(repos.reader)
        refresh(repos.reader)
        refresh(repos.reader)
        assert.equals(1, count("fetch"))
    end)

    it("returns nil for a repository without the cutover marker, without running git", function()
        vim.fn.delete(repos.reader .. "/workshop/issue-tracker.json")
        assert.is_nil(load(repos.reader))
        assert.equals(0, #git_calls)
    end)

    it("returns nil when no remote carries the tracker ref", function()
        fixture.git(repos.reader, { "update-ref", "-d", "refs/remotes/origin/issue-tracker" })
        assert.is_nil(load(repos.reader))
    end)

    it("shares one read between concurrent loads and reuses cached blobs", function()
        local first, second
        tracker.load(repos.reader, function(cards) first = cards end)
        tracker.load(repos.reader, function(cards) second = cards end)
        wait_for(function() return first ~= nil and second ~= nil end)
        assert.equals(first, second)
        assert.equals(1, count("ls-tree"))
        assert.equals(1, count("cat-file"))

        load(repos.reader)
        assert.equals(1, count("cat-file"))
    end)

    it("reads only changed blobs after the tracker moves", function()
        load(repos.reader)
        fixture.write_card(repos.writer, "000002-beta.md", { status = "done", title = "Beta" })
        local seen = subscriber()
        refresh(repos.reader)
        local moved = seen[1]
        assert.equals("done", moved["000002"].fields.status)
        assert.equals("open", moved["000001"].fields.status)
        assert.equals(2, count("cat-file"))
        assert.equals(2, tracker._blob_count_for_tests(repos.reader))
    end)
end)
