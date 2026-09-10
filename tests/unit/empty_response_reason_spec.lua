-- dispatcher._empty_response_reason — say WHY there was no text (#228).
--
-- "response is empty: body_bytes=18152" is self-contradictory, and it has now
-- misled twice for two different causes: #197 (credential failures) and #228
-- (the model hit its output cap while still thinking). The bytes arrived; what
-- was missing was assistant TEXT. `stop_reason` was already extracted and then
-- discarded by the message — parley knew the answer and printed a contradiction.

local D = require("parley.dispatcher")
local reason = D._empty_response_reason

describe("dispatcher._empty_response_reason", function()
    it("names the transport when nothing came back", function()
        local msg = reason({ raw_response = "" })
        assert.is_truthy(msg:match("no response at all"), msg)
        assert.is_nil(msg:match("max_tokens"))
    end)

    it("names the output cap, and never calls a body with bytes 'empty'", function()
        -- The reported case: 18 KB of thinking, stop_reason max_tokens, no text.
        local msg = reason({ raw_response = string.rep("x", 18152), stop_reason = "max_tokens" })
        assert.is_truthy(msg:match("output%-token cap"), msg)
        assert.is_truthy(msg:match("18152"), msg)
        assert.is_truthy(msg:match("[Rr]aise max_tokens"), msg)
        -- the contradiction that sent the operator hunting for a limit
        assert.is_nil(msg:match("is empty"), "still describes a body with bytes as empty: " .. msg)
    end)

    it("says the cap counts thinking, which is the non-obvious half", function()
        local msg = reason({ raw_response = "xxxx", stop_reason = "max_tokens" })
        assert.is_truthy(msg:match("thinking"), msg)
    end)

    it("reports the surprising case as surprising", function()
        -- Finished normally and still no text: the only one worth a bug report.
        local msg = reason({ raw_response = string.rep("x", 500), stop_reason = "end_turn" })
        assert.is_truthy(msg:match("no assistant text"), msg)
        assert.is_truthy(msg:match("end_turn"), msg)
        assert.is_truthy(msg:match("500"), msg)
    end)

    it("recognises the cap in every provider's spelling", function()
        -- #228 BR-1: the first version knew only "max_tokens", which is the
        -- spelling the reported failure happened to use. An OpenAI or Gemini
        -- response that hit its cap was labelled a normal finish.
        for _, spelling in ipairs({ "max_tokens", "length", "MAX_TOKENS" }) do
            local msg = reason({ raw_response = "xxxx", stop_reason = spelling })
            assert.is_truthy(msg:match("output%-token cap"),
                spelling .. " not recognised as the cap: " .. msg)
            assert.is_truthy(msg:match(spelling), "the message hides the actual value: " .. msg)
        end
    end)

    it("does not treat an ordinary finish as the cap", function()
        for _, spelling in ipairs({ "end_turn", "stop", "STOP", "tool_use" }) do
            assert.is_false(D._is_output_cap(spelling), spelling)
        end
        assert.is_false(D._is_output_cap(nil))
        assert.is_false(D._is_output_cap(42))
    end)

    it("does not raise when stop_reason was never parsed", function()
        local msg = reason({ raw_response = "xx" })
        assert.is_truthy(msg:match("unknown"), msg)
    end)

    it("tolerates a missing raw_response", function()
        assert.is_truthy(reason({}):match("no response at all"))
    end)
end)
