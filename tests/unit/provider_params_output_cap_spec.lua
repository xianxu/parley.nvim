-- Tests for provider_params.raise_output_cap (#198 close review I1).
--
-- The output-token cap is not always spelled `max_tokens`: gpt-5 renames it to
-- `max_completion_tokens`, googleai to `maxOutputTokens`. skill_invoke's
-- large-document headroom bump wrote `max_tokens` directly, which on a
-- renaming model did two wrong things at once — left the REAL cap at its 4096
-- default (causing the very truncation the bump exists to prevent) and added a
-- key that family's API rejects.
--
-- That path became reachable when #198 widened the skill tool-capable
-- predicate to OpenAI-family agents.

local pp = require("parley.provider_params")

describe("provider_params.raise_output_cap", function()
    it("writes max_completion_tokens for gpt-5 and leaves max_tokens absent", function()
        local payload = { max_completion_tokens = 4096 }
        local key = pp.raise_output_cap(payload, "openai", { model = "gpt-5.4" }, 100000)
        assert.equals("max_completion_tokens", key)
        assert.equals(100000, payload.max_completion_tokens)
        assert.is_nil(payload.max_tokens)
    end)

    it("writes max_completion_tokens for a gpt-5 model on cliproxyapi", function()
        -- The concrete #198 agent: ToolSol* / gpt-5.6-sol.
        local payload = { max_completion_tokens = 4096 }
        local key = pp.raise_output_cap(payload, "cliproxyapi", { model = "gpt-5.6-sol" }, 100000)
        assert.equals("max_completion_tokens", key)
        assert.equals(100000, payload.max_completion_tokens)
        assert.is_nil(payload.max_tokens)
    end)

    it("writes max_tokens for anthropic", function()
        local payload = { max_tokens = 4096 }
        local key = pp.raise_output_cap(payload, "anthropic", { model = "claude-sonnet-5" }, 100000)
        assert.equals("max_tokens", key)
        assert.equals(100000, payload.max_tokens)
        assert.is_nil(payload.max_completion_tokens)
    end)

    it("writes maxOutputTokens for googleai", function()
        local payload = { maxOutputTokens = 8192 }
        local key = pp.raise_output_cap(payload, "googleai", { model = "gemini-3-pro-preview" }, 100000)
        assert.equals("maxOutputTokens", key)
        assert.equals(100000, payload.maxOutputTokens)
        assert.is_nil(payload.max_tokens)
    end)

    it("never LOWERS an already-higher cap", function()
        local payload = { max_tokens = 200000 }
        pp.raise_output_cap(payload, "anthropic", { model = "claude-sonnet-5" }, 100000)
        assert.equals(200000, payload.max_tokens)
    end)

    it("sets the cap when the payload carries none", function()
        local payload = {}
        pp.raise_output_cap(payload, "anthropic", { model = "claude-sonnet-5" }, 100000)
        assert.equals(100000, payload.max_tokens)
    end)

    -- THE invariant, rather than a hand-listed table of models: whatever key
    -- resolve_params decided to write into the payload is the key
    -- raise_output_cap must raise. Anything else either misses the real cap or
    -- adds a name the model renamed away — the two halves of the bug this
    -- helper replaced.
    it("always raises the same key resolve_params writes", function()
        local cases = {
            { "openai", "gpt-5.4" },
            { "openai", "gpt-4o" },
            { "openai", "gpt-5-search-api" },
            { "cliproxyapi", "gpt-5.6-sol" },
            { "cliproxyapi", "claude-sonnet-5" },
            { "anthropic", "claude-sonnet-5" },
            { "googleai", "gemini-3-pro-preview" },
            { "ollama", "llama3" },
        }
        for _, c in ipairs(cases) do
            local provider, model = c[1], c[2]
            local resolved = pp.resolve_params(provider, { model = model })
            -- which key did resolve_params actually emit for the cap?
            local emitted
            for _, name in ipairs({ "max_tokens", "max_completion_tokens", "maxOutputTokens" }) do
                if resolved[name] ~= nil then emitted = name end
            end

            local payload = vim.deepcopy(resolved)
            local key = pp.raise_output_cap(payload, provider, { model = model }, 100000)

            assert.equals(emitted, key,
                ("%s/%s: resolve_params wrote %s but raise_output_cap wrote %s")
                    :format(provider, model, tostring(emitted), tostring(key)))
            if emitted then
                assert.equals(100000, payload[emitted],
                    ("%s/%s: effective cap did not move"):format(provider, model))
                -- and no sibling name was invented alongside it
                for _, name in ipairs({ "max_tokens", "max_completion_tokens", "maxOutputTokens" }) do
                    if name ~= emitted then
                        assert.is_nil(payload[name],
                            ("%s/%s: invented %s"):format(provider, model, name))
                    end
                end
            end
        end
    end)

    it("tolerates a bare model-name string", function()
        local payload = {}
        assert.equals("max_completion_tokens",
            pp.raise_output_cap(payload, "openai", "gpt-5.4", 100000))
    end)
end)

describe("skill_invoke headroom, end to end through prepare_payload", function()
    local dispatcher = require("parley.dispatcher")

    -- Drives the REAL payload builder, then applies the bump the skill driver
    -- applies, and asserts the EFFECTIVE cap actually moved. The pre-fix code
    -- passed a naive "payload.max_tokens == 100000" check while the real cap
    -- stayed at 4096.
    local function effective_cap(provider, model)
        local payload = dispatcher.prepare_payload(
            { { role = "user", content = "hi" } }, model, provider, nil)
        pp.raise_output_cap(payload, provider, model, 100000)
        return payload.max_completion_tokens or payload.max_tokens, payload
    end

    it("raises the effective cap for gpt-5.6-sol on cliproxyapi", function()
        local cap, payload = effective_cap("cliproxyapi", { model = "gpt-5.6-sol" })
        assert.equals(100000, cap)
        assert.is_nil(payload.max_tokens, "must not add a key gpt-5 renamed away")
    end)

    it("raises the effective cap for gpt-5.4 on openai", function()
        local cap, payload = effective_cap("openai", { model = "gpt-5.4" })
        assert.equals(100000, cap)
        assert.is_nil(payload.max_tokens)
    end)

    it("still raises the effective cap for anthropic", function()
        local cap = effective_cap("anthropic", { model = "claude-sonnet-5" })
        assert.equals(100000, cap)
    end)
end)
