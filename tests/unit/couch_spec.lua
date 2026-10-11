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
-- Runs only inside a pair slot with couch reachable; pending elsewhere.
describe("couch conformance (live)", function()
    it("the real --actors JSON binds this thread by Scope and Tag", function()
        local thread = couch.thread()
        if not thread or vim.fn.executable("couch") == 0 then
            pending("not inside a pair slot")
            return
        end
        local out = vim.system({ "couch", "--actors", "--json" }, { text = true }):wait(10000)
        local ok, data = pcall(vim.json.decode, out.stdout or "", { luanil = { object = true, array = true } })
        if out.code ~= 0 or not ok or type(data) ~= "table" or data.Code ~= "ok" then
            pending("couch unreachable here")
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
