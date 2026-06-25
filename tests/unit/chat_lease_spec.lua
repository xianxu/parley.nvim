local chat_lease = require("parley.chat_lease")

describe("chat_lease", function()
    before_each(function()
        chat_lease._reset()
    end)

    it("validates the active generation while the changedtick matches", function()
        local gen = chat_lease.begin(7, 10, { query_id = "qid_1", role = "stream" })

        local ok, reason = chat_lease.validate(7, gen, 10)

        assert.is_true(ok)
        assert.is_nil(reason)
        assert.same({ query_id = "qid_1", role = "stream" }, chat_lease.current(7).meta)
    end)

    it("invalidates when the buffer changed outside the guarded path", function()
        local gen = chat_lease.begin(7, 10)

        local ok, reason = chat_lease.validate(7, gen, 11)

        assert.is_false(ok)
        assert.matches("changed", reason)
        assert.is_false(chat_lease.current(7).valid)
    end)

    it("commits Parley-owned writes as the new baseline", function()
        local gen = chat_lease.begin(7, 10)

        assert.is_true(chat_lease.validate(7, gen, 10))
        chat_lease.commit(7, gen, 11)
        assert.is_true(chat_lease.validate(7, gen, 11))
    end)

    it("rejects stale generations", function()
        local stale = chat_lease.begin(7, 10)
        local current = chat_lease.begin(7, 10)

        local ok, reason = chat_lease.validate(7, stale, 10)

        assert.is_false(ok)
        assert.matches("stale", reason)
        assert.is_true(chat_lease.validate(7, current, 10))
    end)

    it("clears only the matching generation when provided", function()
        local stale = chat_lease.begin(7, 10)
        local current = chat_lease.begin(7, 10)

        chat_lease.clear(7, stale)
        assert.is_not_nil(chat_lease.current(7))

        chat_lease.clear(7, current)
        assert.is_nil(chat_lease.current(7))
    end)
end)
