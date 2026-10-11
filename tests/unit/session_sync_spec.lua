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
            ss.view("operator", { stale = true }, "ops:0"))
        assert.same({ state = "agent", label = "ops:0 owes a response, 7 min, read-only", hl = "ParleySessionSyncAgent" },
            ss.view("agent", { minutes = 7 }, "ops:0"))
    end)
    it("shows a violation over staleness, in the operator colour", function()
        assert.same({ state = "violated", label = "ops:0 wrote under your lock: yours kept, theirs in .clobbered",
            hl = "ParleySessionSyncOperator" }, ss.view("operator", { stale = true, violated = true }, "ops:0"))
    end)
end)

describe("session_sync.parse_time", function()
    it("reads RFC3339 in UTC, with fractions and offsets", function()
        assert.equals(0, ss.parse_time("1970-01-01T00:00:00Z"))
        assert.equals(1791696000, ss.parse_time("2026-10-11T05:20:00Z"))
        assert.equals(1791696000, ss.parse_time("2026-10-10T22:20:00.123456-07:00"))
        assert.equals(951782400, ss.parse_time("2000-02-29T00:00:00Z"))
        assert.is_nil(ss.parse_time("yesterday"))
        assert.is_nil(ss.parse_time(nil))
    end)
end)

describe("session_sync.find_actor", function()
    local function a(slot) return { Binding = { Slot = slot } } end
    it("matches the exact slot, else a unique repository prefix with the same index", function()
        local actors = { a("parley.nvim:1"), a("ops:0"), a("pair:1"), a("pair-two:1") }
        assert.equals(actors[2], ss.find_actor(actors, "ops:0"))
        assert.equals(actors[1], ss.find_actor(actors, "parley:1"))
        assert.equals(actors[3], ss.find_actor(actors, "pair:1"))
        assert.is_nil(ss.find_actor(actors, "pa:1"))       -- ambiguous
        assert.is_nil(ss.find_actor(actors, "parley:2"))
        assert.is_nil(ss.find_actor(nil, "ops:0"))
    end)
end)
