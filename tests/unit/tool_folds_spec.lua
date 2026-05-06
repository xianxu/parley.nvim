-- Unit tests for lua/parley/tool_folds.lua — pure helpers only.

local tool_folds = require("parley.tool_folds")
local compute = tool_folds._compute_reasoning_ranges

describe("tool_folds.compute_reasoning_ranges", function()
    it("folds a single reasoning region terminated by a structural marker", function()
        local lines = {
            "💬: question",                  -- 1
            "",                                -- 2
            "🤖: agent header",                -- 3
            "🧠: thinking starts",             -- 4  (fold start)
            "more thinking",                   -- 5
            "still thinking",                  -- 6  (fold end — line before 🔧:)
            "🔧: tool call",                   -- 7  (terminator, not in fold)
            "result text",                     -- 8
        }
        local ranges = compute(lines)
        assert.same({ { 4, 6 } }, ranges)
    end)

    it("folds inclusive of an explicit 🧠:[END] terminator", function()
        local lines = {
            "🤖: header",
            "🧠: thinking",
            "more",
            "🧠:[END]",
            "post-think text",
        }
        local ranges = compute(lines)
        assert.same({ { 2, 4 } }, ranges)
    end)

    it("folds two consecutive thinking blocks separately", function()
        local lines = {
            "🤖: header",
            "🧠: first block",
            "first body",
            "🧠: second block",
            "second body",
            "🔧: tool",
        }
        local ranges = compute(lines)
        assert.same({ { 2, 3 }, { 4, 5 } }, ranges)
    end)

    it("does not fold a single 🧠: line with no body", function()
        local lines = {
            "🤖: header",
            "🧠:",
            "🔧: tool",
        }
        local ranges = compute(lines)
        assert.same({}, ranges)
    end)

    it("folds reasoning at end of buffer with no terminator", function()
        local lines = {
            "🤖: header",
            "🧠: trailing",
            "more body",
        }
        local ranges = compute(lines)
        assert.same({ { 2, 3 } }, ranges)
    end)

    it("returns no ranges when there are no 🧠: lines", function()
        local lines = { "💬: question", "🤖: answer", "ok" }
        assert.same({}, compute(lines))
    end)

    it("treats 💬:, 🤖:, 📎:, 📝:, 🌿:, 🔒:, --- as terminators", function()
        for _, terminator in ipairs({ "💬:", "🤖:", "📎:", "📝:", "🌿:", "🔒:", "---" }) do
            local lines = {
                "🧠: thinking",
                "body",
                terminator .. " whatever",
            }
            local ranges = compute(lines)
            assert.same({ { 1, 2 } }, ranges,
                "expected fold to terminate before '" .. terminator .. "'")
        end
    end)
end)
