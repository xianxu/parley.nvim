-- Unit tests for the tool wire registry and the cliproxy route helper (#198).
--
-- The registry is the single seam dispatcher / tool_loop / skill_invoke
-- consume, replacing three independently hardcoded decode sites and a
-- five-branch provider chain.
--
-- Its public API takes (provider, MODEL) rather than (provider, route) on
-- purpose. cliproxyapi speaks two wires depending on the model, and a route
-- parameter is one a caller can forget — a forgotten route would silently
-- resolve to some wire and decode zero tool calls, which is
-- indistinguishable from a truncated response. Deriving the route inside
-- the registry makes that mistake unrepresentable.

local wire = require("parley.tools.wire")
local wire_anthropic = require("parley.tools.wire_anthropic")
local wire_openai = require("parley.tools.wire_openai")
local providers = require("parley.providers")

describe("wire.resolve", function()
    it("resolves anthropic to the anthropic wire", function()
        assert.equals(wire_anthropic, wire.resolve("anthropic", { model = "claude-sonnet-5" }))
    end)

    it("resolves the openai family to the openai wire", function()
        for _, provider in ipairs({ "openai", "copilot", "azure", "ollama" }) do
            assert.equals(wire_openai, wire.resolve(provider, { model = "gpt-5.4" }),
                "expected the openai wire for provider " .. provider)
        end
    end)

    it("resolves cliproxyapi by model, deriving the route itself", function()
        assert.equals(wire_anthropic, wire.resolve("cliproxyapi", {
            model = "claude-sonnet-5", web_search_strategy = "anthropic_tools_route",
        }))
        assert.equals(wire_openai, wire.resolve("cliproxyapi", {
            model = "gpt-5.6-sol",
        }))
    end)

    it("accepts a bare model-name string as well as a model table", function()
        assert.equals(wire_openai, wire.resolve("openai", "gpt-5.4"))
        assert.equals(wire_openai, wire.resolve("cliproxyapi", "gpt-5.6-sol"))
    end)

    it("returns nil for a provider with no wire", function()
        assert.is_nil(wire.resolve("googleai", { model = "gemini-3-pro-preview" }))
        assert.is_nil(wire.resolve("nonsense", { model = "x" }))
        assert.is_nil(wire.resolve(nil, nil))
    end)
end)

describe("wire.encode", function()
    local defs = {
        { name = "read_file", description = "d", input_schema = { type = "object" } },
    }

    it("encodes through the resolved wire", function()
        local anth = wire.encode("anthropic", { model = "claude-sonnet-5" }, defs)
        assert.is_not_nil(anth[1].input_schema)

        local oai = wire.encode("openai", { model = "gpt-5.4" }, defs)
        assert.equals("function", oai[1].type)
    end)

    -- Encode RAISES rather than degrading: an agent declared tools its
    -- provider cannot carry, and failing at request-build time names the
    -- provider. Silently sending no tools would look like the model simply
    -- chose not to call one.
    it("raises for a provider with no wire, naming the provider", function()
        local ok, err = pcall(wire.encode, "googleai", { model = "gemini-3-pro-preview" }, defs)
        assert.is_false(ok)
        assert.matches("googleai", tostring(err))
    end)
end)

describe("wire.decode / has_tool_calls / translate_messages", function()
    -- These run on EVERY response, including from non-tool agents and
    -- providers with no wire, so they degrade quietly instead of raising.
    it("decode returns an empty list for a provider with no wire", function()
        assert.same({}, wire.decode("googleai", { model = "gemini-3-pro-preview" }, "anything"))
    end)

    it("has_tool_calls is false for a provider with no wire", function()
        assert.is_false(wire.has_tool_calls("googleai", { model = "x" }, '"tool_calls"'))
    end)

    it("translate_messages is identity for a wire that does not define it", function()
        local msgs = { { role = "user", content = "hi" } }
        assert.same(msgs, wire.translate_messages("anthropic", { model = "claude-sonnet-5" }, msgs))
        assert.same(msgs, wire.translate_messages("googleai", { model = "x" }, msgs))
    end)

    it("translate_messages applies the openai translation when the wire has one", function()
        local out = wire.translate_messages("openai", { model = "gpt-5.4" }, {
            { role = "user", content = {
                { type = "tool_result", tool_use_id = "call_a", content = "ok" },
            } },
        })
        assert.equals("tool", out[1].role)
        assert.equals("call_a", out[1].tool_call_id)
    end)

    it("decodes a real openai stream through the registry", function()
        local f = assert(io.open("tests/fixtures/openai_tool_use_stream.sse", "r"))
        local raw = f:read("*a")
        f:close()
        local calls = wire.decode("cliproxyapi", { model = "gpt-5.6-sol" }, raw)
        assert.equals(1, #calls)
        assert.equals("get_weather", calls[1].name)
    end)
end)

describe("providers.cliproxy_route", function()
    it("routes an anthropic-family model with the strategy to the anthropic wire", function()
        assert.equals("anthropic", providers.cliproxy_route("claude-sonnet-5", "anthropic_tools_route"))
        assert.equals("anthropic", providers.cliproxy_route("claude-opus-4-8", "anthropic_tools_route"))
    end)

    it("routes an anthropic-family model WITHOUT the strategy to openai", function()
        assert.equals("openai", providers.cliproxy_route("claude-sonnet-5", "openai_tools_route"))
        assert.equals("openai", providers.cliproxy_route("claude-sonnet-5", "openai_search_model"))
        assert.equals("openai", providers.cliproxy_route("claude-sonnet-5", "none"))
        assert.equals("openai", providers.cliproxy_route("claude-sonnet-5", nil))
    end)

    it("routes a non-anthropic model to openai regardless of strategy", function()
        assert.equals("openai", providers.cliproxy_route("gpt-5.6-sol", "anthropic_tools_route"))
        assert.equals("openai", providers.cliproxy_route("gpt-5.6-sol", "openai_tools_route"))
        assert.equals("openai", providers.cliproxy_route("gemini-3-pro-preview", "anthropic_tools_route"))
    end)

    it("routes a nil or non-string model name to openai", function()
        assert.equals("openai", providers.cliproxy_route(nil, "anthropic_tools_route"))
        assert.equals("openai", providers.cliproxy_route(42, "anthropic_tools_route"))
    end)

    -- INTENTIONAL behaviour change, not pure extraction (#198). The old
    -- cliproxyapi_encode_tools tested `^claude%-` alone, so it RAISED for a
    -- code_execution_* model even though format_payload routed that model to
    -- the anthropic wire. The two disagreed; the shared helper settles it in
    -- favour of format_payload, which was right.
    it("routes code_execution_* models to the anthropic wire", function()
        assert.equals("anthropic",
            providers.cliproxy_route("code_execution_claude-sonnet-5", "anthropic_tools_route"))
    end)
end)

describe("providers.cliproxy_strategy", function()
    it("reads the strategy off the model table when present", function()
        assert.equals("anthropic_tools_route",
            providers.cliproxy_strategy({ model = "claude-sonnet-5",
                web_search_strategy = "anthropic_tools_route" }))
    end)

    it("falls back to the provider-level config when the model has none", function()
        -- The config default is openai_tools_route; the point of exposing
        -- this is that consumers must NOT re-implement the fallback by
        -- reading model.web_search_strategy directly.
        local parley = require("parley")
        local configured = parley.dispatcher
            and parley.dispatcher.providers
            and parley.dispatcher.providers.cliproxyapi
            and parley.dispatcher.providers.cliproxyapi.web_search_strategy
        local got = providers.cliproxy_strategy({ model = "gpt-5.6-sol" })
        if configured then
            assert.equals(configured, got)
        else
            -- parley not set up in this process: documented "none" fallback
            assert.equals("none", got)
        end
    end)

    it("ignores an unrecognised strategy on the model table", function()
        local got = providers.cliproxy_strategy({ model = "x", web_search_strategy = "bogus" })
        assert.are_not.equals("bogus", got)
    end)
end)
