-- Unit tests for deprecator module in lua/parley/deprecator.lua
--
-- The deprecator checks config keys against a known deprecated list
-- and provides migration hints. Key behaviors:
-- - is_valid: returns false for deprecated keys, true for valid ones
-- - has_old_prompt_signature: checks agent table for provider field
-- - has_old_chat_signature: checks agent table for provider field
-- - report: displays deprecation warnings

describe("deprecator", function()
    local deprecator

    before_each(function()
        package.loaded["parley.deprecator"] = nil
        deprecator = require("parley.deprecator")
    end)

    describe("Group A: is_valid", function()
        it("A1: returns false for known deprecated key 'command_model'", function()
            local result = deprecator.is_valid("command_model", "gpt-4")
            assert.is_false(result)
        end)

        it("A2: returns false for 'openai_api_endpoint'", function()
            local result = deprecator.is_valid("openai_api_endpoint", "https://api.openai.com")
            assert.is_false(result)
        end)

        it("A3: returns true for non-deprecated key", function()
            local result = deprecator.is_valid("agents", {})
            assert.is_true(result)
        end)

        it("A4: appends to _deprecated when deprecated key found", function()
            deprecator.is_valid("command_model", "gpt-4")
            assert.equals(1, #deprecator._deprecated)
            assert.equals("command_model", deprecator._deprecated[1].name)
            assert.equals("gpt-4", deprecator._deprecated[1].value)
        end)

        it("A5: _deprecated entry contains name, msg, value", function()
            deprecator.is_valid("chat_model", "gpt-3.5")
            local entry = deprecator._deprecated[1]
            assert.is_not_nil(entry.name)
            assert.is_not_nil(entry.msg)
            assert.is_not_nil(entry.value)
        end)

        it("A6: returns false for 'chat_system_prompt'", function()
            local result = deprecator.is_valid("chat_system_prompt", "You are...")
            assert.is_false(result)
        end)

        it("A7: returns false for 'command_prompt_prefix'", function()
            local result = deprecator.is_valid("command_prompt_prefix", "> ")
            assert.is_false(result)
        end)
    end)

    describe("Group B: has_old_prompt_signature", function()
        it("B1: returns true when agent is nil", function()
            assert.is_true(deprecator.has_old_prompt_signature(nil))
        end)

        it("B2: returns false when agent has provider field", function()
            assert.is_false(deprecator.has_old_prompt_signature({ provider = "openai" }))
        end)

        it("B3: returns true when agent has no provider field", function()
            assert.is_true(deprecator.has_old_prompt_signature({ model = "gpt-4" }))
        end)
    end)

    describe("Group C: has_old_chat_signature", function()
        it("C1: returns false when agent is nil", function()
            assert.is_false(deprecator.has_old_chat_signature(nil))
        end)

        it("C2: returns true when agent is non-nil but has no provider field", function()
            assert.is_true(deprecator.has_old_chat_signature({ model = "gpt-4" }))
        end)

        it("C3: returns false when agent has provider field", function()
            assert.is_false(deprecator.has_old_chat_signature({ provider = "openai" }))
        end)
    end)

    describe("Group D: report", function()
        it("D1: does nothing when _deprecated is empty", function()
            -- Should not error
            local ok = pcall(deprecator.report)
            assert.is_true(ok)
        end)

        it("D2: does not error when there are deprecated entries", function()
            deprecator.is_valid("command_model", "gpt-4")
            deprecator.is_valid("chat_model", "gpt-3.5")
            local ok = pcall(deprecator.report)
            assert.is_true(ok)
        end)
    end)
end)
