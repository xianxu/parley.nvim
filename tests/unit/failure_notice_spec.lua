-- #197: the last mile — what the operator actually reads when a request fails.
-- Extracted from chat_respond's failure closure so it can be tested directly.

local chat_respond = require("parley.chat_respond")
local notice = chat_respond._failure_notice

describe("_failure_notice", function()
    it("prefers a recovery diagnosis over the raw provider body", function()
        local m = notice({
            http_status = 503,
            body = '{"type":"error","error":{"message":"auth_unavailable: no auth available"}}',
            message = 'cliproxy for "claude-opus-4-8": the credential (me@example.com) is '
                .. "unavailable: OAuth access token has expired.",
        })
        assert.matches("me@example.com", m)
        assert.matches("expired", m)
        -- the naked JSON must NOT be what the operator sees
        assert.is_nil(m:find("auth_unavailable", 1, true))
    end)

    it("falls back to the body when no diagnosis was supplied", function()
        local m = notice({ http_status = 500, body = "upstream exploded" })
        assert.matches("upstream exploded", m)
    end)

    it("names the HTTP status", function()
        assert.matches("HTTP 503", notice({ http_status = 503, message = "x" }))
    end)

    it("names how the transport ended when there is no HTTP status", function()
        assert.matches("exit 22", notice({ exit = "exit 22" }))
        -- #261 M3 review BR-45: a kill names its cause, and the partial body it
        -- left is not shown as if it were a diagnosis.
        local killed = notice({ exit = "killed: deadline", body = '{"choices":[{"delta":' })
        assert.matches("killed: deadline", killed)
        assert.is_nil(killed:find("choices", 1, true))
        assert.is_nil(killed:find("nil", 1, true))
    end)

    it("bounds the detail so a huge body cannot flood the notice", function()
        local m = notice({ http_status = 500, body = string.rep("x", 5000) })
        assert.is_true(#m < 600)
    end)

    it("degrades safely with no detail at all", function()
        assert.matches("provider request failed", notice({ http_status = 500 }))
        assert.matches("provider request failed", notice(nil))
    end)
end)
