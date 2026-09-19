-- One vocabulary for every refusal a user can meet (#261 M5). Producers keep
-- their tokens, because control flow reads several of them; this module owns
-- the words. Pure: it returns the message, and the caller logs it.
--
-- `describe(kind, outcome, failure, detail)` looks up the `failure` token first
-- (a provider failure, a user's Stop), then the outcome, then says the token is
-- unexpected. Every literal a producer emits is keyed here, or listed as not a
-- refusal in tests/arch/refusal_vocabulary_spec.lua, which scans for them.
local M = {}

-- The one statement of each refusal kind's lead-in.
M.PREFIX = {
    start = "Response not started",
    resume = "Response not resumed",
    batch_start = "Batch not started",
    batch_resume = "Batch not resumed",
    batch_paused = "Batch paused",
    ended = "Response stopped",
    drill = "Drill-in stopped",
}

-- The failure a user's own Stop carries: it is not a refusal, so no message.
M.USER_STOP = "operator stopped response"

local AGAIN = "submit again"
local MOMENT = "try again in a moment"

-- token -> {what, action}. `what` says what happened; `action` says what to do,
-- naming only commands that exist.
M.TOKENS = {
    -- Capacity: a slot is held by work still running.
    ["generation limit"] = { what = "four responses are already running in this chat",
        action = "wait for one to finish, or stop one with :ParleyStop" },
    ["process generation limit"] = { what = "sixteen responses are already running across Neovim",
        action = "wait for one to finish, or stop one with :ParleyStop" },
    ["task start rejected: process admission capacity"] = { what = "too many processes are already running",
        action = "wait for one to finish, or stop one with :ParleyStop" },
    ["task start rejected: owner is busy"] = { what = "this request is still running",
        action = "wait for it to finish, or stop it with :ParleyStop" },
    ["target limit"] = { what = "four responses are already waiting to start in this chat",
        action = "wait for one to start, or stop one with :ParleyStop" },
    ["grant limit"] = { what = "this chat holds too many answers being written",
        action = "wait for one to finish, or stop one with :ParleyStop" },
    ["capacity"] = { what = "too many edits are pending in this chat", action = MOMENT },
    ["dependency limit"] = { what = "the question depends on too many earlier parts of the chat",
        action = "edit the chat down, or branch it, then submit again" },
    ["preparation region limit"] = { what = "the answer being replaced is split into too many pieces",
        action = "edit the answer into one block, then submit again" },
    ["overlap"] = { what = "another response is already writing this answer",
        action = "wait for it to finish, or stop it with :ParleyStop, then submit again" },
    ["entity row overlap"] = { what = "another response is already writing this answer",
        action = "wait for it to finish, or stop it with :ParleyStop, then submit again" },
    -- The chat changed underneath the request.
    ["detached"] = { what = "the chat was closed", action = "reopen the chat and submit again" },
    ["epoch"] = { what = "the chat was reloaded", action = AGAIN },
    ["document changed"] = { what = "the chat changed before the request could start", action = AGAIN },
    ["source changed"] = { what = "the question was edited before the request could start", action = AGAIN },
    ["validation interrupted by edits"] = { what = "the chat was edited while the batch was checked", action = AGAIN },
    ["context changed"] = { what = "an earlier question or answer changed", action = AGAIN },
    ["unconfirmed entity"] = { what = "the chat is still being read", action = MOMENT },
    ["unconfirmed line end"] = { what = "the chat is still being read", action = MOMENT },
    ["uncertain"] = { what = "the chat is still being read", action = MOMENT },
    ["waiting"] = { what = "the chat is still being read", action = MOMENT },
    ["query owner inactive"] = { what = "the response was stopped before its request started", action = AGAIN },
    -- Nothing to submit.
    ["no question selected"] = { what = "the cursor is not on a question",
        action = "edit: put the cursor on a 💬: question, then submit again" },
    ["no questions selected"] = { what = "no question is in the selection",
        action = "edit: select the 💬: questions to answer, then submit again" },
    ["question missing"] = { what = "the question was deleted", action = "edit: write the question, then submit again" },
    ["question unavailable"] = { what = "the question could not be found", action = AGAIN },
    ["question identity unavailable"] = { what = "the chat is still being read", action = MOMENT },
    ["chat header unavailable"] = { what = "the chat has no header",
        action = "edit: restore the chat's header, then submit again" },
    ["document structure unavailable"] = { what = "the chat is still being read", action = MOMENT },
    ["captured batch context unavailable"] = { what = "a question in the batch was deleted", action = AGAIN },
    ["no batch in this chat"] = { what = "there is no batch to resume", action = ":ParleyChatRespondAll to start one" },
    ["Choose a model before submitting"] = { what = "no model is chosen", action = ":ParleyAgent to choose one" },
    -- Resume.
    ["no stale continuation ready"] = { what = "the response is not paused on a changed input",
        action = ":ParleyChatRespond to start a new one" },
    ["response changed"] = { what = "the paused response has moved on", action = ":ParleyChatRespond to start a new one" },
    ["output ownership changed"] = { what = "the answer was edited while paused",
        action = ":ParleyChatRespond to start a new one" },
    ["target unavailable"] = { what = "the answer being continued is gone", action = ":ParleyChatRespond to start a new one" },
    ["resume"] = { what = "the response is not paused", action = ":ParleyChatRespond to start a new one" },
    ["not paused"] = { what = "the batch is not paused", action = ":ParleyChatRespondAll to start one" },
    ["not ready"] = { what = "the batch is still starting", action = MOMENT },
    ["validation pending"] = { what = "the batch is still being checked", action = MOMENT },
    ["leg unresolved"] = { what = "the batch's current answer is still being cleaned up", action = MOMENT },
    ["unknown effect"] = { what = "a tool's effect in the batch is unknown",
        action = ":ParleyToolOperations to record what happened" },
    ["not cancellable"] = { what = "the batch has already finished", action = ":ParleyChatRespondAll to start one" },
    ["not running"] = { what = "the response has already ended", action = AGAIN },
    ["disposed"] = { what = "the batch has already ended", action = ":ParleyChatRespondAll to start one" },
    -- Preparation.
    ["input preparation failed"] = { what = "the request could not be built", action = AGAIN },
    ["preparation resolved without input"] = { what = "the request could not be built", action = AGAIN },
    ["invalid prepared input"] = { what = "the request could not be built", action = AGAIN },
    ["preparation override changed captured geometry"] = { what = "the answer changed while the request was built",
        action = AGAIN },
    ["task start rejected: its generation has already stopped"] = { what = "the response was stopped before this step",
        action = AGAIN },
    ["task start rejected: a process outside a generation needs deadline_ms"] = { what = "a helper process could not start",
        action = AGAIN },
    ["task start failed: "] = { what = "a process could not start", action = "try again in a moment; if it persists, check the command is installed" },
    ["target step failed: "] = { what = "the response could not find its answer", action = AGAIN },
    -- Terminal outcomes. `revoked` depends on the cause (see `describe`).
    ["cancelled"] = { what = "the response was cancelled", action = AGAIN },
    ["overflow"] = { what = "the response produced output faster than the chat could take it", action = AGAIN },
    ["provider_failed"] = { what = "the model's request failed", action = AGAIN },
    ["prepare_failed"] = { what = "the request could not be built", action = AGAIN },
    ["finalize_failed"] = { what = "the answer was written, but the next question prompt could not be added",
        action = "edit: add the 💬: prompt yourself" },
    ["fault"] = { what = "an internal step failed, so the response was ended", action = AGAIN },
    ["start refused"] = { what = "the response could not start", action = AGAIN },
    ["completion refused"] = { what = "the next question prompt could not be added", action = "edit: add the 💬: prompt yourself" },
}

-- Reachable only through a programming error: the message says so and points
-- at the log.
M.INTERNAL = {}
for _, token in ipairs({
    "invalid event", "invalid stale evidence", "invalid dependency", "invalid input snapshot", "generation",
    "invalid region", "invalid edit", "invalid uncertainty", "invalid proofs", "grant", "invalid epoch",
    "unknown event", "coordinator-owned event", "invalid released insertion", "row slice limit", "cannot narrow grant",
    "operation", "range", "anchor", "successor", "patch", "overlapping patches",
    "prepare/request/finalize adapters required", "invalid specification", "invalid staging limit",
    "invalid queue limit", "invalid preparation region", "invalid target", "invalid callbacks",
    "preparation and payload builders required", "revision unavailable", "wrong scope", "stale leg",
    "missing outcome", "missing context revision", "invalid context status", "invalid process limits",
    "invalid process limit: ", "task start rejected: invalid process options",
    "chat_path not supplied to build_messages", "chat path has no directory: ", "missing ",
}) do M.INTERNAL[token] = true end

-- What a revocation means depends on why it happened.
M.REVOKED = {
    edit = { what = "you edited the answer while it was being written; the partial answer is kept",
        action = "submit again to regenerate" },
    reload = { what = "the chat was reloaded while the answer was being written", action = AGAIN },
}

-- Tokens whose message names what still holds the slot, when something does.
local CAPACITY = { ["generation limit"] = true, ["process generation limit"] = true,
    ["task start rejected: process admission capacity"] = true }


-- A token that ends in ": " carries detail after it; its row is keyed by the
-- lead-in, and the detail follows the words.
local function row_of(token)
    if type(token) ~= "string" then return nil end
    local row = M.TOKENS[token]
    if row then return row, nil end
    for key, value in pairs(M.TOKENS) do
        if key:sub(-2) == ": " and token:sub(1, #key) == key then return value, token:sub(#key + 1) end
    end
end
local function internal(token)
    if type(token) ~= "string" then return false end
    if M.INTERNAL[token] then return true end
    for key in pairs(M.INTERNAL) do
        if key:sub(-2) == ": " and token:sub(1, #key) == key then return true end
    end
    return false
end

---@param kind string # a PREFIX key
---@param outcome string|nil # a terminal outcome, when the refusal is an ending
---@param failure string|nil # the producer's token
---@param detail table|nil # {cause = 'edit'|'reload'|'detach', held = tasker.held(), notice = string,
---  log_file = the Parley log's path, named when the token is unexpected}
---@return string|nil # the message, or nil when there is nothing to say
function M.describe(kind, outcome, failure, detail)
    detail = detail or {}
    if failure == M.USER_STOP then return nil end
    local prefix = M.PREFIX[kind] or tostring(kind)
    local log = "the details are in " .. (detail.log_file or "the Parley log")
    local text
    if outcome == "revoked" and failure == nil then
        if detail.cause == "detach" then return nil end
        local row = M.REVOKED[detail.cause]
        text = row and (row.what .. "; " .. row.action)
    end
    if not text then
        local token = failure or outcome
        local row, extra = row_of(token)
        if not row and failure and outcome then row, extra = row_of(outcome) end
        if row then
            text = row.what .. (extra and extra ~= "" and (" (" .. extra .. ")") or "") .. "; " .. row.action
            if CAPACITY[token] and type(detail.held) == "table" and #detail.held > 0 then
                local pids = {}
                for _, held in ipairs(detail.held) do pids[#pids + 1] = tostring(held.pid) end
                text = text .. "; still running after Stop: pid " .. table.concat(pids, ", ")
            end
        elseif internal(token) then
            text = "an unexpected internal error (" .. tostring(token) .. "); " .. log
        else
            text = "unexpected (" .. tostring(token) .. "); " .. log
        end
    end
    if type(detail.notice) == "string" and detail.notice ~= "" then text = text .. " — " .. detail.notice end
    return prefix .. ": " .. text
end

return M
