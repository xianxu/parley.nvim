local history = require("parley.chat_history")

describe("native chat history", function()
    it("runs native history without consulting presentation or cancelling responses", function()
        local native = 0
        local result = history.guard({
            buf = 11,
            pending_identity = function() error("presentation is not write authority") end,
            confirm = function() error("native history must not prompt") end,
            cancel_for_history = function() error("unrelated grants must survive") end,
            native_history = function() native = native + 1 end,
        })

        assert.equals("native", result)
        assert.equals(1, native)
    end)

    it("preserves native history errors without retrying or hiding them", function()
        local calls = 0
        local ok, failure = pcall(history.guard, {
            native_history = function()
                calls = calls + 1
                error("native history failed")
            end,
        })

        assert.is_false(ok)
        assert.is_truthy(failure:find("native history failed", 1, true))
        assert.equals(1, calls)
    end)
end)
