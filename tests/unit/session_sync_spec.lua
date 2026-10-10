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
        assert.equals("holder: x\ntime: 1970-01-01T00:00:00Z\n", ss.lock_body("x", 0))
    end)
end)
