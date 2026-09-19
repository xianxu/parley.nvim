-- #261 M5: one vocabulary for every refusal a user can meet.
local R = require("parley.refusal")

describe("refusal vocabulary", function()
    local ACTION = { "^:Parley%u", "submit again", "try again in a moment", "wait for", "edit" }
    it("gives every token words and an action that names something that exists", function()
        for token, row in pairs(R.TOKENS) do
            assert.is_true(type(row.what) == "string" and #row.what > 0, token .. " has no words")
            local ok = false
            for _, pattern in ipairs(ACTION) do if row.action:find(pattern) then ok = true end end
            if not ok then for _, pattern in ipairs(ACTION) do if row.action:find(pattern, 1, true) then ok = true end end end
            assert.is_true(ok, token .. ": action '" .. tostring(row.action) .. "' names nothing a user can do")
        end
    end)
    it("resolves the failure before the outcome", function()
        local message = R.describe("ended", "provider_failed", "no question selected")
        assert.truthy(message:find("cursor is not on a question", 1, true), message)
    end)
    it("says nothing for the user's own Stop, and warns for any other cancel", function()
        assert.is_nil(R.describe("ended", "cancelled", R.USER_STOP))
        assert.truthy(R.describe("ended", "cancelled", nil):find("cancelled", 1, true))
    end)
    it("words a revocation by its cause, and says nothing when the chat was closed", function()
        assert.truthy(R.describe("ended", "revoked", nil, { cause = "edit" }):find("you edited the answer", 1, true))
        assert.truthy(R.describe("ended", "revoked", nil, { cause = "reload" }):find("reloaded", 1, true))
        assert.is_nil(R.describe("ended", "revoked", nil, { cause = "detach" }))
    end)
    it("calls an internal token and an unknown one unexpected, showing the token and the log", function()
        local internal = R.describe("start", nil, "invalid specification", { log_file = "/x/parley.log" })
        assert.truthy(internal:find("unexpected", 1, true)); assert.truthy(internal:find("invalid specification", 1, true))
        assert.truthy(internal:find("/x/parley.log", 1, true))
        local unknown = R.describe("start", nil, "never heard of it")
        assert.truthy(unknown:find("unexpected", 1, true)); assert.truthy(unknown:find("never heard of it", 1, true))
    end)
    it("names the pid still held after Stop on the three capacity refusals", function()
        for _, token in ipairs({ "generation limit", "process generation limit",
            "task start rejected: process admission capacity" }) do
            local message = R.describe("start", nil, token, { held = { { pid = 4242 } } })
            assert.truthy(message:find("still running after Stop: pid 4242", 1, true), message)
            assert.is_nil(R.describe("start", nil, token, { held = {} }):find("pid", 1, true))
        end
    end)
    it("carries the detail after a token that ends in ': '", function()
        local message = R.describe("start", nil, "task start failed: ENOENT")
        assert.truthy(message:find("(ENOENT)", 1, true), message)
    end)
end)
