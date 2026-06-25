-- #138: chat_lease is extmark-anchored. The lease tracks the response block's
-- start line via an `invalidate = true` extmark, so it tolerates ordinary edits
-- (typing, streaming, growing other lines) and only invalidates on a structural
-- break (the anchor line being deleted — e.g. undo/redo of the placeholder).
-- Needs a real buffer (extmarks are a Neovim API), hence integration, not unit.

local chat_lease = require("parley.chat_lease")

describe("chat_lease (extmark-anchored, #138)", function()
    local buf

    before_each(function()
        chat_lease._reset()
        buf = vim.api.nvim_create_buf(false, true)
        -- anchor the lease on row 2 ("stream-here") in these tests
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "q: hello", "🤖:", "stream-here", "tail" })
    end)

    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    it("validates while the anchor line exists", function()
        local gen = chat_lease.begin(buf, 2, { query_id = "qid_1", role = "stream" })

        local ok, reason = chat_lease.validate(buf, gen)

        assert.is_true(ok)
        assert.is_nil(reason)
        assert.same({ query_id = "qid_1", role = "stream" }, chat_lease.current(buf).meta)
    end)

    it("stays valid across in-place edits to the anchor line (streaming in)", function()
        local gen = chat_lease.begin(buf, 2, {})

        vim.api.nvim_buf_set_text(buf, 2, 0, 2, 0, { "streamed text " })

        assert.is_true(chat_lease.validate(buf, gen))
    end)

    it("stays valid when unrelated lines above change (anchor rides the edit)", function()
        local gen = chat_lease.begin(buf, 2, {})

        -- replace the single line above with two lines: pushes the anchor down
        vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "q: hi", "q: more" })

        assert.is_true(chat_lease.validate(buf, gen))
    end)

    it("invalidates when the anchor line is deleted (structural break)", function()
        local gen = chat_lease.begin(buf, 2, {})

        vim.api.nvim_buf_set_lines(buf, 2, 3, false, {}) -- delete the anchor line

        local ok, reason = chat_lease.validate(buf, gen)
        assert.is_false(ok)
        assert.matches("structure changed", reason)
        assert.is_false(chat_lease.current(buf).valid)
    end)

    it("rejects stale generations", function()
        local stale = chat_lease.begin(buf, 2)
        local current = chat_lease.begin(buf, 2)

        local ok, reason = chat_lease.validate(buf, stale)

        assert.is_false(ok)
        assert.matches("stale", reason)
        assert.is_true(chat_lease.validate(buf, current))
    end)

    it("invalidate() marks the active lease invalid with a reason", function()
        local gen = chat_lease.begin(buf, 2)

        chat_lease.invalidate(buf, "explicit cancel")

        local ok, reason = chat_lease.validate(buf, gen)
        assert.is_false(ok)
        assert.matches("explicit cancel", reason)
    end)

    it("commit is a no-op that still reports the live generation", function()
        local gen = chat_lease.begin(buf, 2)

        assert.is_true(chat_lease.commit(buf, gen))
        assert.is_true(chat_lease.validate(buf, gen))
    end)

    it("clears only the matching generation when provided", function()
        local stale = chat_lease.begin(buf, 2)
        local current = chat_lease.begin(buf, 2)

        chat_lease.clear(buf, stale)
        assert.is_not_nil(chat_lease.current(buf))

        chat_lease.clear(buf, current)
        assert.is_nil(chat_lease.current(buf))
    end)
end)
