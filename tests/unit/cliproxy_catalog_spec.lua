-- Unit tests for lua/parley/cliproxy_catalog.lua (issue #205).
-- Pure catalog core: no IO, no mocks. Driven by fixtures captured from a real
-- proxy (tests/fixtures/cliproxy_catalog_v1*.json), so the awkward shapes —
-- rows with no `created`, ids that don't match their display name — are in the
-- test data rather than imagined.

local cat = require("parley.cliproxy_catalog")

local function fixture(name)
    local fd = assert(io.open("tests/fixtures/" .. name, "r"))
    local body = fd:read("*a")
    fd:close()
    return body
end

local V1 = fixture("cliproxy_catalog_v1.json")
local V1BETA = fixture("cliproxy_catalog_v1beta.json")

--------------------------------------------------------------------------------
-- series
--------------------------------------------------------------------------------
describe("series", function()
    it("strips version numerals to the model line", function()
        assert.equals("claude-opus", cat.series("claude-opus-5"))
        assert.equals("claude-opus", cat.series("claude-opus-4-8"))
        assert.equals("claude-sonnet", cat.series("claude-sonnet-4-5-20250929"))
        assert.equals("gpt-sol", cat.series("gpt-5.6-sol"))
    end)

    it("keeps distinct product lines apart", function()
        assert.are_not.equals(cat.series("gpt-5.6-sol"), cat.series("gpt-5.6-luna"))
    end)

    it("returns a stable non-empty key for an all-numeric tail", function()
        assert.equals("gpt-image", cat.series("gpt-image-2"))
    end)

    -- Strategy for the malformed class, not more examples: ids are
    -- vendor-controlled and series() is the only pattern mangler over them.
    it("never returns an empty key, whatever the id", function()
        for _, id in ipairs({ "2026", "1.2.3", "-", "5-5-5" }) do
            assert.is_true(#cat.series(id) > 0,
                ("series(%q) collapsed to empty"):format(id))
        end
    end)

    it("keeps distinct alphabetic stems distinct", function()
        assert.are_not.equals(cat.series("alpha-1"), cat.series("beta-1"))
    end)
end)

--------------------------------------------------------------------------------
-- parse
--------------------------------------------------------------------------------
describe("parse", function()
    local models = cat.parse(V1, V1BETA)

    local function by_id(id)
        for _, m in ipairs(models) do
            if m.id == id then return m end
        end
    end

    it("joins displayName from the v1beta route onto the v1 rows", function()
        assert.equals("Claude Opus 5", by_id("claude-opus-5").display)
        assert.equals("anthropic", by_id("claude-opus-5").owner)
    end)

    it("keeps rows that carry no created (antigravity)", function()
        local m = by_id("gemini-pro-agent")
        assert.is_not_nil(m)
        assert.is_nil(m.created)
        -- the id is an opaque handle; displayName is the truth for this provider
        assert.equals("Gemini 3.1 Pro (High)", m.display)
    end)

    it("falls back to the id when v1beta has no row", function()
        local only_v1 = [[{"data":[{"id":"mystery-1","owned_by":"openai","created":5}]}]]
        local m = cat.parse(only_v1, [[{"models":[]}]])[1]
        assert.equals("mystery-1", m.display)
    end)

    it("returns an empty list for undecodable input rather than raising", function()
        assert.same({}, cat.parse("not json", "not json"))
    end)
end)

--------------------------------------------------------------------------------
-- rank_key
--------------------------------------------------------------------------------
describe("rank_key", function()
    it("prefers created when present", function()
        assert.is_true(cat.rank_key({ created = 200, display = "X 1" })
                     > cat.rank_key({ created = 100, display = "X 9" }))
    end)

    it("orders created-less rows by the version in displayName", function()
        assert.is_true(cat.rank_key({ display = "Gemini 3.7 Flash" })
                     > cat.rank_key({ display = "Gemini 3.1 Pro (Low)" }))
    end)

    it("never ranks a created-less row above a dated one", function()
        -- The load-bearing case: version numbers and epoch seconds are different
        -- units, so the two must occupy disjoint bands rather than be compared.
        assert.is_true(cat.rank_key({ created = 1, display = "A 1" })
                     > cat.rank_key({ display = "Gemini 999999 Flash" }))
    end)
end)

--------------------------------------------------------------------------------
-- parse_provider_spec + curate
--------------------------------------------------------------------------------
describe("parse_provider_spec", function()
    it("splits provider from terms", function()
        assert.same({ provider = "claude", terms = { "opus", "sonnet" } },
            cat.parse_provider_spec("claude:opus,sonnet"))
    end)

    it("treats a bare provider as unfiltered", function()
        assert.same({ provider = "claude", terms = {} },
            cat.parse_provider_spec("claude"))
    end)

    it("ignores whitespace and empty terms", function()
        assert.same({ provider = "codex", terms = { "gpt-5.6" } },
            cat.parse_provider_spec("codex: gpt-5.6 , "))
    end)
end)

describe("curate", function()
    local models = cat.parse(V1, V1BETA)
    local function ids(spec, per)
        local out = {}
        for _, m in ipairs(cat.curate(models, { providers = { spec }, per_provider = per or 3 })) do
            out[#out + 1] = m.id
        end
        return out
    end

    -- These expectations are real renders captured from the live catalog on
    -- 2026-08-31. If one fails, decide whether the catalog moved or the code
    -- broke — don't edit the expectation to match the code.
    it("filters to the named families, newest of each", function()
        assert.same({ "claude-opus-5", "claude-sonnet-5" }, ids("claude:opus,sonnet"))
    end)

    it("takes the newest per series when unfiltered", function()
        assert.same({ "claude-opus-5", "claude-sonnet-5", "claude-fable-5" }, ids("claude"))
    end)

    it("keeps sibling variants of one release apart", function()
        assert.same({ "gpt-5.6-luna", "gpt-5.6-sol", "gpt-5.6-terra" }, ids("codex:gpt-5.6"))
    end)

    it("matches displayName, not just id", function()
        -- gemini-pro-agent's id carries no version and no "pro" version token; it
        -- displays as "Gemini 3.1 Pro (High)". An id-only match would make
        -- antigravity unfilterable. Asserted as the FULL render, not containment:
        -- this is the one case exercising displayName matching and created-less
        -- ranking together, so its ordering is part of what's under test.
        assert.same({ "gemini-3.1-pro-low", "gemini-pro-agent" }, ids("antigravity:pro"))
    end)

    it("does not let a parameter count outrank a version", function()
        -- "GPT-OSS 120B (Medium)" has no created, like every antigravity row. If
        -- 120 were read as its version it would sort above every Gemini release.
        local got = ids("antigravity", 3)
        assert.is_false(vim.tbl_contains(got, "gpt-oss-120b-medium"),
            "a 120B parameter count floated to the top of the provider")
    end)

    it("orders by term, so config expresses preference", function()
        assert.equals("claude-sonnet-5", ids("claude:sonnet,opus")[1])
    end)

    it("caps at per_provider", function()
        assert.equals(2, #ids("claude", 2))
    end)

    it("does not mutate the rows it was given", function()
        local before = vim.deepcopy(models)
        cat.curate(models, { providers = { "claude" }, per_provider = 3 })
        assert.same(before, models)
    end)
end)

--------------------------------------------------------------------------------
-- cliproxy_default_web_search_strategy (single source, lives in providers.lua)
--------------------------------------------------------------------------------
describe("cliproxy_default_web_search_strategy", function()
    local providers = require("parley.providers")

    it("routes claude models over the anthropic wire", function()
        assert.equals("anthropic_tools_route",
            providers.cliproxy_default_web_search_strategy("claude-opus-5"))
    end)

    it("keeps openai-family models on the openai tools route", function()
        assert.equals("openai_tools_route",
            providers.cliproxy_default_web_search_strategy("gpt-5.6-sol"))
    end)

    it("disables server-side search for gemini-family models", function()
        -- Measured: {type="web_search"} makes gemini answer with
        -- finish_reason="malformed_function_call" and no content.
        assert.equals("none",
            providers.cliproxy_default_web_search_strategy("gemini-3-flash"))
    end)

    it("disables it for anything antigravity serves, whatever the family", function()
        -- gpt-oss-120b-medium is gpt-family by id but antigravity-owned; measured,
        -- it answers without ever searching. A claude model served there is
        -- unmeasured, so it is not claimed to work either.
        assert.equals("none",
            providers.cliproxy_default_web_search_strategy("gpt-oss-120b-medium", "antigravity"))
        assert.equals("none",
            providers.cliproxy_default_web_search_strategy("claude-opus-4-6-thinking", "antigravity"))
    end)

    it("reuses the canonical anthropic family test, code_execution included", function()
        assert.equals("anthropic_tools_route",
            providers.cliproxy_default_web_search_strategy("code_execution_claude"))
    end)

    it("falls back to the openai route for an unrecognized model", function()
        assert.equals("openai_tools_route",
            providers.cliproxy_default_web_search_strategy("mystery-1"))
    end)
end)

--------------------------------------------------------------------------------
-- build_agent
--------------------------------------------------------------------------------
describe("build_agent", function()
    it("routes anthropic models over the anthropic wire", function()
        local a = cat.build_agent({ id = "claude-opus-5", owner = "anthropic",
                                    display = "Claude Opus 5" })
        assert.equals("cliproxyapi", a.provider)
        assert.equals("claude-opus-5", a.model.model)
        assert.equals("anthropic_tools_route", a.model.web_search_strategy)
        assert.same({ "@all" }, a.tools)
        assert.is_true(a.synthetic_system_prompt)
    end)

    it("leaves openai-family models on the openai tools route", function()
        local a = cat.build_agent({ id = "gpt-5.6-sol", owner = "openai" })
        assert.equals("openai_tools_route", a.model.web_search_strategy)
    end)

    it("ships a gemini pick with server-side search off, not broken", function()
        -- Measured: {type="web_search"} makes gemini answer with
        -- finish_reason="malformed_function_call" and no content.
        local a = cat.build_agent({ id = "gemini-3-flash", owner = "antigravity" })
        assert.equals("none", a.model.web_search_strategy)
        assert.same({ "@all" }, a.tools) -- client tools DO work for gemini
    end)

    it("names the agent after the model with the cliproxy marker", function()
        assert.equals("claude-opus-5*",
            cat.build_agent({ id = "claude-opus-5", owner = "anthropic" }).name)
    end)

    it("passes the owner through, so an antigravity-served claude gets none", function()
        -- The family alone would say anthropic_tools_route; the owner overrides,
        -- because server-side search does not survive antigravity's re-serving.
        -- build_agent must therefore forward `owner`, not just the id.
        local a = cat.build_agent({ id = "claude-opus-4-6-thinking", owner = "antigravity" })
        assert.equals("none", a.model.web_search_strategy)
    end)
end)

--------------------------------------------------------------------------------
-- The strategy has to SURVIVE the resolver (boundary review BR-2)
--------------------------------------------------------------------------------
describe("a built agent's strategy survives get_cliproxy_strategy", function()
    it("keeps `none` instead of falling back to the provider default", function()
        -- The bug this pins: the resolver whitelisted only the three ACTIVE
        -- strategies, so `none` fell through to providers.cliproxyapi's
        -- openai_tools_route — and a gemini pick shipped the very web_search
        -- payload build_agent chose "none" to avoid.
        local parley = require("parley")
        local saved = parley.dispatcher
        -- The provider default must be set to an ACTIVE strategy, or the
        -- fallback path returns "none" too and the test passes for the wrong
        -- reason — which is exactly what it did on first writing.
        parley.dispatcher = { providers = {
            cliproxyapi = { web_search_strategy = "openai_tools_route" },
        } }
        local ok, strategy = pcall(function()
            local agent = require("parley.cliproxy_catalog")
                .build_agent({ id = "gemini-3-flash", owner = "antigravity" })
            return require("parley.providers").cliproxy_strategy(agent.model)
        end)
        parley.dispatcher = saved
        assert.is_true(ok, tostring(strategy))
        assert.equals("none", strategy)
    end)
end)
