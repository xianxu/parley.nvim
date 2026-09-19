-- #261 M5 Task 5.2: every refusal literal a producer emits has words in
-- lua/parley/refusal.lua (TOKENS or INTERNAL), or is listed below as not a
-- refusal with its reason. The prefixes live only in refusal.lua.
local R = require("parley.refusal")

local FILES = { "lua/parley/document/state.lua", "lua/parley/document/init.lua", "lua/parley/document/user_edits.lua",
    "lua/parley/generation_runner.lua", "lua/parley/generation.lua", "lua/parley/response_submission.lua",
    "lua/parley/response_target.lua", "lua/parley/response_session.lua", "lua/parley/response_provider.lua",
    "lua/parley/batch.lua", "lua/parley/batch_response.lua", "lua/parley/tasker.lua", "lua/parley/dispatcher.lua",
    "lua/parley/chat_respond.lua", "lua/parley/llm_readiness.lua" }
local FORMS = { "reject%(%s*(['\"])(.-)%1", "reject%(%s*[%w_]+%s*,%s*(['\"])(.-)%1",
    "return%s+nil%s*,%s*(['\"])(.-)%1", "reason%s*=%s*(['\"])(.-)%1", "failed%(%s*(['\"])(.-)%1", "fail%(%s*(['\"])(.-)%1", "start_error%(%s*(['\"])(.-)%1",
    "retire%(%s*[%w_]+%s*,%s*['\"][%w_]+['\"]%s*,%s*(['\"])(.-)%1", "cancel%(%s*opts%s*,%s*(['\"])(.-)%1" }

-- Literals the scan finds that no user meets as a refusal.
local WRITE = "a write's validation result; the runner consumes it and the user meets the ending"
local MACHINE = "the pure machine rejecting an event; the runner consumes it and the user meets the ending"
local NOT_REFUSAL = {
    ownership = WRITE, revision = WRITE, identity = WRITE, ["outside grant"] = WRITE, stale = WRITE, busy = WRITE,
    refused = WRITE, ["write turn held elsewhere"] = WRITE,
    ["unconfirmed identity"] = "reclaim_tail's wait-and-retry answer; the runner waits",
    terminal = MACHINE, duplicate = MACHINE, ["turn status"] = MACHINE, preparation = MACHINE, gap = MACHINE,
    output = MACHINE, extend = MACHINE, receipt = MACHINE, revoked = MACHINE, dependency = MACHINE,
    attempt = MACHINE, ["call declaration"] = MACHINE, insert = MACHINE, child = MACHINE, written = MACHINE,
    round = MACHINE, phase = MACHINE, supervision = MACHINE, ["unresolved child outcome"] = MACHINE,
    finalize = MACHINE, ["cancel reason"] = MACHINE, event = MACHINE,
    ["the source buffer no longer exists"] = "llm_readiness without validate_source; a chat passes one, so it never meets this",
    ["the source buffer is not visible in a window"] = "llm_readiness without validate_source, as above",
    [" .. tostring(qt.stop_reason) .. "] = "not a token: a concatenated diagnostic the scan's quotes catch",
}

-- A reason composed at run time has no literal to key. One that starts with a
-- literal is keyed by it, so the literal must be a lead-in ending in ": " (see
-- `row_of` in refusal.lua). One that starts with a variable is declared here:
-- its suffix, and every value the variable takes.
local HEADS = { "reject%(%s*", "reject%(%s*[%w_]+%s*,%s*", "return%s+nil%s*,%s*", "reason%s*=%s*", "[^%w_]failed%(%s*",
    "[^%w_]fail%(%s*", "start_error%(%s*", "cancel%(%s*opts%s*,%s*" }
local COMPOSED = {
    [" missing"] = { "question", "context" }, [" obsolete"] = { "question", "context" },
    [" changed"] = { "question", "context" }, -- batch.lua's validate: check(..., 'question'|'context', ...)
    [" adapter required"] = { "prepare", "request", "finalize" }, -- response_submission.lua's adapter loop
}
local function compositions()
    local leads, variables = {}, {}
    for _, file in ipairs(FILES) do
        for n, line in ipairs(vim.fn.readfile(file)) do
            if not line:match("^%s*%-%-") then
                for _, head in ipairs(HEADS) do
                    for _, literal in line:gmatch(head .. "(['\"])(.-)%1%s*%.%.") do
                        leads[#leads + 1] = { site = file .. ":" .. n, literal = literal }
                    end
                    for _, suffix in line:gmatch(head .. "[%w_%.]+%s*%.%.%s*(['\"])(.-)%1") do
                        variables[#variables + 1] = { site = file .. ":" .. n, suffix = suffix }
                    end
                end
            end
        end
    end
    return leads, variables
end

local function scan()
    local found = {}
    for _, file in ipairs(FILES) do
        for n, line in ipairs(vim.fn.readfile(file)) do
            if not line:match("^%s*%-%-") then
                for _, form in ipairs(FORMS) do
                    for _, literal in line:gmatch(form) do
                        found[literal] = found[literal] or (file .. ":" .. n)
                    end
                end
            end
        end
    end
    return found
end

describe("arch: every refusal token has words", function()
    local found = scan()
    it("finds the literals, so it cannot pass vacuously", function()
        local count = 0
        for _ in pairs(found) do count = count + 1 end
        assert.is_true(count >= 100, "found only " .. count .. " literals")
    end)
    it("gives each one words, or a reason it is not a refusal", function()
        local missing = {}
        for literal, site in pairs(found) do
            if not (R.TOKENS[literal] or R.INTERNAL[literal] or NOT_REFUSAL[literal]) then
                missing[#missing + 1] = site .. ": " .. literal
            end
        end
        table.sort(missing)
        assert.same({}, missing, "add the token to refusal.lua TOKENS or INTERNAL")
    end)
    it("keys every composed reason", function()
        local leads, variables = compositions()
        assert.is_true(#leads >= 3 and #variables >= 5, "the composition scan found too little")
        local bad = {}
        for _, lead in ipairs(leads) do
            if lead.literal:sub(-2) ~= ": " then bad[#bad + 1] = lead.site .. ": lead-in without ': ': " .. lead.literal end
        end
        for _, variable in ipairs(variables) do
            local values = COMPOSED[variable.suffix]
            if not values then bad[#bad + 1] = variable.site .. ": undeclared composition ..'" .. variable.suffix .. "'" end
            for _, value in ipairs(values or {}) do
                local token = value .. variable.suffix
                if not (R.TOKENS[token] or R.INTERNAL[token]) then bad[#bad + 1] = variable.site .. ": no words for " .. token end
            end
        end
        table.sort(bad)
        assert.same({}, bad)
    end)
    it("keeps the prefixes in refusal.lua alone", function()
        local arch = require("tests.arch.arch_helper")
        local found_prefix = {}
        for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
            if file ~= "lua/parley/refusal.lua" then
                local text = table.concat(vim.fn.readfile(file), "\n")
                for _, prefix in pairs(R.PREFIX) do
                    if text:find(prefix, 1, true) then found_prefix[#found_prefix + 1] = file .. ": " .. prefix end
                end
            end
        end
        table.sort(found_prefix)
        assert.same({}, found_prefix, "say it through refusal.describe")
    end)
end)
