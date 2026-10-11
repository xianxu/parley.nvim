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
