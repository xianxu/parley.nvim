local golden = require("scripts.golden_fixture")

local function payload(version, openai)
    local tools = {}
    for _, name in ipairs({ "grep", "chat_history_search" }) do
        local tool = {
            name = name,
            description = "Search safely. Backend: ripgrep (ripgrep " .. version .. ").",
            input_schema = { description = "ripgrep " .. version },
        }
        tools[#tools + 1] = openai and { type = "function", ["function"] = tool } or tool
    end
    return { tools = tools, messages = { { content = "ripgrep 15.1.0" } } }
end

describe("golden fixture normalization", function()
    for _, openai in ipairs({ false, true }) do
        local wire = openai and "OpenAI" or "Anthropic"

        it("ignores only ripgrep tool description versions on " .. wire, function()
            local old = payload("15.1.0", openai)
            local new = vim.deepcopy(old)
            for _, tool in ipairs(new.tools) do
                local definition = openai and tool["function"] or tool
                definition.description = definition.description:gsub("15%.1%.0", "15.2.0")
            end
            assert.same(golden.normalize_payload(old), golden.normalize_payload(new))
        end)

        it("preserves meaningful description changes on " .. wire, function()
            local original = payload("15.1.0", openai)
            local changed = vim.deepcopy(original)
            local definition = openai and changed.tools[1]["function"] or changed.tools[1]
            definition.description = definition.description:gsub("safely", "recursively")
            assert.are_not.same(golden.normalize_payload(original), golden.normalize_payload(changed))
        end)

        it("leaves the input and non-description values unchanged on " .. wire, function()
            local original = payload("15.1.0", openai)
            local before = vim.deepcopy(original)
            local normalized = golden.normalize_payload(original)
            assert.same(before, original)
            assert.same(original.messages, normalized.messages)
            for i, tool in ipairs(original.tools) do
                local definition = openai and tool["function"] or tool
                local result = openai and normalized.tools[i]["function"] or normalized.tools[i]
                assert.same(definition.input_schema, result.input_schema)
            end
            local changed = vim.deepcopy(original)
            changed.messages[1].content = "ripgrep 15.2.0"
            assert.are_not.same(normalized, golden.normalize_payload(changed))
        end)
    end

    it("preserves unrelated tools and payloads without tools", function()
        local original = {
            tools = { { name = "read_file", description = "Read (ripgrep 15.1.0)." } },
        }
        assert.same(original, golden.normalize_payload(original))
        assert.same({ messages = {} }, golden.normalize_payload({ messages = {} }))
    end)
end)
