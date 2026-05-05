-- Tests for lua/parley/system_prompt_msgs.lua

local sp = require("parley.system_prompt_msgs")

local function cache_yes(_) return true end
local function cache_no(_) return false end

describe("system_prompt_msgs.build", function()
    it("returns empty when system_prompt is nil", function()
        local r = sp.build({ provider = "anthropic" }, cache_yes)
        assert.same({}, r)
    end)

    it("returns empty when system_prompt is whitespace-only", function()
        local r = sp.build({ provider = "anthropic", system_prompt = "  \n\t " }, cache_yes)
        assert.same({}, r)
    end)

    it("default mode: returns one role=system message", function()
        local r = sp.build({ provider = "anthropic", system_prompt = "Be helpful." }, cache_no)
        assert.equals(1, #r)
        assert.equals("system", r[1].role)
        assert.equals("Be helpful.", r[1].content)
        assert.is_nil(r[1].cache_control)
    end)

    it("default mode: attaches cache_control when provider supports it", function()
        local r = sp.build({ provider = "anthropic", system_prompt = "Be helpful." }, cache_yes)
        assert.equals(1, #r)
        assert.equals("system", r[1].role)
        assert.same({ type = "ephemeral" }, r[1].cache_control)
    end)

    it("synthetic mode: returns a user+assistant pair", function()
        local r = sp.build({
            provider = "anthropic",
            system_prompt = "Be helpful.",
            synthetic_system_prompt = true,
        }, cache_no)
        assert.equals(2, #r)
        assert.equals("user", r[1].role)
        assert.equals("Be helpful.", r[1].content)
        assert.equals("assistant", r[2].role)
        assert.equals(sp.DEFAULT_ACK, r[2].content)
    end)

    it("synthetic mode: cache_control rides on the user content block when supported", function()
        local r = sp.build({
            provider = "anthropic",
            system_prompt = "Be helpful.",
            synthetic_system_prompt = true,
        }, cache_yes)
        assert.equals(2, #r)
        assert.equals("user", r[1].role)
        assert.is_table(r[1].content)
        assert.equals(1, #r[1].content)
        assert.equals("text", r[1].content[1].type)
        assert.equals("Be helpful.", r[1].content[1].text)
        assert.same({ type = "ephemeral" }, r[1].content[1].cache_control)
    end)

    it("synthetic mode without cache support: plain string user content", function()
        local r = sp.build({
            provider = "openai",
            system_prompt = "Be helpful.",
            synthetic_system_prompt = true,
        }, cache_no)
        assert.equals(2, #r)
        assert.equals("user", r[1].role)
        assert.equals("Be helpful.", r[1].content)
    end)

    it("synthetic mode: custom ack overrides the default", function()
        local r = sp.build({
            provider = "anthropic",
            system_prompt = "Be helpful.",
            synthetic_system_prompt = true,
            synthetic_system_prompt_ack = "Understood.",
        }, cache_yes)
        assert.equals("Understood.", r[2].content)
    end)

    it("synthetic mode: empty/blank custom ack falls back to the default", function()
        local r = sp.build({
            provider = "anthropic",
            system_prompt = "Be helpful.",
            synthetic_system_prompt = true,
            synthetic_system_prompt_ack = "",
        }, cache_yes)
        assert.equals(sp.DEFAULT_ACK, r[2].content)
    end)

    it("falsy synthetic flag stays in default mode", function()
        local r = sp.build({
            provider = "anthropic",
            system_prompt = "Be helpful.",
            synthetic_system_prompt = false,
        }, cache_yes)
        assert.equals(1, #r)
        assert.equals("system", r[1].role)
    end)

    it("missing has_cache_control probe degrades safely (no cache_control attached)", function()
        local r = sp.build({ provider = "anthropic", system_prompt = "Hi." }, nil)
        assert.equals(1, #r)
        assert.is_nil(r[1].cache_control)
    end)
end)
