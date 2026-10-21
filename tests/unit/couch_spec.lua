-- #316: this editor's slot is the actor bound to its COUCH_THREAD_SCOPE/TAG.
local couch = require("parley.couch")

local actors = {
    { Binding = { Slot = "ariadne:2", Scope = "s2", Tag = "t2" } },
    { Binding = { Slot = "parley.nvim:1", Scope = "s1", Tag = "t1" } },
    "junk",
}

describe("couch.own_actor", function()
    it("matches the thread by scope and tag", function()
        assert.equals("ariadne:2", couch.slot(couch.own_actor(actors, { scope = "s2", tag = "t2" })))
    end)

    it("is nil with no thread, or when only one of scope/tag matches", function()
        assert.is_nil(couch.own_actor(actors, nil))
        assert.is_nil(couch.own_actor(actors, { scope = "s2", tag = "t1" }))
        assert.is_nil(couch.own_actor(nil, { scope = "s2", tag = "t2" }))
    end)
end)

describe("couch.same", function()
    it("compares the bound thread, not the address spelling", function()
        assert.is_true(couch.same(actors[2], couch.find_actor(actors, "parley:1")))
        assert.is_false(couch.same(actors[1], actors[2]))
        assert.is_false(couch.same(nil, nil))
    end)
end)

