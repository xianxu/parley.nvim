-- Integration tests for the progress bar's float/timer lifecycle (#133 M7).

local progress = require("parley.progress")

describe("progress bar", function()
    after_each(function()
        progress.stop()
    end)

    it("start shows a bar; stop tears it down (idempotent)", function()
        assert.is_false(progress.is_active())
        assert.is_true(progress.start("review running"))
        assert.is_true(progress.is_active())
        progress.stop()
        assert.is_false(progress.is_active())
        progress.stop() -- idempotent
        assert.is_false(progress.is_active())
    end)

    it("start replaces an existing bar (one active at a time)", function()
        progress.start("first")
        progress.start("second")
        assert.is_true(progress.is_active())
    end)
end)
