local exchange_model = require("parley.exchange_model")
local projection = require("parley.fold_projection")

describe("tool_folds semantic policy", function()
    it("folds exactly auxiliary answer entities", function()
        local model = exchange_model.new(0)
        model:add_exchange(1)
        for _, kind in ipairs({ "agent_header", "thinking", "summary", "tool_use", "tool_result", "text" }) do
            model:add_block(1, kind, 1)
        end
        local kinds = {}
        for _, range in ipairs(projection.desired_folds(model, 1)) do kinds[#kinds + 1] = range.kind end
        assert.same({ "thinking", "summary", "tool_use", "tool_result" }, kinds)
    end)
end)