-- ARCH-MOCK conformance (#316 close review): the fakes hand-write the
-- --actors JSON; against the real couch, this editor's thread must resolve.
-- Live only by opt-in (#365): `make check-couch-actors-live` sets
-- PARLEY_LIVE_COUCH, the one way the real thread reaches a spec, and runs this
-- file alone. The suite strips the flag, so here it is pending.
local function real_couch()
    -- The sentinel (tests/fixtures/sentinel-bin) shadows a bare `couch`.
    for dir in (vim.env.PATH or ""):gmatch("[^:]+") do
        local path = dir .. "/couch"
        if not dir:find("/tests/fixtures/sentinel-bin", 1, true) and vim.fn.executable(path) == 1 then return path end
    end
end

describe("couch conformance (live)", function()
    it("the real --actors JSON binds this thread by Scope and Tag", function()
        local thread, binary = couch.thread(), real_couch()
        if vim.env.PARLEY_LIVE_COUCH ~= "1" or not thread or not binary then
            pending("live only: make check-couch-actors-live, inside a pair slot")
            return
        end
        -- #366: the operator's data home for this one call; the spec stays isolated.
        local out = vim.system({ binary, "--actors", "--json" },
            { text = true, env = { XDG_DATA_HOME = vim.env.PARLEY_LIVE_COUCH_DATA_HOME } }):wait(10000)
        local ok, data = pcall(vim.json.decode, out.stdout or "", { luanil = { object = true, array = true } })
        if out.code ~= 0 or not ok or type(data) ~= "table" or data.Code ~= "ok" then
            pending(("couch unreachable here (exit %s): %s"):format(out.code,
                ((out.stderr or ""):match("[^\n]+") or (out.stdout or ""):match("[^\n]+") or "no output")))
            return
        end
        local own = couch.own_actor(data.Actors, thread)
        assert.is_not_nil(own, "no actor bound to this thread")
        assert.truthy((couch.slot(own) or ""):match("^.+:%d+$"))
    end)
end)

describe("couch.thread", function()
    local saved
    before_each(function() saved = { vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG } end)
    after_each(function() vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = saved[1], saved[2] end)

    it("reads the pair-launched env; nil when either is unset", function()
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = "s", "t"
        assert.same({ scope = "s", tag = "t" }, couch.thread())
        vim.env.COUCH_THREAD_TAG = nil
        assert.is_nil(couch.thread())
    end)
end)

-- #400: no couch child lives forever.
describe("couch.run deadline", function()
    local real_system, saved_deadline, saved_config
    local arrival = require("tests.helpers.arrival")
    local p = require("parley")
    before_each(function()
        p.config = p.config or {}
        real_system, saved_deadline, saved_config = vim.system, couch.deadline_ms, p.config.agentic_submit_timeout_ms
    end)
    after_each(function()
        vim.system, couch.deadline_ms, p.config.agentic_submit_timeout_ms = real_system, saved_deadline, saved_config
    end)

    -- The options vim.system got for one run.
    local function spawned_with(options)
        local seen
        vim.system = function(_, opts) seen = opts; return {} end
        couch.run({ "couch", "--actors", "--json" }, function() end, options)
        return seen
    end

    it("defaults to the submit budget, keeps an explicit one, and leaves a self-bounded caller alone", function()
        p.config.agentic_submit_timeout_ms = nil
        local shipped = require("parley.config").agentic_submit_timeout_ms
        assert.equals(shipped, spawned_with(nil).timeout)
        assert.equals(shipped, spawned_with({ env = { A = "1" } }).timeout)
        assert.equals(5000, spawned_with({ timeout = 5000 }).timeout)
        assert.is_nil(spawned_with({ timeout = false }).timeout)
        assert.is_true(spawned_with(nil).text)
    end)

    it("follows the user's submit budget, read per call", function()
        p.config.agentic_submit_timeout_ms = 40000
        assert.equals(40000, spawned_with(nil).timeout)
        p.config.agentic_submit_timeout_ms = 7000
        assert.equals(7000, spawned_with(nil).timeout)
    end)

    it("kills a hung child at the deadline; the callback fires once, as timed out", function()
        couch.deadline_ms = function() return 100 end
        local results = {}
        couch.run({ "sleep", "30" }, function(obj) results[#results + 1] = obj end)
        assert.is_true(vim.wait(arrival.MS, function() return #results > 0 end))
        vim.wait(200) -- absence: no second delivery
        assert.equals(1, #results)
        assert.is_true(couch.timed_out(results[1]))
    end)

    it("delivers once when the kill and a normal exit both report", function()
        local results = {}
        vim.system = function(_, _, on_exit)
            on_exit({ code = 124, signal = 15 })
            on_exit({ code = 0, signal = 0, stdout = "late" })
            return {}
        end
        couch.run({ "couch", "--actors" }, function(obj) results[#results + 1] = obj end)
        vim.wait(100) -- absence: the second report stays dropped
        assert.equals(1, #results)
        assert.equals(124, results[1].code)
    end)

    it("gives a send three submit deadlines, and a killed send logs its delivery once", function()
        p.config.agentic_submit_timeout_ms = 2000
        local seen, logged, results = nil, {}, {}
        vim.system = function(_, opts, on_exit) seen = opts; on_exit({ code = 124, signal = 15 }); return {} end
        local logger = require("parley.logger")
        local warn = logger.warning
        logger.warning = function(msg) logged[#logged + 1] = msg end
        couch.send("ops:0", "submitted: /x.md\nsecond line", function(obj) results[#results + 1] = obj end)
        local ok = vim.wait(arrival.MS, function() return #results > 0 end)
        logger.warning = warn
        assert.is_true(ok)
        assert.equals(6000, seen.timeout)
        assert.same({ 'couch send killed at its deadline: to=ops:0 message="submitted: /x.md" not confirmed within 6 s; it may have arrived' }, logged)
        assert.equals("not confirmed within 6 s; it may have arrived", results[1].stderr)
    end)

    it("reads only a deadline kill as timed out", function()
        assert.is_true(couch.timed_out({ code = 124, signal = 15 }))
        assert.is_true(couch.timed_out({ code = 124, signal = 0 })) -- trapped TERM, exited 0
        assert.is_false(couch.timed_out({ code = 1, signal = 15 }))
        assert.is_false(couch.timed_out({ code = 0, signal = 0 }))
    end)
end)


-- #408: the synchronous registry transaction admits input only on a proved ack.
describe("couch operator transaction", function()
    local identity = { ID = "doc-408", File = "/scratch/doc.md" }
    local token = string.rep("a", 32)
    local text = "holder: operator\ndocument: doc-408\nturn: " .. token .. "\ntime: now\n"
    local function result(state)
        return { code = 0, stdout = vim.json.encode({ Code = "ok", OperatorLock = {
            ID = identity.ID, File = identity.File, Turn = token, Holder = "operator",
            LockPath = identity.File .. ".lock", LockText = text, State = state or "acquired",
        } }) }
    end
    local function decoded(obj) return vim.json.decode(obj.stdout) end
    local function evaluate(data, verb)
        return couch.operator_result({code = 0, stdout = vim.json.encode(data)}, verb or "acquire", identity, token)
    end

    it("accepts acquire and idempotent retry only with exact ownership proof", function()
        for _, state in ipairs({"acquired", "already-held"}) do
            local obj = result(state)
            local answer = couch.operator_result(obj, "acquire", identity, token)
            assert.equals("confirmed", answer.kind)
            assert.same(decoded(obj).OperatorLock, answer.lock)
        end
    end)

    it("accepts release and absent release without claiming acquire ownership", function()
        for _, state in ipairs({"released", "already-released"}) do
            assert.equals("confirmed", evaluate({Code = "ok", OperatorLock = {
                ID = identity.ID, File = identity.File, Turn = token, State = state,
            }}, "release").kind)
        end
    end)

    it("parses only single exact proof fields with a lowercase 32-hex turn", function()
        assert.same({ID = identity.ID, Turn = token}, couch.operator_proof(text))
        for _, bad in ipairs({
            text .. "document: doc-408\n", text .. "holder: operator\n", text .. "turn: " .. token .. "\n",
            text:gsub("holder: operator", "holder: agent"), text:gsub("document: doc%-408", "document:"),
            text:gsub(token, string.rep("A", 32)), text:gsub(token, "abc"),
            text:gsub("turn:", "turn :"), text:gsub("document:", " document:"),
        }) do assert.is_nil(couch.operator_proof(bad), bad) end
        assert.is_nil(couch.operator_proof(nil))
    end)

    it("refuses malformed, foreign and mismatched acquire acknowledgments", function()
        for _, change in ipairs({
            {"ID", "other"}, {"File", "/other.md"}, {"Turn", string.rep("b", 32)},
            {"Holder", "agent"}, {"LockPath", "/other.lock"}, {"State", "released"},
            {"LockText", text:gsub("doc%-408", "other")}, {"LockText", text .. "turn: " .. token .. "\n"},
            {"LockText", false},
        }) do
            local data = decoded(result())
            data.OperatorLock[change[1]] = change[2]
            assert.equals("refused", evaluate(data).kind, change[1])
        end
        for _, data in ipairs({{}, {Code = "ok"}, {Code = "ok", OperatorLock = "junk"}, {Code = "not-ok"}}) do
            assert.equals("refused", evaluate(data).kind)
        end
        assert.equals("refused", couch.operator_result({code = 0, stdout = "bad json"}, "acquire", identity, token).kind)
        assert.equals("refused", couch.operator_result(result(), "unknown", identity, token).kind)
        assert.equals("refused", couch.operator_result(result(), "acquire", identity, "bad").kind)
    end)

    it("allows degradation only for timeout or the exact unavailable exit and code", function()
        for _, case in ipairs({
            {124, "", "unavailable"}, {7, "session-sync-unavailable", "unavailable"},
            {1, "session-sync-unavailable", "refused"}, {7, "operator-lock", "refused"},
            {3, "operator-lock", "refused"}, {1, "operator-lock-uncertain", "refused"},
            {1, "operator-invalid", "refused"}, {2, "usage", "refused"},
            {-1, "", "refused"}, {1, "ok", "refused"},
        }) do
            local answer = couch.operator_result({code = case[1], stdout = vim.json.encode({Code = case[2]})},
                "acquire", identity, token)
            assert.equals(case[3], answer.kind)
            assert.equals("string", type(answer.error))
        end
    end)

    it("passes the fixed child and wait budget with canonical identity and turn", function()
        local original = vim.system
        local argv, opts, waited
        vim.system = function(a, o)
            argv, opts = a, o
            return {wait = function(_, timeout) waited = timeout; return result() end}
        end
        local ok, answer = pcall(couch.operator_lock, "acquire", identity, token)
        vim.system = original
        assert.is_true(ok)
        assert.equals("confirmed", answer.kind)
        assert.same({"couch", "--session-sync", "operator-acquire", identity.File,
            "--id", identity.ID, "--turn", token, "--json"}, argv)
        assert.equals(500, couch.OPERATOR_LOCK_TIMEOUT_MS)
        assert.equals(500, opts.timeout)
        assert.equals(500, waited)
        assert.is_true(opts.text)
    end)

    it("refuses spawn failures instead of treating missing binaries as permission", function()
        local original = vim.system
        vim.system = function() error("missing couch executable") end
        local ok, answer = pcall(couch.operator_lock, "acquire", identity, token)
        vim.system = original
        assert.is_true(ok)
        assert.equals("refused", answer.kind)
        assert.matches("missing couch", answer.error)
    end)

    it("kills and reaps a real hung child within the named input budget", function()
        local original, child = vim.system
        vim.system = function(_, opts)
            child = original({"sleep", "30"}, opts)
            return child
        end
        local started = vim.uv.hrtime()
        local ok, answer = pcall(couch.operator_lock, "acquire", identity, token)
        local elapsed = (vim.uv.hrtime() - started) / 1e6
        vim.system = original
        assert.is_true(ok)
        assert.equals("unavailable", answer.kind)
        assert.is_true(elapsed >= 400, tostring(elapsed))
        assert.is_true(elapsed < 1500, tostring(elapsed))
        assert.equals(124, child:wait().code)
    end)
end)
