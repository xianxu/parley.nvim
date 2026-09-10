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

    it("says the cap counts reasoning, which is the non-obvious half", function()
        local msg = reason({ raw_response = "xxxx", stop_reason = "max_tokens" })
        assert.is_truthy(msg:match("[Rr]easoning"), msg)
    end)

    it("does not tell an openai or googleai user about Claude", function()
        -- #228 BR-1: the advice was worded "On Claude the cap counts thinking
        -- tokens", which is untrue about the provider the user is actually on —
        -- and reasoning tokens count on gpt-5 too.
        for _, r in ipairs({ "length", "MAX_TOKENS" }) do
            local msg = reason({ raw_response = "xxxx", stop_reason = r })
            assert.is_nil(msg:match("Claude"), "names the wrong provider: " .. msg)
            assert.is_truthy(msg:match("output%-token cap"), msg)
        end
    end)

    it("reports the surprising case as surprising", function()
        -- Finished normally and still no text: the only one worth a bug report.
        local msg = reason({ raw_response = string.rep("x", 500), stop_reason = "end_turn" })
        assert.is_truthy(msg:match("no assistant text"), msg)
        assert.is_truthy(msg:match("end_turn"), msg)
        assert.is_truthy(msg:match("500"), msg)
    end)

    describe("_extract_stop_reason, per wire", function()
        -- #228 BR-1: the Gemini line had no test — deleting it left every spec
        -- green, so the fix was unpinned. Each wire gets its own case.
        it("anthropic: stop_reason", function()
            assert.equals("max_tokens", D._extract_stop_reason(
                '{"type":"message_delta","delta":{"stop_reason":"max_tokens"}}'))
        end)

        it("openai: finish_reason", function()
            assert.equals("length", D._extract_stop_reason(
                '{"choices":[{"finish_reason":"length","delta":{}}]}'))
        end)

        it("googleai: finishReason (camelCase — the one that went unmatched)", function()
            assert.equals("MAX_TOKENS", D._extract_stop_reason(
                '{"candidates":[{"finishReason":"MAX_TOKENS"}]}'))
        end)

        it("returns nil when no wire spells one, and tolerates a non-string", function()
            assert.is_nil(D._extract_stop_reason('{"choices":[{"delta":{}}]}'))
            assert.is_nil(D._extract_stop_reason(nil))
            assert.is_nil(D._extract_stop_reason(42))
        end)
    end)

    describe("_is_normal_finish", function()
        -- Stated as a whitelist (#228 BR-7): asking "was it the cap?" stayed
        -- silent for refusals, content filters and in-band errors, which leave
        -- the same artefact. An unseen ending should surface, not pass.
        it("accepts the ordinary endings across wires", function()
            for _, r in ipairs({ "end_turn", "stop", "STOP", "tool_use", "tool_calls" }) do
                assert.is_true(D._is_normal_finish(r), r)
            end
        end)

        it("rejects every abnormal ending, including ones not enumerated", function()
            for _, r in ipairs({
                "max_tokens", "length", "MAX_TOKENS",
                "refusal", "content_filter", "SAFETY", "RECITATION",
                "some_future_reason_nobody_has_seen",
            }) do
                assert.is_false(D._is_normal_finish(r), r .. " passed as a normal finish")
            end
        end)

        it("treats an unparsed reason as normal", function()
            -- Every successful non-streaming shape reaches here; warning on all
            -- of them would be noise, and the empty path still reports.
            assert.is_true(D._is_normal_finish(nil))
        end)
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

-- One classification, computed once, rendered from (class, has_text).
--
-- #228 close review: the first version asked three separate questions in a
-- fixed if/elseif order — empty? in-band error? abnormal stop reason? — so
-- ORDER decided the answer, and an empty response that ALSO carried an error
-- could never be reported as an error. A single classification cannot have
-- that bug, which is the point of the refactor.
describe("dispatcher._classify_ending / _ending_notice", function()
    local D = require("parley.dispatcher")

    local function qt(o)
        return {
            raw_response = o.raw or "",
            response = o.text or "",
            stop_reason = o.reason,
        }
    end

    describe("classification", function()
        local cases = {
            { name = "normal finish",     reason = "end_turn",   class = "done" },
            { name = "openai normal",     reason = "stop",       class = "done" },
            { name = "cap, anthropic",    reason = "max_tokens", class = "cap" },
            { name = "cap, openai",       reason = "length",     class = "cap" },
            { name = "cap, googleai",     reason = "MAX_TOKENS", class = "cap" },
            { name = "refusal",           reason = "refusal",    class = "filtered" },
            { name = "content filter",    reason = "content_filter", class = "filtered" },
            { name = "unseen reason",     reason = "some_new_thing", class = "filtered" },
            { name = "no reason at all",  reason = nil,          class = "unknown" },
        }
        for _, c in ipairs(cases) do
            it(c.name .. " -> " .. c.class, function()
                assert.equals(c.class, D._classify_ending(qt({ reason = c.reason })).class)
            end)
        end

        it("an in-band error OUTRANKS every other signal", function()
            -- The ordering bug, stated as a property. An error explains the
            -- whole turn including its emptiness, so it must not lose a race
            -- with the empty branch.
            local e = D._classify_ending(qt({
                raw = '{"error":{"message":"Overloaded"}}', reason = "end_turn", text = "",
            }))
            assert.equals("error", e.class)
            assert.equals("Overloaded", e.detail)
        end)

        it("does not flag an ordinary answer that happens to quote error JSON", function()
            -- The text arrived and is about errors; the body is not an error.
            local e = D._classify_ending(qt({
                raw = 'data: {"delta":{"text":"use {\\"error\\": null} to reset"}}',
                reason = "end_turn", text = "use ...",
            }))
            assert.equals("done", e.class)
        end)

        it("keeps a message containing escaped quotes intact", function()
            -- `[^"]+` stopped at the first escaped quote and logged `Internal \`.
            assert.equals([[Internal "x" error]],
                D._inband_error('{"error":{"message":"Internal \\"x\\" error"}}'))
        end)
    end)

    describe("rendering", function()
        it("says nothing at all when the turn ended normally with text", function()
            local msg = D._ending_notice(qt({ reason = "end_turn", text = "hi", raw = "xx" }))
            assert.is_nil(msg)
        end)

        it("warns about truncation when text arrived, errors when none did", function()
            local trunc, lvl1 = D._ending_notice(qt({ reason = "max_tokens", text = "hi", raw = "xx" }))
            assert.is_truthy(trunc:match("TRUNCATED"), trunc)
            assert.equals("warning", lvl1)

            local none, lvl2 = D._ending_notice(qt({ reason = "max_tokens", text = "", raw = "xx" }))
            assert.is_truthy(none:match("no answer"), none)
            assert.equals("error", lvl2)
        end)

        it("gives max_tokens advice for the cap and withholds it otherwise", function()
            assert.is_truthy(D._ending_notice(qt({ reason = "length", text = "x", raw = "y" }))
                :match("Raise max_tokens"))
            assert.is_nil(D._ending_notice(qt({ reason = "refusal", text = "x", raw = "y" }))
                :match("Raise max_tokens"))
        end)

        it("keeps the #197 property: a successful zero-byte body still reports", function()
            local msg, lvl = D._ending_notice(qt({ raw = "", text = "" }))
            assert.is_truthy(msg:match("no response at all"), msg)
            assert.equals("error", lvl)
        end)

        it("mentions an unexplained ending only when an answer arrived", function()
            assert.is_truthy(D._ending_notice(qt({ raw = "xxxx", text = "hi" }))
                :match("without saying why"))
            -- with no text it is the empty diagnosis's business, not this one
            assert.is_truthy(D._ending_notice(qt({ raw = "xxxx", text = "" }))
                :match("no assistant text"))
        end)
    end)
end)
