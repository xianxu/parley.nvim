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
    local real_system, saved_deadline
    local arrival = require("tests.helpers.arrival")
    before_each(function() real_system, saved_deadline = vim.system, couch.DEADLINE_MS end)
    after_each(function() vim.system, couch.DEADLINE_MS = real_system, saved_deadline end)

    -- The options vim.system got for one run.
    local function spawned_with(options)
        local seen
        vim.system = function(_, opts) seen = opts; return {} end
        couch.run({ "couch", "--actors", "--json" }, function() end, options)
        return seen
    end

    it("defaults to the submit budget, keeps an explicit one, and leaves a self-bounded caller alone", function()
        assert.equals(require("parley.config").agentic_submit_timeout_ms, couch.DEADLINE_MS)
        assert.equals(couch.DEADLINE_MS, spawned_with(nil).timeout)
        assert.equals(couch.DEADLINE_MS, spawned_with({ env = { A = "1" } }).timeout)
        assert.equals(5000, spawned_with({ timeout = 5000 }).timeout)
        assert.is_nil(spawned_with({ timeout = false }).timeout)
        assert.is_true(spawned_with(nil).text)
    end)

    it("kills a hung child at the deadline; the callback fires once, as timed out", function()
        couch.DEADLINE_MS = 100
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

    it("reads only a deadline kill as timed out", function()
        assert.is_true(couch.timed_out({ code = 124, signal = 15 }))
        assert.is_false(couch.timed_out({ code = 124, signal = 0 }))
        assert.is_false(couch.timed_out({ code = 1, signal = 15 }))
        assert.is_false(couch.timed_out({ code = 0, signal = 0 }))
    end)
end)
