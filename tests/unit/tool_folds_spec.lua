local tool_folds = require("parley.tool_folds")

describe("tool_folds semantic policy", function()
    it("folds exactly auxiliary answer entities", function()
        for _, kind in ipairs({ "thinking", "summary", "tool_use", "tool_result" }) do
            assert.is_true(tool_folds._is_foldable(kind), kind)
        end
        for _, kind in ipairs({ "question", "agent_header", "text", "stream_placeholder" }) do
            assert.is_false(tool_folds._is_foldable(kind), kind)
        end
    end)
end)
