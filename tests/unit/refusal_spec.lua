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
    -- An unknown token is a defect, so `describe` records it and, under the
    -- harness, fails where it is produced. A spec that means to pass one says so
    -- (#261 M5 review BR-66).
    it("records a token that has no words, and fails the harness unless allowed", function()
        R.forget_unkeyed()
        assert.has_error(function() R.describe("start", nil, "never heard of it") end)
        assert.same({ "never heard of it" }, R.unkeyed(), "recorded before it throws")
        R._allow_unkeyed = false
        -- Free text under a known outcome is that outcome's detail, not a
        -- missing row: recorded, and never a failure.
        R.describe("ended", "provider_failed", "provider request failed (HTTP 503)")
        assert.same({ "never heard of it" }, R.unkeyed())
        assert.same({ "provider request failed (HTTP 503)" }, R.detail_tokens())
        R.forget_unkeyed()
    end)
    it("calls an internal token and an unknown one unexpected, showing the token and the log", function()
        R._allow_unkeyed = true
        local internal = R.describe("start", nil, "invalid specification", { log_file = "/x/parley.log" })
        assert.truthy(internal:find("unexpected", 1, true)); assert.truthy(internal:find("invalid specification", 1, true))
        assert.truthy(internal:find("/x/parley.log", 1, true))
        local unknown = R.describe("start", nil, "never heard of it")
        assert.truthy(unknown:find("unexpected", 1, true)); assert.truthy(unknown:find("never heard of it", 1, true))
        R._allow_unkeyed = false; R.forget_unkeyed()
    end)
    -- BR-67: naming a command that cannot clear the condition is worse than
    -- naming none. Nothing clears a batch's `unknown`, and a batch whose
    -- captured question is gone can never resume, so both say: start a new one.
    it("points a batch that cannot continue at a new batch", function()
        for _, token in ipairs({ "unknown effect", "question obsolete", "question missing",
            "context missing", "context obsolete", "captured batch context unavailable" }) do
            local row = assert(R.TOKENS[token], token)
            assert.truthy(row.action:find(":ParleyChatRespondAll", 1, true) or row.action:find("submit again", 1, true),
                token .. " names " .. row.action)
        end
        assert.truthy(R.TOKENS["unknown effect"].action:find(":ParleyChatRespondAll", 1, true))
    end)
    it("names only commands that exist", function()
        local init = table.concat(vim.fn.readfile("lua/parley/init.lua"), "\n")
        local missing = {}
        local function check(action, token)
            for name in tostring(action):gmatch(":Parley(%u[%w_]*)") do
                if not init:find("M.cmd." .. name, 1, true) then missing[#missing + 1] = token .. " -> :Parley" .. name end
            end
        end
        for token, row in pairs(R.TOKENS) do check(row.action, token) end
        for cause, row in pairs(R.REVOKED) do check(row.action, cause) end
        check(R.BATCH_CONTINUE, "BATCH_CONTINUE"); check(R.BATCH_RESTART, "BATCH_RESTART")
        table.sort(missing)
        assert.same({}, missing)
    end)
    -- BR-68: the cause is the more specific fact, and outranks a failure the
    -- stop recorded on its way to the terminal.
    it("words a revocation by its cause even when a failure came with it", function()
        assert.equals("Response stopped: you edited the answer while it was being written; the partial answer is kept;"
            .. " submit again to regenerate",
            R.describe("ended", "revoked", "cancel adapter missing; operation unresolved", { cause = "edit" }))
        assert.is_nil(R.describe("ended", "revoked", "adapter failed", { cause = "detach" }))
    end)
    -- BR-65: an internal token never erases a known outcome's words; it adds the log.
    it("keeps the outcome's words when its failure is internal", function()
        assert.equals("Response stopped: the answer was written, but the next question prompt could not be added;"
            .. " edit: add the 💬: prompt yourself; the details are in /x/parley.log",
            R.describe("ended", "finalize_failed", "invalid completion", { log_file = "/x/parley.log" }))
    end)
    it("names the pid still held after Stop on the three capacity refusals", function()
        for _, token in ipairs({ "generation limit", "process generation limit",
            "task start rejected: process admission capacity" }) do
            local message = R.describe("start", nil, token, { held = { { pid = 4242 } } })
            assert.truthy(message:find("still running after Stop: pid 4242", 1, true), message)
            assert.is_nil(R.describe("start", nil, token, { held = {} }):find("pid", 1, true))
        end
    end)
    -- A batch continues or starts over rather than submitting: the host names that.
    it("uses the host's action in place of the row's", function()
        assert.equals("Batch paused: its current response stopped; " .. R.BATCH_CONTINUE .. " — 1 of 3 questions answered",
            R.describe("batch_paused", nil, "leg stopped", { action = R.BATCH_CONTINUE, notice = "1 of 3 questions answered" }))
        assert.equals("Batch stopped: the chat was reloaded; " .. R.BATCH_RESTART,
            R.describe("batch_ended", nil, "epoch", { action = R.BATCH_RESTART }))
    end)
    it("carries the detail after a token that ends in ': '", function()
        local message = R.describe("start", nil, "task start failed: ENOENT")
        assert.truthy(message:find("(ENOENT)", 1, true), message)
    end)
end)
