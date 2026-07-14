local history = require("parley.chat_history")

describe("chat history guard policy", function()
    it("normalizes agent labels and bounds the complete prompt on UTF-8 boundaries", function()
        local prompt = history.prompt("Agent\r\nλ" .. string.rep("x", 300) .. "TAIL_SECRET")

        assert.is_true(#prompt <= 160)
        assert.is_truthy(prompt:find("Agent λ", 1, true))
        assert.is_nil(prompt:find("\r", 1, true))
        assert.is_nil(prompt:find("\n", 1, true))
        assert.is_nil(prompt:find("TAIL_SECRET", 1, true))
        assert.is_true(vim.str_utfindex(prompt) > 0, "prompt must remain valid UTF-8")
    end)

    it("uses only confirmation result one as approval", function()
        assert.is_true(history.should_proceed(1))
        assert.is_false(history.should_proceed(2))
        assert.is_false(history.should_proceed(0))
        assert.is_false(history.should_proceed(nil))
    end)

    it("reads identity once and passes through native history when inactive", function()
        local identities = 0
        local native = 0
        local result = history.guard({
            buf = 11,
            pending_identity = function()
                identities = identities + 1
                return nil
            end,
            native_history = function() native = native + 1 end,
            confirm = function() error("must not confirm") end,
            cancel_for_history = function() error("must not cancel") end,
        })

        assert.equals("native", result)
        assert.equals(1, identities)
        assert.equals(1, native)
    end)

    for _, choice in ipairs({ 2, 0 }) do
        it("leaves history and request untouched for confirmation result " .. choice, function()
            local native = 0
            local cancelled = 0
            local result = history.guard({
                buf = 11,
                pending_identity = function() return { agent = "Claude" } end,
                native_history = function() native = native + 1 end,
                confirm = function(message, buttons, default)
                    assert.equals(history.prompt("Claude"), message)
                    assert.equals("&Yes\n&No", buttons)
                    assert.equals(2, default)
                    return choice
                end,
                cancel_for_history = function() cancelled = cancelled + 1 end,
            })

            assert.equals("declined", result)
            assert.equals(0, native)
            assert.equals(0, cancelled)
        end)
    end

    it("passes the native callback once to confirmed cancellation", function()
        local native = function() end
        local calls = {}
        local result = history.guard({
            buf = 11,
            pending_identity = function() return { agent = "Claude" } end,
            native_history = native,
            confirm = function() return 1 end,
            cancel_for_history = function(buf, callback)
                table.insert(calls, { buf = buf, callback = callback })
            end,
        })

        assert.equals("cancelled", result)
        assert.equals(1, #calls)
        assert.equals(11, calls[1].buf)
        assert.equals(native, calls[1].callback)
    end)
end)
