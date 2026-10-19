local watchdog = require("parley.fd_watchdog")

describe("fd_watchdog (#399)", function()
    it("fires once, on the first count above a positive threshold", function()
        assert.is_false(watchdog.crossed(200, 200, false))
        assert.is_true(watchdog.crossed(201, 200, false))
        assert.is_false(watchdog.crossed(250, 200, true))
        assert.is_false(watchdog.crossed(999, 0, false))
        assert.is_false(watchdog.crossed(nil, 200, false))
    end)

    it("keeps only this process's children from ps", function()
        local ps = table.concat({
            "  100     1 /sbin/launchd",
            "  201   100 couch --session-sync status --json /x.md",
            "  202   100 /usr/bin/git diff",
            "  203   201 sleep 5",
            "garbage line",
        }, "\n")
        assert.are.same({ "201 couch --session-sync status --json /x.md", "202 /usr/bin/git diff" }, watchdog.children(ps, 100))
        assert.are.same({}, watchdog.children(nil, 100))
    end)

    it("reports the count, the children and lsof, and records a failed command", function()
        local lines = watchdog.report({ time = "T", pid = 100, count = 201, threshold = 200,
            ps = { code = 0, stdout = "  201   100 couch status\n" },
            lsof = { code = 1, stdout = "", stderr = "lsof: denied" } })
        local text = table.concat(lines, "\n")
        assert.truthy(text:find("open descriptors: 201 (threshold 200)", 1, true))
        assert.truthy(text:find("## children\n201 couch status", 1, true))
        assert.truthy(text:find("## lsof -p 100\n(exit 1) lsof: denied", 1, true))
        local none = table.concat(watchdog.report({ time = "T", pid = 1, count = 9, threshold = 8,
            ps = { code = 1, stdout = "", stderr = "EPERM" }, lsof = { code = 0, stdout = "a\nb\n" } }), "\n")
        assert.truthy(none:find("(ps exit 1) EPERM\n(none)", 1, true))
        assert.truthy(none:find("## lsof -p 1\na\nb", 1, true))
    end)

    it("removes all but the newest captures, ignoring other files", function()
        local names = { "fd-20261019-070000-1.txt", "notes.md", "fd-20261019-090000-1.txt", "fd-20261019-080000-2.txt" }
        assert.are.same({ "fd-20261019-070000-1.txt" }, watchdog.stale(names, 2))
        assert.are.same({}, watchdog.stale(names, 5))
    end)
end)
