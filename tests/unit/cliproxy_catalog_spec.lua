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
        -- gemini-pro-agent's id carries no version; it displays as
        -- "Gemini 3.1 Pro (High)". An id-only match makes antigravity unfilterable.
        assert.is_true(vim.tbl_contains(ids("antigravity:pro"), "gemini-pro-agent"))
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

    it("routes an antigravity-served claude model over the anthropic wire", function()
        -- owner is the display grouping; the WIRE follows the model family.
        local a = cat.build_agent({ id = "claude-opus-4-6-thinking", owner = "antigravity" })
        assert.equals("anthropic_tools_route", a.model.web_search_strategy)
    end)
end)
