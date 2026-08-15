-- Unit tests for the providers-level tool encoders after #198.
--
-- Before this issue, openai_encode_tools raised outright and
-- cliproxyapi_encode_tools raised for any model not matching `^claude%-`.
-- The latter made its own routing decision, by a different test than
-- cliproxyapi.format_payload used — so the two could disagree about which
-- wire a request was on. Both now go through providers.cliproxy_route.

local providers = require("parley.providers")

local function defs()
    return {
        {
            name = "read_file",
            description = "Read a file.",
            input_schema = {
                type = "object",
                properties = { path = { type = "string" } },
                required = { "path" },
            },
            handler = function() end,
            kind = "read",
        },
    }
end

describe("providers.openai_encode_tools", function()
    it("no longer raises", function()
        assert.has_no.errors(function() providers.openai_encode_tools(defs()) end)
    end)

    it("emits the openai function envelope", function()
        local out = providers.openai_encode_tools(defs())
        assert.equals(1, #out)
        assert.equals("function", out[1].type)
        assert.equals("read_file", out[1]["function"].name)
        assert.is_not_nil(out[1]["function"].parameters)
        -- the anthropic field name must NOT leak through
        assert.is_nil(out[1].input_schema)
    end)

    it("accepts an empty list", function()
        assert.same({}, providers.openai_encode_tools({}))
    end)
end)

describe("providers.cliproxyapi_encode_tools", function()
    it("encodes openai-shaped tools for a non-anthropic model", function()
        local out = providers.cliproxyapi_encode_tools(defs(), { model = "gpt-5.6-sol" })
        assert.equals("function", out[1].type)
        assert.equals("read_file", out[1]["function"].name)
    end)

    it("encodes anthropic-shaped tools on the anthropic route", function()
        local out = providers.cliproxyapi_encode_tools(defs(), {
            model = "claude-sonnet-5",
            web_search_strategy = "anthropic_tools_route",
        })
        assert.is_not_nil(out[1].input_schema)
        assert.equals("read_file", out[1].name)
        assert.is_nil(out[1].type)
    end)

    -- The pairing that nothing enforced before #198: a claude model WITHOUT
    -- the strategy override takes the OpenAI payload path in format_payload,
    -- so its tools must be openai-shaped too. The old encoder keyed on
    -- `^claude%-` alone and would have emitted anthropic-shaped tools onto
    -- an OpenAI payload.
    it("follows the route, not the model family, for a claude model with no strategy", function()
        local out = providers.cliproxyapi_encode_tools(defs(), {
            model = "claude-sonnet-5",
            web_search_strategy = "openai_tools_route",
        })
        assert.equals("function", out[1].type)
    end)

    -- Used to raise: the encoder's `^claude%-` test excluded code_execution_*
    -- even though format_payload routed it to the anthropic wire.
    it("encodes a code_execution model on the anthropic route", function()
        local out = providers.cliproxyapi_encode_tools(defs(), {
            model = "code_execution_claude-sonnet-5",
            web_search_strategy = "anthropic_tools_route",
        })
        assert.is_not_nil(out[1].input_schema)
    end)

    it("accepts a bare model-name string", function()
        local out = providers.cliproxyapi_encode_tools(defs(), "gpt-5.6-sol")
        assert.equals("function", out[1].type)
    end)
end)

describe("cliproxyapi.format_payload route agreement", function()
    -- The invariant the shared helper exists to guarantee: whatever wire
    -- format_payload builds for, the encoder encodes for.
    local function route_of_payload(payload)
        -- the anthropic branch stamps _parley_route; the openai one does not
        return payload._parley_route == "anthropic" and "anthropic" or "openai"
    end

    local cases = {
        { model = { model = "claude-sonnet-5", web_search_strategy = "anthropic_tools_route" } },
        { model = { model = "claude-sonnet-5", web_search_strategy = "openai_tools_route" } },
        { model = { model = "gpt-5.6-sol" } },
        { model = { model = "gpt-5.6-sol", web_search_strategy = "anthropic_tools_route" } },
    }

    for _, case in ipairs(cases) do
        it("agrees for " .. case.model.model ..
           " / " .. tostring(case.model.web_search_strategy), function()
            local adapter = providers.get("cliproxyapi")
            local payload = adapter.format_payload(
                { { role = "user", content = "hi" } }, case.model, "cliproxyapi")
            local payload_route = route_of_payload(payload)

            local tools = providers.cliproxyapi_encode_tools(defs(), case.model)
            local tools_route = tools[1].type == "function" and "openai" or "anthropic"

            assert.equals(payload_route, tools_route)
        end)
    end
end)
