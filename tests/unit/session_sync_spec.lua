local ss = require("parley.session_sync")

describe("session_sync.parse_header", function()
    it("reads owner and operator from a session-sync header", function()
        local h = ss.parse_header({
            "---", "type: session-sync", "owner: ops:0        # couch address", "operator: xian-xu", "---", "# body",
        })
        assert.same({ owner = "ops:0", operator = "xian-xu" }, h)
    end)
    it("is nil for another type, no frontmatter, or an unterminated header", function()
        assert.is_nil(ss.parse_header({ "---", "type: pensive", "owner: ops:0", "---" }))
        assert.is_nil(ss.parse_header({ "# title", "type: session-sync" }))
        assert.is_nil(ss.parse_header({ "---", "type: session-sync", "owner: ops:0" }))
    end)
    it("leaves owner nil when absent", function()
        assert.same({}, ss.parse_header({ "---", "type: session-sync", "---" }))
    end)
end)

describe("session_sync.lock_body", function()
    it("names the holder and the UTC time", function()
        assert.equals("holder: agent\ntime: 1970-01-01T00:00:00Z\n", ss.lock_body("agent", 0))
    end)
end)

describe("session_sync.turn", function()
    it("reads the turn holder from the lock text", function()
        assert.equals("free", ss.turn(nil))
        assert.equals("operator", ss.turn(ss.lock_body("operator", 0)))
        assert.equals("agent", ss.turn(ss.lock_body("agent", 0)))
        assert.equals("operator", ss.turn("garbage"))
    end)
end)

describe("session_sync.view", function()
    it("maps each turn to its label and highlight", function()
        assert.same({ state = "free", label = "free: editing takes your turn", hl = "ParleySessionSyncFree" },
            ss.view("free", false, "ops:0"))
        assert.same({ state = "operator", label = "your turn, Alt+Return to submit", hl = "ParleySessionSyncOperator" },
            ss.view("operator", false, "ops:0"))
        assert.same({ state = "stale", label = "unsent edits, Alt+Return to submit", hl = "ParleySessionSyncStale" },
            ss.view("operator", true, "ops:0"))
        assert.same({ state = "agent", label = "ops:0 working, read-only", hl = "ParleySessionSyncAgent" },
            ss.view("agent", false, "ops:0"))
    end)
end)
