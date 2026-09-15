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

        it("compares captures with backend-only descriptions on " .. wire, function()
            local old = payload("15.1.0", openai)
            local current = vim.deepcopy(old)
            for _, tool in ipairs(current.tools) do
                local definition = openai and tool["function"] or tool
                definition.description = definition.description:gsub("ripgrep 15%.1%.0", "ripgrep")
            end
            assert.same(golden.normalize_payload(old), golden.normalize_payload(current))
        end)

        it("normalizes only the dedicated ls backend metadata on " .. wire, function()
            local function listing(metadata)
                local tool = {name="ls", description="List directory contents using the system ls command ("
                    .. metadata .. "). Safe flags only. Extra (ripgrep 15.1.0).",
                    input_schema={description="BSD ls (macOS)"}}
                return {tools={openai and {type="function", ["function"]=tool} or tool},
                    messages={{content="BSD ls (macOS)"}}}
            end
            local current = listing("ls")
            for _, metadata in ipairs({"BSD ls (macOS)", "ls (GNU coreutils) 9.5"}) do
                local captured = listing(metadata)
                assert.same(golden.normalize_payload(current), golden.normalize_payload(captured))
                local before = vim.deepcopy(captured)
                golden.normalize_payload(captured)
                assert.same(before, captured)
            end
            local changed = listing("ls")
            local definition = openai and changed.tools[1]["function"] or changed.tools[1]
            definition.description = definition.description:gsub("Safe flags only", "All flags allowed")
            assert.are_not.same(golden.normalize_payload(current), golden.normalize_payload(changed))
            definition.name = "other"
            assert.same(changed, golden.normalize_payload(changed))
        end)

        it("normalizes only find backend metadata on " .. wire, function()
            local function value(metadata, suffix)
                local def={name="find",description="Search for files and directories using the system find command ("
                    .. metadata .. "). " .. (suffix or "Structured fields only.")}
                return {tools={openai and {type="function", ["function"]=def} or def}}
            end
            assert.same(golden.normalize_payload(value("find")), golden.normalize_payload(value("BSD find (macOS)")))
            assert.same(golden.normalize_payload(value("find")), golden.normalize_payload(value("find (GNU findutils) 4.10.0")))
            assert.are_not.same(golden.normalize_payload(value("find")), golden.normalize_payload(value("find", "Raw shell fragments allowed.")))
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
