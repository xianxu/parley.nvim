-- #261 M5: one vocabulary for every refusal a user can meet.
local R = require("parley.refusal")
-- This spec describes tokens that have no words on purpose; the harness watch
-- in tests/minimal_init.vim fails any other spec that produces one.
vim.g.parley_expected_unkeyed = { "never heard of it", "provider request failed (HTTP 503)",
    "preparation outside captured output", "brand new reason", "a reason nobody worded" }

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
    -- `describe` stays pure and keeps no state: it says how it resolved, and the
    -- harness judges that (tests/minimal_init.vim fails a spec that produces an
    -- `unkeyed` one). #261 M5 review BR-66/BR-71.
    it("says how it resolved, so a caller can judge the words", function()
        local function class(...) local _, resolution = R.describe(...); return resolution end
        assert.equals("keyed", class("start", nil, "generation limit"))
        assert.equals("cause", class("ended", "revoked", nil, { cause = "edit" }))
        assert.equals("silent", class("ended", "cancelled", R.USER_STOP))
        assert.equals("silent", class("ended", "revoked", nil, { cause = "detach" }))
        assert.equals("internal", class("start", nil, "invalid specification"))
        assert.equals("internal", class("ended", "finalize_failed", "invalid completion"))
        assert.equals("unkeyed", class("start", nil, "never heard of it"))
        -- `failure` is a token, always. Free text passed there is a producer
        -- defect, not a detail to print (BR-66); it reaches the user as a notice.
        assert.equals("unkeyed", class("ended", "provider_failed", "provider request failed (HTTP 503)"))
        assert.equals("keyed", class("ended", "provider_failed", nil,
            { notice = "parley: provider request failed (HTTP 503): upstream down" }))
        -- A lifecycle token has one home, whatever the kind that carries it.
        assert.equals("silent", class("start", "start refused", "detach"))
        assert.equals("cause", class("start", "start refused", "reload"))
    end)
    -- Round 2: the harness watch caught `interrupted` from the drill-in. The
    -- class is every status a user edit can end with, not that one token.
    it("has words for every status a user edit ends with", function()
        for _, status in ipairs({ "stale", "refused", "interrupted", "busy", "chunkneeded" }) do
            assert.is_not_nil(R.TOKENS[status], status)
        end
        local statuses = {}
        for _, file in ipairs({ "lua/parley/document/editor.lua", "lua/parley/document/user_edits.lua" }) do
            for _, line in ipairs(vim.fn.readfile(file)) do
                for status in line:gmatch("status%s*=%s*'([%a_]+)'") do statuses[status] = true end
            end
        end
        local missing = {}
        for status in pairs(statuses) do
            if status ~= "applied" and not (R.TOKENS[status] or R.INTERNAL[status]) then
                missing[#missing + 1] = status
            end
        end
        table.sort(missing)
        assert.same({}, missing, "a status a caller can report needs words")
    end)
    -- BR-74: an outcome the machine can stop with has words, checked at load.
    it("has words for every outcome the generation machine stops with", function()
        for outcome in pairs(require("parley.generation").OUTCOMES) do
            assert.is_true(outcome == "success" or R.TOKENS[outcome] ~= nil, outcome)
        end
    end)
    it("calls an internal token unexpected, showing the token and the log", function()
        local internal = R.describe("start", nil, "invalid specification", { log_file = "/x/parley.log" })
        assert.truthy(internal:find("unexpected", 1, true)); assert.truthy(internal:find("invalid specification", 1, true))
        assert.truthy(internal:find("/x/parley.log", 1, true))
    end)
    -- BR-92: a reason nobody worded still leaves the user an action. It becomes
    -- the detail beside the KIND's words, and the caller hears "unkeyed".
    it("gives an unworded reason an action, and keeps it as the detail", function()
        local message, resolution = R.describe("start", nil, "preparation outside captured output")
        -- The prefix already says what happened, so the floor adds only the
        -- action (#261 close: BR-97).
        assert.equals("Response not started: submit again — preparation outside captured output", message)
        assert.equals("unkeyed", resolution)
        -- Every kind has that floor, so no prefix can reach a user without one.
        for kind in pairs(R.PREFIX) do
            assert.is_not_nil(R.KIND_ACTION[kind], kind)
            assert.truthy(R.describe(kind, nil, "brand new reason"):find("brand new reason", 1, true))
        end
    end)
    -- BR-96: the gate PLACES what it demotes. A caller's notice does not
    -- swallow the reason, and a row's own detail is dropped instead of doubling.
    it("keeps both details when a caller's notice meets a demoted reason", function()
        assert.equals("Batch paused: :ParleyChatResumeBatch to continue"
            .. " — 1 of 3 questions answered — a reason nobody worded",
            R.describe("batch_paused", nil, "a reason nobody worded",
                { action = R.BATCH_CONTINUE, notice = "1 of 3 questions answered" }))
        -- A KEYED token's own detail still yields to the notice: one detail, as
        -- BR-65 requires. Only a demoted reason is joined, because dropping it
        -- would lose the only record of what happened.
        assert.equals("Response stopped: the model's request failed; submit again — upstream gone",
            R.describe("ended", "provider_failed", "provider request failed: HTTP 503",
                { notice = "upstream gone" }))
    end)
    -- Provider prose keeps its last line, which often carries the action;
    -- `brief` drops a traceback on purpose, so the two are separate entry points.
    it("folds free text onto one line without losing what follows", function()
        assert.equals("cliproxy: not healthy within 30s — try :ParleyProxy status",
            R.prose("cliproxy: not healthy within 30s\n — try :ParleyProxy status"))
        assert.equals("boom", R.brief("boom\nstack traceback:\n\tfoo"))
        assert.equals("unknown", R.brief(""))
        assert.equals("unknown", R.prose("  \n  "))
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
