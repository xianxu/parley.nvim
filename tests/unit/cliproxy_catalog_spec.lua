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
    it("never collapses a non-empty id to an empty key", function()
        for _, id in ipairs({ "2026", "1.2.3", "-", "5-5-5", "8x7" }) do
            assert.is_true(#cat.series(id) > 0,
                ("series(%q) collapsed to empty"):format(id))
        end
    end)

    it("has nothing to return for an empty id, which parse never emits", function()
        -- The empty id is handled at the boundary instead: a row with no id is
        -- not a model, so parse drops it rather than letting every such row
        -- share one empty series key.
        assert.equals("", cat.series(""))
        local dropped = cat.parse(
            [[{"data":[{"id":"","owned_by":"openai"},{"id":"real-1","owned_by":"openai"}]}]],
            [[{"models":[]}]])
        assert.equals(1, #dropped)
        assert.equals("real-1", dropped[1].id)
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

    it("reads a magnitude as a magnitude, whatever its size", function()
        -- The rule is DELIMITED-or-not, not big-or-small. A magnitude threshold
        -- (the first attempt at this) only excludes the sizes that happen to be
        -- large: under `< 100`, "GPT-OSS 20B" reads as version 20 and outranks
        -- every real release. Each case below is a magnitude that would slip
        -- through such a threshold.
        local gemini = cat.rank_key({ display = "Gemini 3.7 Flash" })
        for _, magnitude in ipairs({ "GPT-OSS 20B (Medium)", "Llama 70B", "Ctx 32K", "Mixtral 8x7B" }) do
            assert.is_true(gemini > cat.rank_key({ display = magnitude }),
                ("%q outranked a real version"):format(magnitude))
        end
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

    -- THE RULE, not four examples: every row in the Spec's render table is
    -- pinned here as an EQUALITY on that row's exact spec string. Equality, not
    -- containment — order is part of the render, and a containment check is how
    -- the rank_key ordering defect stayed invisible through two rounds. A new
    -- Spec row means a new entry here; these are captured from the live catalog,
    -- so a failure means either the catalog moved or the code broke — never that
    -- the expectation should be edited to match the code.
    local SPEC_RENDERS = {
        ["claude:opus,sonnet"] = { "claude-opus-5", "claude-sonnet-5" },
        ["claude"] = { "claude-opus-5", "claude-sonnet-5", "claude-fable-5" },
        ["codex:gpt-5.6"] = { "gpt-5.6-luna", "gpt-5.6-sol", "gpt-5.6-terra" },
        ["antigravity:pro,flash"] = { "gemini-3.1-pro-low", "gemini-pro-agent",
                                      "gemini-3.7-flash-high" },
        ["antigravity"] = { "claude-opus-4-6-thinking", "claude-sonnet-4-6",
                            "gemini-3.7-flash-high" },
    }

    for spec, expected in pairs(SPEC_RENDERS) do
        it(("renders the documented row for %q"):format(spec), function()
            assert.same(expected, ids(spec))
        end)
    end

    it("matches displayName, not just id", function()
        -- gemini-pro-agent's id carries no "pro" version token at all; it
        -- displays as "Gemini 3.1 Pro (High)". An id-only match would make
        -- antigravity unfilterable — and it is in the documented row above.
        assert.is_true(vim.tbl_contains(SPEC_RENDERS["antigravity:pro,flash"],
            "gemini-pro-agent"))
    end)

    it("orders by term, so config expresses preference", function()
        assert.equals("claude-sonnet-5", ids("claude:sonnet,opus")[1])
    end)

    it("caps at per_provider", function()
        assert.equals(2, #ids("claude", 2))
    end)

    it("does not let a parameter count outrank a version", function()
        -- "GPT-OSS 120B (Medium)" has no `created`, like every antigravity row.
        -- If 120 were read as its version it would sort above every Gemini
        -- release. Covered by the documented "antigravity" row above; asserted
        -- here directly so the reason is legible.
        local cat_local = require("parley.cliproxy_catalog")
        assert.is_true(
            cat_local.rank_key({ display = "Gemini 3.7 Flash" })
            > cat_local.rank_key({ display = "GPT-OSS 120B (Medium)" }))
    end)

    it("contributes nothing for a provider it does not know", function()
        -- A typo like "claud" resolves to owner=nil, and `m.owner == owner`
        -- would then pool every row whose owned_by is ABSENT — offering
        -- unrelated models under a heading the operator mistyped.
        local models_with_ownerless = { { id = "orphan-1", series = "orphan" } }
        assert.same({}, cat.curate(models_with_ownerless,
            { providers = { "claud" }, per_provider = 3 }))
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

    it("disables it for what antigravity serves — except where that would move the wire", function()
        -- gpt-oss-120b-medium is gpt-family by id but antigravity-owned; measured,
        -- it answers while never actually searching, so the tool is not sent.
        assert.equals("none",
            providers.cliproxy_default_web_search_strategy("gpt-oss-120b-medium", "antigravity"))
    end)

    it("never lets owner reach the wire decision", function()
        -- This value also selects the transport, and `owner` is unstable for a
        -- shared id — claude-sonnet-4-6 was reported under `anthropic` on one
        -- proxy start and `antigravity` on the next. If owner could win here,
        -- the same model would speak a different protocol on different days.
        -- Measured: claude-opus-4-6-thinking answers 200 on the anthropic wire
        -- through antigravity, so family wins and the wire stays put.
        assert.equals("anthropic_tools_route",
            providers.cliproxy_default_web_search_strategy("claude-opus-4-6-thinking", "antigravity"))
        assert.equals(
            providers.cliproxy_default_web_search_strategy("claude-sonnet-4-6", "anthropic"),
            providers.cliproxy_default_web_search_strategy("claude-sonnet-4-6", "antigravity"))
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

    it("returns nil for a row with no usable id, instead of raising", function()
        -- The callers are a picker callback and a session restore; an error
        -- there surfaces as a stack trace over the UI or aborts setup.
        assert.is_nil(cat.build_agent({ owner = "anthropic" }))
        assert.is_nil(cat.build_agent({ id = "", owner = "anthropic" }))
        assert.is_nil(cat.build_agent(nil))
    end)

    it("names the agent after the model with the cliproxy marker", function()
        assert.equals("claude-opus-5*",
            cat.build_agent({ id = "claude-opus-5", owner = "anthropic" }).name)
    end)

    it("forwards the owner, without letting it move a claude model's wire", function()
        -- build_agent must pass `owner` (it decides the search tool for gemini
        -- and gpt-oss rows), but a claude model keeps the anthropic wire whoever
        -- serves it — otherwise an unstable owner would change the transport.
        local a = cat.build_agent({ id = "claude-opus-4-6-thinking", owner = "antigravity" })
        assert.equals("anthropic_tools_route", a.model.web_search_strategy)
        local b = cat.build_agent({ id = "gpt-oss-120b-medium", owner = "antigravity" })
        assert.equals("none", b.model.web_search_strategy)
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

--------------------------------------------------------------------------------
-- catalog_stale: pure, so it needs no clock, no seams and no curl (#205 BR-67)
--------------------------------------------------------------------------------
describe("catalog_stale", function()
    local cc = require("parley.cliproxy_config")
    local BASE = { now = 1000, ttl = 600, backoff = 30 }

    local function stale(over)
        return cc.catalog_stale(vim.tbl_extend("force", BASE, over))
    end

    it("is stale with nothing cached and nothing tried", function()
        assert.is_true(stale({}))
    end)

    it("is fresh while the cache is inside the TTL", function()
        assert.is_false(stale({ cached_at = 500 }))   -- 500s old, ttl 600
    end)

    it("is stale once the cache passes the TTL", function()
        assert.is_true(stale({ cached_at = 300 }))    -- 700s old
    end)

    it("backs off briefly after a failed attempt", function()
        assert.is_false(stale({ last_attempt = 980 })) -- 20s ago, backoff 30
    end)

    it("does not let a failure back off for the whole success TTL", function()
        -- The regression this pins: a failure keyed on `ttl` silenced the picker
        -- for ten minutes, including right after a login through a
        -- "(logged out)" row.
        assert.is_true(stale({ last_attempt = 900 }))  -- 100s ago: past backoff
    end)

    it("lets an explicit invalidation outrank a fresh cache", function()
        -- A "(logged out)" row exists BECAUSE a successful fetch lacked that
        -- provider's models, so the cache IS fresh at the moment of login.
        assert.is_false(stale({ cached_at = 999 }))
        assert.is_true(stale({ cached_at = 999, forced = true }))
    end)
end)
