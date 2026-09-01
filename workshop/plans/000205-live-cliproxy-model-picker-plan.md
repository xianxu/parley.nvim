# Live cliproxy model picker Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Offer cliproxyapi's live model catalog in the agent picker so no cliproxyapi model is ever named in `config.lua` again.

**Architecture:** A pure catalog core (`cliproxy_catalog.lua`) parses the proxy's two model routes, applies the operator's `provider:term,term` filters, and curates a short per-provider list. A thin IO shell in `cliproxy.lua` fetches and disk-caches that catalog; `agent_picker.lua` renders it as a live section and turns a selection into a session-registered cliproxyapi agent. Finally `oauth-model-alias` is deleted and model→channel resolution derives from the catalog.

**Tech Stack:** Lua 5.1 / LuaJIT (Neovim), plenary.nvim busted specs, `vim.system` + curl for IO, the existing `tests/fixtures/fake_cliproxy` process fake.

**Spec:** `workshop/issues/000205-live-cliproxy-model-picker.md`

**The issue file is the record of progress, not this plan's checkboxes.** The
`- [ ]` boxes below are a reading aid; `## Plan` in the issue carries the milestone
state that `sdlc` ticks and the close gate reads. Do not infer "nothing is done"
from unticked boxes here.

---

## Core concepts

### Pure entities (the conceptual core)

| Name | Lives in | Status |
|------|----------|--------|
| `Model` (record) | `lua/parley/cliproxy_catalog.lua` | new |
| `parse` | `lua/parley/cliproxy_catalog.lua` | new |
| `series` | `lua/parley/cliproxy_catalog.lua` | new |
| `rank_key` | `lua/parley/cliproxy_catalog.lua` | new |
| `parse_provider_spec` | `lua/parley/cliproxy_catalog.lua` | new |
| `curate` | `lua/parley/cliproxy_catalog.lua` | new |
| `build_agent` | `lua/parley/cliproxy_catalog.lua` | new |
| `agent_name` | `lua/parley/cliproxy_catalog.lua` | new |
| `cliproxy_default_web_search_strategy` | `lua/parley/providers.lua` | new |
| `get_cliproxy_strategy` | `lua/parley/providers.lua` | modified |
| `resolve_channel` | `lua/parley/cliproxy_config.lua` | modified |
| `_build_items` | `lua/parley/agent_picker.lua` | modified |
| `_providers_without_models` | `lua/parley/agent_picker.lua` | new |
| `_view_for` | `lua/parley/agent_picker.lua` | new |
| `key_for` | `lua/parley/keybinding_registry.lua` | new |

- **Model** — one catalog row: `{ id, owner, created, display, description, series }`. The join of `/v1/models` (carries `created`) and `/v1beta/models` (carries `displayName`/`description`) on `id`.
  - **Relationships:** N:1 with provider (via `PROVIDER_OWNED_BY`); N:1 with series.
  - **DRY rationale:** One row shape for the picker, the curation, and the agent constructor. Without it each consumer re-reaches into raw JSON with a different idea of which field is authoritative.
  - **Future extensions:** `input_token_limit` is already present for google rows; a context-window column widens here.

- **series** — the id with version numerals stripped (`claude-opus-5` → `claude-opus`), so "newest of this line" is expressible.
  - **DRY rationale:** Curation, dedupe and ordering all need the same notion of "same model line". First occurrence of a pattern that recurs the moment a second provider is added.

- **rank_key** — recency for ordering: `created` when present, else the version parsed from `displayName`. Exists because **all 13 antigravity rows carry no `created`** (measured 2026-08-31); a `created`-only sort silently pins that provider's order to JSON order.

- **parse_provider_spec** — `"claude:opus,sonnet"` → `{ provider = "claude", terms = { "opus", "sonnet" } }`. Split on `:` then `,`; empty filter means "no filter".

- **curate** — filter → dedupe by series → rank → cap at `per_provider`. Term order is display order.
  - **Future extensions:** a `min_created` cut, or per-provider `per_provider` overrides, widen the opts table.

- **build_agent** — a `Model` plus config defaults → a parley agent table. Lives beside the catalog deliberately: it consumes a `Model` field-by-field, so the two change together (skill heuristic: files that change together live together).

### Integration points (where pure meets the world)

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `fetch_catalog` | `lua/parley/cliproxy.lua` | new | HTTP GET on the proxy |
| `catalog_cached` / `_write_catalog` / `_catalog_path` | `lua/parley/cliproxy.lua` | new | filesystem (`stdpath('data')`) |
| `catalog_stale` | `lua/parley/cliproxy.lua` | new | clock + filesystem |
| `register_live_agent` | `lua/parley/init.lua` | new | `state.json` |
| `_select` | `lua/parley/agent_picker.lua` | new | `vim.cmd` / `vim.schedule` |
| `selected` (handle) | `lua/parley/float_picker.lua` | new | picker window state |
| `invalidate_catalog` / `_reset_catalog_clock` / `_set_failed_attempt_at` | `lua/parley/cliproxy.lua` | new | the staleness clocks |
| `agent_picker` live section | `lua/parley/agent_picker.lua` | modified | `float_picker` handle |
| live-agent restore | `lua/parley/init.lua` | modified | `state.json` |
| `/v1beta/models` route | `tests/fixtures/fake_cliproxy` | modified | the cliproxy binary |

- **fetch_catalog** — two GETs through the existing `api_argv` helper (ARCH-DRY: the same argv builder the health probe, `list_models` and the management reader already use), joined by `parse`.
  - **Injected into:** nothing pure — it *produces* the input `curate` consumes. Specs drive `parse`/`curate` from fixtures with no IO.
- **catalog_cached / _write_catalog** — JSON at `<data_root>/catalog.json`, `data_root()` already test-redirected by `M._set_data_dir`.
  - **Injected into:** the picker reads the cache synchronously; the network path only ever writes it.
- **_providers_without_models** (pure, in `agent_picker.lua`) — a configured
  provider the catalog advertises nothing for is one you are not logged into:
  cliproxy registers a channel's models only once it has a credential (measured —
  antigravity's 13 models appeared the moment its auth file landed). That keeps
  the check synchronous on a UI path and needs no management call. A credential
  that is loaded but DEAD still lists models; #197's dispatch-failure path owns
  that case.
- **fake_cliproxy** — the stateful process fake gains `/v1beta/models` extending its existing `healthy` mode with the awkward shapes (no new mode:
the fixture's mode list is `healthy|needs_login|client_key_mismatch|foreign|slow|crash`,
and the catalog is a property of a healthy proxy, not a sixth behaviour): rows without `created`, and one id claimed by two owners.

### Operating envelope (ARCH-CONSTRAINTS)

- **Interaction path:** picker open — UI response, keystroke-adjacent.
- **Latency budget:** opening the picker does **zero network work on the main thread**. It reads one cached JSON (~5 KB for today's 43 models — measured) and renders. Basis: measured catalog size.
- **Refresh:** async `vim.system`, `--max-time 2` (the existing `CURL_MAX_TIME`). Exactly 2 GETs, at most one refresh in flight (module-local guard). When it exceeds the budget or the proxy is down, the cached list stays on screen and the failure is logged at debug — never a popup on a UI path.
- **Never spawns the proxy.** The refresh is a plain GET; a connection-refused is a no-op. It deliberately does **not** call `ensure_running`, so the "#131 dormant unless a cliproxyapi agent runs" contract holds.
- **Staleness:** three inputs, not one clock — a successful cache is fresh for
  10 min; a FAILED attempt backs off ~30s (a failure keyed on the success TTL
  silences the picker while the proxy recovers); and a completed login
  invalidates outright, since `catalog_stale` short-circuits on a fresh cache and
  a `(logged out)` row exists exactly when the cache IS fresh. Basis: operator choice, informed by a measured fact — an antigravity login registered 13 new models mid-session with no restart, so a long TTL would show a stale provider set.
- **Scale:** catalog is O(50) rows; curation is O(n log n) on a list that small. N/A for memory, concurrency, disk.

---

## Chunk 1: M1 — the pure catalog core

### Task 1.1: Capture real fixtures

**Files:**
- Create: `tests/fixtures/cliproxy_catalog_v1.json`, `tests/fixtures/cliproxy_catalog_v1beta.json`

- [ ] **Step 1: Capture both routes from a running proxy**

```bash
KEY="${CLIPROXYAPI_API_KEY:-parley-local}"
curl -s -H "Authorization: Bearer $KEY" http://127.0.0.1:8317/v1/models \
  | python3 -m json.tool > tests/fixtures/cliproxy_catalog_v1.json
curl -s -H "Authorization: Bearer $KEY" http://127.0.0.1:8317/v1beta/models \
  | python3 -m json.tool > tests/fixtures/cliproxy_catalog_v1beta.json
```

- [ ] **Step 2: Verify the fixture keeps the awkward rows**

The fixture is worthless without them — they are the cases the code exists to handle.

```bash
python3 -c "
import json
v1=json.load(open('tests/fixtures/cliproxy_catalog_v1.json'))['data']
assert any('created' not in m for m in v1), 'need antigravity rows lacking created'
assert any(m['owned_by']=='antigravity' for m in v1), 'need an antigravity owner'
print('rows:', len(v1), '| no-created:', sum(1 for m in v1 if 'created' not in m))
"
```
Expected: `rows: 43 | no-created: 13` (counts may drift; both must be non-zero)

- [ ] **Step 3: Commit**

```bash
git add tests/fixtures/cliproxy_catalog_v1.json tests/fixtures/cliproxy_catalog_v1beta.json
git commit -m "#205 M1: capture real cliproxy catalog fixtures"
```

### Task 1.2: `series`

**Files:**
- Create: `lua/parley/cliproxy_catalog.lua`
- Test: `tests/unit/cliproxy_catalog_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
local cat = require("parley.cliproxy_catalog")

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

    -- Strategy for the malformed class, not seven more examples: ids are
    -- vendor-controlled and series() is the only pattern mangler over them.
    it("never returns an empty key, whatever the id", function()
        for _, id in ipairs({ "2026", "1.2.3", "-", "5-5-5", "" }) do
            assert.is_true(#cat.series(id) > 0 or id == "",
                ("series(%q) collapsed to empty"):format(id))
        end
    end)

    it("keeps distinct alphabetic stems distinct", function()
        assert.are_not.equals(cat.series("alpha-1"), cat.series("beta-1"))
    end)
end)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: FAIL — `module 'parley.cliproxy_catalog' not found`

- [ ] **Step 3: Implement**

```lua
--------------------------------------------------------------------------------
-- Pure catalog core for cliproxyapi's advertised models (issue #205).
--
-- No IO: every function here is deterministic and unit-tested against real
-- captured fixtures without mocks (ARCH-PURE). The fetch/cache shell lives in
-- parley/cliproxy.lua.
--------------------------------------------------------------------------------

local M = {}

--- The model LINE an id belongs to: the id with version numerals removed, so
--- claude-opus-5 and claude-opus-4-8 collapse to one series and the newest can
--- be picked. Sol/Luna/Terra stay distinct because their distinguishing token
--- is a word, not a number.
---
--- Derived from the id alone, deliberately. An earlier draft also specified a
--- displayName-derived stem for opaque-id providers; it was dropped because the
--- id rule already produces the correct curation for every verified case,
--- including antigravity's — "Gemini 3.1 Pro (Low)" and "(High)" are genuinely
--- different offerings and SHOULD stay separate series.
---@param id string
---@return string
function M.series(id)
    if type(id) ~= "string" then
        return ""
    end
    local s = id:gsub("%-?%d[%d%.%-]*", "-"):gsub("%-+", "-")
    s = s:gsub("^%-", ""):gsub("%-$", "")
    -- An all-numeral id strips to "", which would collapse every such model into
    -- one series and let curate drop all but one. Vendor-controlled input: fall
    -- back to the id itself rather than emit a colliding empty key.
    if s == "" then
        return id
    end
    return s
end

return M
```

- [ ] **Step 4: Run it and watch it pass**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua/parley/cliproxy_catalog.lua tests/unit/cliproxy_catalog_spec.lua
git commit -m "#205 M1: series key derives the model line from an id"
```

### Task 1.3: `parse` — join the two routes

**Files:**
- Modify: `lua/parley/cliproxy_catalog.lua`
- Test: `tests/unit/cliproxy_catalog_spec.lua`

- [ ] **Step 1: Write the failing test** (drive it from the real fixture, not a hand-written stub)

```lua
local function fixture(name)
    local path = "tests/fixtures/" .. name
    local fd = assert(io.open(path, "r"))
    local body = fd:read("*a")
    fd:close()
    return body
end

describe("parse", function()
    local models = cat.parse(fixture("cliproxy_catalog_v1.json"),
                             fixture("cliproxy_catalog_v1beta.json"))

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
```

- [ ] **Step 2: Run it and watch it fail**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: FAIL — `attempt to call field 'parse' (a nil value)`

- [ ] **Step 3: Implement**

```lua
--- Join cliproxy's two model routes into one row list.
---
--- Both are needed and neither is sufficient: /v1/models carries `created`
--- (the recency signal) and /v1beta/models carries `displayName` +
--- `description` (the only human-readable naming — and for antigravity the
--- only TRUTHFUL naming, since its ids are opaque handles).
---@param v1_json string    # body of GET /v1/models
---@param beta_json string  # body of GET /v1beta/models
---@return table[] # { { id, owner, created?, display, description, series }, … }
function M.parse(v1_json, beta_json)
    local ok, v1 = pcall(vim.json.decode, v1_json or "")
    if not ok or type(v1) ~= "table" or type(v1.data) ~= "table" then
        return {}
    end
    local beta_by_id = {}
    local beta_ok, beta = pcall(vim.json.decode, beta_json or "")
    if beta_ok and type(beta) == "table" and type(beta.models) == "table" then
        for _, m in ipairs(beta.models) do
            if type(m) == "table" and type(m.name) == "string" then
                beta_by_id[(m.name:gsub("^models/", ""))] = m
            end
        end
    end
    local out = {}
    for _, m in ipairs(v1.data) do
        if type(m) == "table" and type(m.id) == "string" then
            local b = beta_by_id[m.id] or {}
            out[#out + 1] = {
                id = m.id,
                owner = m.owned_by,
                created = tonumber(m.created),
                display = type(b.displayName) == "string" and b.displayName or m.id,
                description = type(b.description) == "string" and b.description or "",
                series = M.series(m.id),
            }
        end
    end
    return out
end
```

- [ ] **Step 4: Run it and watch it pass**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua/parley/cliproxy_catalog.lua tests/unit/cliproxy_catalog_spec.lua
git commit -m "#205 M1: parse joins /v1/models with /v1beta/models"
```

### Task 1.4: `rank_key` — order without `created`

**Files:**
- Modify: `lua/parley/cliproxy_catalog.lua`
- Test: `tests/unit/cliproxy_catalog_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
describe("rank_key", function()
    it("prefers created when present", function()
        local a = { created = 200, display = "X 1" }
        local b = { created = 100, display = "X 9" }
        assert.is_true(cat.rank_key(a) > cat.rank_key(b))
    end)

    it("orders created-less rows by the version in displayName", function()
        local hi = { display = "Gemini 3.7 Flash" }
        local lo = { display = "Gemini 3.1 Pro (Low)" }
        assert.is_true(cat.rank_key(hi) > cat.rank_key(lo))
    end)

    it("never ranks a created-less row above a dated one", function()
        local dated = { created = 1, display = "A 1" }
        local undated = { display = "Gemini 999 Flash" }
        assert.is_true(cat.rank_key(dated) > cat.rank_key(undated))
    end)
end)
```

The third case is the load-bearing one: version numbers and epoch seconds are
different units, so they must occupy disjoint bands rather than being compared.

- [ ] **Step 2: Run it and watch it fail**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: FAIL — `attempt to call field 'rank_key' (a nil value)`

- [ ] **Step 3: Implement**

```lua
--- Recency for ordering. Two disjoint bands, never mixed: a dated row ranks in
--- epoch seconds; a row with no `created` (every antigravity model — measured
--- 2026-08-31) ranks by the version parsed from its displayName, always BELOW
--- any dated row. Comparing a version number against epoch seconds directly
--- would put "Gemini 3.7" beneath every model ever dated.
---@param m table # a parsed Model
---@return number
function M.rank_key(m)
    if type(m.created) == "number" and m.created > 0 then
        return m.created
    end
    local n = tostring(m.display or ""):match("(%d+%.?%d*)")
    -- -1e9 not -1000: the bands must not overlap for ANY input. A parsed
    -- display version only has to reach 1000 to outrank a small epoch value.
    return -1e9 + (tonumber(n) or 0)
end
```

- [ ] **Step 4: Run it and watch it pass**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua/parley/cliproxy_catalog.lua tests/unit/cliproxy_catalog_spec.lua
git commit -m "#205 M1: rank_key orders created-less rows in their own band"
```

### Task 1.5: `parse_provider_spec` + `curate`

**Files:**
- Modify: `lua/parley/cliproxy_catalog.lua`
- Test: `tests/unit/cliproxy_catalog_spec.lua`

- [ ] **Step 1: Write the failing test** — these four cases are real renders captured from the live catalog on 2026-08-31 and recorded in the spec

```lua
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
    local models = cat.parse(fixture("cliproxy_catalog_v1.json"),
                             fixture("cliproxy_catalog_v1beta.json"))
    local function ids(spec)
        local out = {}
        for _, m in ipairs(cat.curate(models, { providers = { spec }, per_provider = 3 })) do
            out[#out + 1] = m.id
        end
        return out
    end

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
        -- gemini-pro-agent's id contains no version; it displays as
        -- "Gemini 3.1 Pro (High)". An id-only match makes antigravity unfilterable.
        assert.is_true(vim.tbl_contains(ids("antigravity:pro"), "gemini-pro-agent"))
    end)

    it("orders by term, so config expresses preference", function()
        local got = ids("claude:sonnet,opus")
        assert.equals("claude-sonnet-5", got[1])
    end)

    it("caps at per_provider", function()
        assert.equals(2, #cat.curate(models,
            { providers = { "claude" }, per_provider = 2 }))
    end)
end)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: FAIL — `attempt to call field 'parse_provider_spec' (a nil value)`

- [ ] **Step 3: Implement**

```lua
--- Parse one `live_models.providers` entry: "<provider>[:<term>[,<term>…]]".
---@param spec string
---@return table # { provider = string, terms = string[] }
function M.parse_provider_spec(spec)
    local provider, filter = tostring(spec or ""):match("^%s*([^:]-)%s*:?(.*)$")
    local terms = {}
    for term in tostring(filter or ""):gmatch("[^,]+") do
        term = term:match("^%s*(.-)%s*$")
        if term ~= "" then
            terms[#terms + 1] = term:lower()
        end
    end
    return { provider = provider, terms = terms }
end

local function matches(m, term)
    return m.id:lower():find(term, 1, true) ~= nil
        or tostring(m.display):lower():find(term, 1, true) ~= nil
end

--- The picker's default view: for each configured provider, the models matching
--- its terms, one per series (the newest), capped at `per_provider`.
---
--- Term order is display order, so the config expresses preference.
---@param models table[]  # from parse()
---@param opts table      # { providers = {"claude:opus,sonnet", …}, per_provider = 3, owned_by = fn }
---@return table[]
function M.curate(models, opts)
    opts = opts or {}
    local per = opts.per_provider or 3
    local owned_by = opts.owned_by or require("parley.cliproxy_config").provider_owned_by
    local out = {}
    for _, spec in ipairs(opts.providers or {}) do
        local parsed = M.parse_provider_spec(spec)
        local owner = owned_by(parsed.provider)
        local pool = {}
        for _, m in ipairs(models) do
            if m.owner == owner then
                pool[#pool + 1] = m
            end
        end
        table.sort(pool, function(a, b)
            local ra, rb = M.rank_key(a), M.rank_key(b)
            if ra ~= rb then return ra > rb end
            return a.id < b.id
        end)
        local taken, seen = {}, {}
        for _, term in ipairs(#parsed.terms > 0 and parsed.terms or { "" }) do
            for _, m in ipairs(pool) do
                if #taken >= per then break end
                if not seen[m.series] and (term == "" or matches(m, term)) then
                    seen[m.series] = true
                    taken[#taken + 1] = m
                end
            end
        end
        for _, m in ipairs(taken) do
            -- Copy before tagging: these rows are the disk cache's own tables,
            -- re-curated on every <C-a> toggle and background repaint, and this
            -- module promises to be side-effect-free (ARCH-PURE).
            local row = vim.tbl_extend("force", {}, m)
            row.provider = parsed.provider
            out[#out + 1] = row
        end
    end
    return out
end
```

- [ ] **Step 4: Run it and watch it pass**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: PASS — all six `curate` cases

- [ ] **Step 5: Commit**

```bash
git add lua/parley/cliproxy_catalog.lua tests/unit/cliproxy_catalog_spec.lua
git commit -m "#205 M1: curate filters, dedupes by series, caps per provider"
```

### Task 1.6: Single-source the family → web-search-strategy decision

**Files:**
- Modify: `lua/parley/providers.lua` (beside `is_cliproxy_anthropic_route_model:142`)
- Test: `tests/unit/provider_params_spec.lua` (or the nearest providers spec)

**Why this task exists:** three families need three different answers, and the
family test already has a canonical home. `providers.lua:170-179` records that
`is_cliproxy_anthropic_route_model` was extracted *because* two call sites had
drifted to two different tests. A fourth copy inside `build_agent` would
re-open exactly that (ARCH-DRY).

**Measured 2026-08-31 against the live proxy** — this is the whole reason the
decision is three-way and not two-way:

| family | server-side web search over cliproxy |
|---|---|
| `claude-*` | `anthropic_tools_route`; on the OpenAI route the response comes back empty |
| `gpt-*` / codex-owned | `openai_tools_route` — verified, returns a cited answer |
| gemini / antigravity | **neither.** `{type="web_search"}` makes `gemini-3-flash` answer with `finish_reason: "malformed_function_call"` and no content |

Client-side function tools work on the OpenAI route for **all three**, so
`tools = {"@all"}` stays unconditional; only the server-side search differs.

- [ ] **Step 1: Write the failing test**

```lua
local providers = require("parley.providers")

describe("cliproxy_default_web_search_strategy", function()
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
        -- finish_reason="malformed_function_call" and empty content. A live pick
        -- that shipped the openai tool here would be a BROKEN agent, so the
        -- honest default is no server-side search at all.
        assert.equals("none",
            providers.cliproxy_default_web_search_strategy("gemini-3-flash"))
        assert.equals("none",
            providers.cliproxy_default_web_search_strategy("gemini-pro-agent"))
    end)

    it("reuses the canonical anthropic family test, including code_execution", function()
        assert.equals("anthropic_tools_route",
            providers.cliproxy_default_web_search_strategy("code_execution_claude"))
    end)

    it("falls back to the openai route for an unrecognized model", function()
        assert.equals("openai_tools_route",
            providers.cliproxy_default_web_search_strategy("mystery-1"))
    end)
end)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: FAIL — `attempt to call field 'cliproxy_default_web_search_strategy'`

- [ ] **Step 3: Implement in `providers.lua`, reusing the existing family test**

```lua
--- The server-side web-search strategy a model can actually USE over cliproxy.
--- PURE. Single source for the three-way answer (ARCH-DRY) — the canonical
--- anthropic family test is reused here, never re-written.
---
--- Verified against the live proxy 2026-08-31:
---   claude-*  the OpenAI route returns an empty completion; the anthropic
---             route is what makes server-side web_search fire.
---   gpt-*     `{type="web_search"}` works and returns cited results.
---   gemini-*  `{type="web_search"}` yields finish_reason
---             "malformed_function_call" and NO content — it breaks the model.
---             Google's own `{google_search={}}` on the gemini route does work,
---             so a `google_tools_route` is a real future strategy; until it
---             exists the honest answer is "none" rather than a broken agent.
---@param model_name string
---@return "anthropic_tools_route"|"openai_tools_route"|"none"
function M.cliproxy_default_web_search_strategy(model_name)
    if is_cliproxy_anthropic_route_model(model_name) then
        return "anthropic_tools_route"
    end
    if type(model_name) == "string" and model_name:find("^gemini") then
        return "none"
    end
    return "openai_tools_route"
end
```

- [ ] **Step 4: Run it and watch it pass**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: PASS

- [ ] **Step 5: Verify "none" actually suppresses the tool**

`cliproxy_openai_payload` only attaches `{type="web_search"}` when the strategy
is `openai_tools_route`, so "none" already falls through — confirm with a test
that the payload for a gemini model carries no `tools` entry of that type.

- [ ] **Step 6: Commit**

```bash
git add lua/parley/providers.lua tests/unit/cliproxy_catalog_spec.lua
git commit -m "#205 M1: single-source the cliproxy web-search strategy per model family"
```

### Task 1.7: `build_agent`

**Files:**
- Modify: `lua/parley/cliproxy_catalog.lua`
- Test: `tests/unit/cliproxy_catalog_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
describe("build_agent", function()
    it("routes anthropic-owned models over the anthropic wire", function()
        local a = cat.build_agent({ id = "claude-opus-5", owner = "anthropic",
                                    display = "Claude Opus 5" })
        assert.equals("cliproxyapi", a.provider)
        assert.equals("claude-opus-5", a.model.model)
        assert.equals("anthropic_tools_route", a.model.web_search_strategy)
        assert.same({ "@all" }, a.tools)
        assert.is_true(a.synthetic_system_prompt)
    end)

    it("leaves openai-family models on the openai tools route", function()
        local a = cat.build_agent({ id = "gpt-5.6-sol", owner = "openai",
                                    display = "GPT 5.6 Sol" })
        assert.equals("openai_tools_route", a.model.web_search_strategy)
    end)

    it("ships a gemini pick with server-side search off, not broken", function()
        local a = cat.build_agent({ id = "gemini-3-flash", owner = "antigravity" })
        assert.equals("none", a.model.web_search_strategy)
        assert.same({ "@all" }, a.tools)  -- client tools DO work for gemini
    end)

    it("names the agent after the model with the cliproxy marker", function()
        assert.equals("claude-opus-5*",
            cat.build_agent({ id = "claude-opus-5", owner = "anthropic" }).name)
    end)

    it("routes an antigravity-served claude model over the anthropic wire", function()
        -- owner is the display grouping; the WIRE follows the model family
        local a = cat.build_agent({ id = "claude-opus-4-6-thinking", owner = "antigravity" })
        assert.equals("anthropic_tools_route", a.model.web_search_strategy)
    end)
end)
```

The last case is why the wire is chosen from the id family and not from `owner`:
a claude model served through antigravity still speaks the Anthropic wire.

- [ ] **Step 2: Run it and watch it fail**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: FAIL — `attempt to call field 'build_agent' (a nil value)`

- [ ] **Step 3: Implement**

```lua
--- Turn a catalog row into a session agent. Tools and web search are ON: an
--- ad-hoc pick is meant to be a working agent, not a stripped one.
---
--- The wire follows the MODEL FAMILY, never `owner`: owner is a display
--- grouping that is not even stable (claude-sonnet-4-6 was reported under
--- `anthropic` on one proxy start and `antigravity` on the next), while
--- claude-* always speaks the Anthropic wire. Non-claude models inherit the
--- provider-level default (openai_tools_route), which is what buys them
--- server-side web search — see the ToolSol* note in config.lua.
---@param m table # a parsed Model
---@param opts table|nil # { system_prompt = string }
---@return table # a parley agent
function M.build_agent(m, opts)
    opts = opts or {}
    return {
        provider = "cliproxyapi",
        name = m.id .. "*",
        model = {
            -- Single-sourced in providers.lua (Task 1.6). NEVER re-test the
            -- family here: providers.lua:170-179 records that this exact
            -- duplication had already drifted once.
            model = m.id,
            web_search_strategy =
                require("parley.providers").cliproxy_default_web_search_strategy(m.id),
        },
        system_prompt = opts.system_prompt or require("parley.defaults").chat_system_prompt,
        synthetic_system_prompt = true,
        tools = { "@all" },
    }
end
```

- [ ] **Step 4: Run it and watch it pass**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: PASS

- [ ] **Step 5: Document THIS milestone's surface, before the boundary**

AGENTS.md §8 wants the atlas updated at each milestone close, not swept up at the
end. A terminal docs task structurally guarantees every earlier boundary is
crossed undocumented, which is exactly what happened here.

`atlas/providers/cliproxy-managed.md` → the catalog's two routes, why both are
needed, and the per-family web-search table with its measurements.

- [ ] **Step 6: Commit + close the milestone**

```bash
git add lua/parley/cliproxy_catalog.lua tests/unit/cliproxy_catalog_spec.lua atlas/providers/cliproxy-managed.md
git commit -m "#205 M1: build_agent turns a catalog row into a tool-enabled agent"
make test
sdlc milestone-close --issue 205 --milestone M1
```

---

## Chunk 2: M2 — fetch, cache, and the fake

### Task 2.1: Teach the fake to serve `/v1beta/models` (extending its `healthy` mode)

**Files:**
- Modify: `tests/fixtures/fake_cliproxy` (the `do_GET` dispatch, near the `/v1/models` branch)

- [ ] **Step 1: Add the route and a catalog mode**

Serve a small catalog carrying the two shapes that matter, so integration tests
meet them the way production does (ARCH-MOCK — the fake models our current
understanding of the dependency, not a happy path):

```python
CATALOG_V1 = {"object": "list", "data": [
    {"id": "claude-opus-5",  "owned_by": "anthropic", "created": 1784038800},
    {"id": "claude-opus-4-8", "owned_by": "anthropic", "created": 1779984000},
    {"id": "gpt-5.6-sol",    "owned_by": "openai",    "created": 1783616400},
    # no `created` — the antigravity shape
    {"id": "gemini-pro-agent", "owned_by": "antigravity"},
]}
CATALOG_V1BETA = {"models": [
    {"name": "models/claude-opus-5",   "displayName": "Claude Opus 5"},
    {"name": "models/claude-opus-4-8", "displayName": "Claude Opus 4.8"},
    {"name": "models/gpt-5.6-sol",     "displayName": "GPT 5.6 Sol"},
    {"name": "models/gemini-pro-agent", "displayName": "Gemini 3.1 Pro (High)"},
]}
```

Dispatch `/v1beta/models` to `CATALOG_V1BETA`; keep `/v1/models` answering the
existing identity protocol, extended with `CATALOG_V1["data"]` in `healthy` mode.

- [ ] **Step 2: Verify the fake by hand**

```bash
python3 tests/fixtures/fake_cliproxy --port 8321 &
curl -s -H "Authorization: Bearer test" http://127.0.0.1:8321/v1beta/models
kill %1
```
Expected: the four-model JSON above

- [ ] **Step 3: Extend the LIVE conformance spec — the fake must not be the only witness**

`tests/integration/cliproxy_conformance_spec.lua` (#197) is the seam that boots
the REAL binary and asserts the fields parley reads still exist. Without a case
there, the unit tests run on a fixture consistent with itself and the
integration tests on a fake restating the same assumption — so if cliproxy ever
emits a bare id instead of `models/<id>`, every join misses, every row silently
falls back to the raw id, and both suites still pass.

```lua
it("/v1beta/models carries the naming fields parse() joins on", function()
    -- against the real binary, skipped when it is unavailable like its siblings
    local body = get("/v1beta/models")
    local decoded = vim.json.decode(body)
    assert.is_table(decoded.models)
    local m = decoded.models[1]
    assert.is_string(m.name)
    assert.is_true(m.name:find("^models/") ~= nil,
        "parse() strips a `models/` prefix; a bare id would silently break every join")
    assert.is_string(m.displayName)
end)

it("the join actually lands against the real catalog", function()
    local models = cat.parse(get("/v1/models"), get("/v1beta/models"))
    local joined = 0
    for _, m in ipairs(models) do
        if m.display ~= m.id then joined = joined + 1 end
    end
    assert.is_true(joined > 0, "no row got a displayName — the join is broken")
end)
```

Add the same "did the join land" assertion to Task 1.1 Step 2, so a re-captured
fixture cannot silently lose its v1beta half.

- [ ] **Step 4: Commit**

```bash
git add tests/fixtures/fake_cliproxy tests/integration/cliproxy_conformance_spec.lua
git commit -m "#205 M2: fake serves /v1beta/models; live conformance guards its shape"
```

### Task 2.2: `fetch_catalog` + disk cache

**Files:**
- Modify: `lua/parley/cliproxy.lua` (beside `list_models`, reusing `api_argv`)
- Modify: `tests/helpers/ready_port.lua` (promote `free_port` + `wait_listening`; add `is_listening`)
- Modify: `tests/integration/cliproxy_lifecycle_spec.lua:17,50` (call the promoted helpers)
- Modify: `tests/integration/cliproxy_recovery_e2e_spec.lua:18,26` (same — the second existing copy)
- Test: `tests/integration/cliproxy_catalog_spec.lua`

- [ ] **Step 1: Write the failing integration test**

Drive it against the fake process, not a mock — `cliproxy_lifecycle_spec.lua`
shows the spawn/teardown pattern to copy.

```lua
it("fetches both routes and caches the join to disk", function()
    -- fake_cliproxy on a ready port; cliproxy._set_data_dir(tmp)
    local done, models = false, nil
    cliproxy.fetch_catalog(function(m) models, done = m, true end)
    vim.wait(3000, function() return done end)
    assert.is_true(#models > 0)
    assert.equals("Claude Opus 5", models[1].display)
    assert.equals(1, vim.fn.filereadable(tmp .. "/catalog.json"))
end)

it("returns the cached catalog with the proxy down, and never spawns it", function()
    -- kill the fake, then:
    local cached = cliproxy.catalog_cached()
    assert.is_true(#cached > 0)
end)

it("does not start a proxy when one is not running", function()
    -- The observable, not an invented API: take a port nothing is listening on,
    -- point the endpoint at it, call fetch_catalog, and assert the port is STILL
    -- free afterwards.
    --
    -- `free_port` and `wait_listening` are ALREADY duplicated file-locals in two
    -- specs: cliproxy_lifecycle_spec.lua:17,50 and cliproxy_recovery_e2e_spec.lua:18,26.
    -- This task PROMOTES them into tests/helpers/ready_port.lua (which today
    -- exports only wait_for_port) and rewrites both specs to call them there —
    -- with this test they would have a third copy (ARCH-DRY).
    --
    -- The promotion also adds the negative predicate this assertion needs, since
    -- neither existing copy has one:
    --   function M.is_listening(port) -> boolean   (single connect attempt)
    --   M.wait_listening(port)  is then a poll over M.is_listening
    local port = ready_port.free_port()
    -- …point providers.cliproxyapi.endpoint at 127.0.0.1:<port>…
    local settled = false
    cliproxy.fetch_catalog(function() settled = true end)
    vim.wait(3000, function() return settled end)
    assert.is_false(ready_port.is_listening(port))  -- #131 dormancy contract
end)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: FAIL — `attempt to call field 'fetch_catalog' (a nil value)`

- [ ] **Step 3: Implement**

```lua
local CATALOG_TTL = 600 -- seconds; see the plan's operating envelope
local _catalog_inflight = false

local function catalog_path()
    return data_root() .. "/catalog.json"
end

--- The last catalog we saw, straight off disk. Synchronous and tiny (~5 KB) —
--- this is what the picker renders, so it never waits on the network.
---@return table[] models, number|nil fetched_at
function M.catalog_cached()
    local fd = io.open(catalog_path(), "r")
    if not fd then return {}, nil end
    local body = fd:read("*a")
    fd:close()
    local ok, decoded = pcall(vim.json.decode, body)
    if not ok or type(decoded) ~= "table" then return {}, nil end
    return decoded.models or {}, decoded.fetched_at
end

--- Refresh the catalog from a proxy that is ALREADY running.
---
--- Deliberately not routed through ensure_running: opening a picker must never
--- spawn a daemon (#131's dormancy contract). A connection-refused is a no-op
--- that leaves the cache in place.
---@param cb fun(models: table[])|nil
function M.fetch_catalog(cb)
    if _catalog_inflight then return end
    local opts = render_opts()
    if not opts.host or not opts.port then return end
    _catalog_inflight = true
    local function get(route, done)
        vim.system(api_argv(opts.host, opts.port, opts.secret, route), { text = true },
            function(obj)
                done(obj.code == 0 and (split_status(obj.stdout) or obj.stdout) or nil)
            end)
    end
    get("/v1/models", function(v1)
        get("/v1beta/models", function(beta)
            vim.schedule(function()
                _catalog_inflight = false
                local models = require("parley.cliproxy_catalog").parse(v1 or "", beta or "")
                if #models > 0 then
                    local fd = io.open(catalog_path(), "w")
                    if fd then
                        fd:write(vim.json.encode({ models = models, fetched_at = os.time() }))
                        fd:close()
                        vim.fn.setfperm(catalog_path(), "rw-------")
                    end
                end
                if cb then cb(models) end
            end)
        end)
    end)
end

--- Is the cache old enough to be worth a background refresh?
function M.catalog_stale()
    local _, at = M.catalog_cached()
    return not at or (os.time() - at) > CATALOG_TTL
end
```

- [ ] **Step 4: Run it and watch it pass**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: PASS

- [ ] **Step 5: Document THIS milestone's surface, before the boundary**

`atlas/providers/cliproxy-managed.md` → `catalog.json` in the derived-artifact
list, the 10-minute refresh, and the never-spawns rule with the test that pins it.

- [ ] **Step 6: Commit + close the milestone**

```bash
git add lua/parley/cliproxy.lua tests/helpers/ready_port.lua tests/integration/cliproxy_catalog_spec.lua tests/integration/cliproxy_lifecycle_spec.lua atlas/providers/cliproxy-managed.md
git commit -m "#205 M2: fetch and disk-cache the live model catalog"
make test
sdlc milestone-close --issue 205 --milestone M2
```

---

## Chunk 3: M3 — the picker

### Task 3.1: Live rows in `_build_items`

**Files:**
- Modify: `lua/parley/agent_picker.lua`
- Test: `tests/unit/picker_items_spec.lua` — `agent_picker._build_items` is already
  covered there (`:44`) with a `make_plugin(current_agent)` helper at `:10`. Extend
  that file and reuse `make_plugin`; do not start a new spec.

- [ ] **Step 1: Write the failing test** — `_build_items` is already the pure seam, so this stays mock-free (ARCH-PURE)

```lua
it("appends live catalog rows after the configured agents", function()
    local plugin = make_plugin("mango")  -- picker_items_spec.lua:10
    local items = agent_picker._build_items(plugin, {
        live = { { id = "claude-opus-5", display = "Claude Opus 5",
                   owner = "anthropic", provider = "claude" } },
    })
    local last = items[#items]
    assert.is_true(last.display:find("Claude Opus 5", 1, true) ~= nil)
    assert.is_true(last.display:find("claude-opus-5", 1, true) ~= nil)
    assert.equals("live", last.kind)
end)

it("renders a logged-out provider as a login row", function()
    local items = agent_picker._build_items(make_plugin("mango"), {
        logged_out = { { provider = "antigravity" } },
    })
    local row = items[#items]
    assert.is_true(row.display:find("(logged out)", 1, true) ~= nil)
    assert.equals("login", row.kind)
end)

it("is unchanged when the catalog is empty", function()
    assert.same(agent_picker._build_items(make_plugin("mango")),
                agent_picker._build_items(make_plugin("mango"), { live = {}, logged_out = {} }))
end)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: FAIL — live rows absent

- [ ] **Step 3: Implement** — extend `_build_items(plugin, extra)` with a second, optional argument so every existing caller and test keeps working, and tag each row with `kind` (`"agent"` / `"live"` / `"login"`) so `on_select` can branch without re-parsing the display string.

- [ ] **Step 4: Write the failing test for the logged-out source**

`extra.logged_out` has to come from somewhere, and that somewhere is a pure
function in this same file — the picker must not make a management call on a UI
path:

```lua
describe("agent_picker._providers_without_models", function()
    local models = {
        { id = "claude-opus-5", owner = "anthropic" },
        { id = "gpt-5.6-sol", owner = "openai" },
    }

    it("names a configured provider the catalog advertises nothing for", function()
        assert.same({ { provider = "antigravity" } },
            agent_picker._providers_without_models(models, { "claude:opus", "antigravity" }))
    end)

    it("stays quiet when every configured provider has models", function()
        assert.same({}, agent_picker._providers_without_models(models, { "claude", "codex" }))
    end)

    it("reads the provider out of a filtered spec", function()
        assert.same({ { provider = "antigravity" } },
            agent_picker._providers_without_models(models, { "antigravity:pro,flash" }))
    end)
end)
```

- [ ] **Step 5: Implement `_providers_without_models(models, providers)`**

The catalog IS the signal: cliproxy registers a channel's models only once that
channel has a credential, so a configured provider contributing nothing is one
you are not logged into. Measured — antigravity's 13 models appeared the moment
its auth file landed, no restart. That keeps the check synchronous, with no
management call on a UI path. A credential that is loaded but DEAD still lists
models; #197's dispatch-failure path owns that case, and the docstring says so.

- [ ] **Step 6: Run both blocks and watch them pass**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lua/parley/agent_picker.lua tests/unit/picker_items_spec.lua
git commit -m "#205 M3: agent picker renders live catalog and login rows"
```

### Task 3.2: Wire the picker — selection, `<C-a>`, async refresh

**Files:**
- Modify: `lua/parley/agent_picker.lua` (`M.agent_picker`)

- [ ] **Step 1: Implement selection branching**

`float_picker.open` returns a handle (`{ update, set_status, set_title, close, is_closed }`) — capture it in a local so the `<C-a>` mapping and the async refresh can call `update` in place instead of reopening (no flash):

```lua
-- Local to M.agent_picker: the two views the <C-a> toggle switches between.
local expanded = false
local function view_for(all)
    local models = cliproxy.catalog_cached()
    local cfg = (plugin.config.cliproxy or {}).live_models or {}
    return {
        live = all and models or cat.curate(models, cfg),
        logged_out = M._providers_without_models(models, cfg.providers or {}),  -- Task 3.1
    }
end

local handle
handle = float_picker.open({
    title = "🤖 Parley Agents",
    items = M._build_items(plugin, view_for(expanded)),
    -- …existing opts…
    on_select = function(item)
        if item.kind == "login" then
            vim.cmd((plugin.config.cmd_prefix or "Parley") .. "Proxy login " .. item.provider)
            return
        end
        if item.kind == "live" then
            plugin.register_live_agent(item.model)  -- Task 3.3
            return
        end
        plugin.refresh_state({ agent = item.name })
        plugin.logger.info("Agent set to: " .. item.name)
        vim.cmd("doautocmd User ParleyAgentChanged")
    end,
    mappings = {
        -- …existing keybindings mapping…
        {
            key = "<C-a>",
            fn = function()
                expanded = not expanded
                handle.update(M._build_items(plugin, view_for(expanded)))
                handle.set_title(expanded and "🤖 Parley Agents — all models"
                                          or "🤖 Parley Agents")
            end,
        },
    },
})
```

- [ ] **Step 2: Kick the background refresh**

After `open`, refresh only when stale; repaint if the picker is still up:

```lua
if cliproxy.is_managed() and cliproxy.catalog_stale() then
    cliproxy.fetch_catalog(function()
        if not handle.is_closed() then
            handle.update(M._build_items(plugin, view_for(expanded)))
        end
    end)
end
```

- [ ] **Step 3: Verify by hand in a real editor**

```
:lua require('parley').setup()
:ParleyAgent
```
Expected: configured agents, then the live rows; `<C-a>` expands to the full
catalog and the title changes; picking `claude-opus-5` sets the agent.

- [ ] **Step 4: Commit**

```bash
git add lua/parley/agent_picker.lua lua/parley/keybinding_registry.lua
git commit -m "#205 M3: live selection, <C-a> expansion, background refresh"
```

### Task 3.3: Register and persist the live agent

**Files:**
- Modify: `lua/parley/init.lua` (new `M.register_live_agent`; restore near `init.lua:1329`)
- Test: `tests/unit/live_agent_state_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
it("registers the agent and makes it selectable", function()
    parley.register_live_agent({ id = "claude-opus-5", owner = "anthropic" })
    assert.is_not_nil(parley.agents["claude-opus-5*"])
    assert.is_true(vim.tbl_contains(parley._agents, "claude-opus-5*"))
    assert.equals("claude-opus-5*", parley._state.agent)
end)

it("survives a restart instead of falling back to the first agent", function()
    parley._state.live_agent = { id = "claude-opus-5", owner = "anthropic" }
    parley._state.agent = "claude-opus-5*"
    parley.setup({})                       -- re-entry, as on a fresh session
    assert.equals("claude-opus-5*", parley._state.agent)
end)
```

The second test is the whole point of this task: without the restore the
`if not M.agents[M._state.agent]` guard at `init.lua:1329` silently resets the
agent to `M._agents[1]` on every launch.

- [ ] **Step 2: Run it and watch it fail**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: FAIL — agent reset to the first configured agent

- [ ] **Step 3: Implement**

```lua
--- Register a catalog model as a session agent and select it.
--- Persisted so the next session restores it rather than resetting.
function M.register_live_agent(model)
    local agent = require("parley.cliproxy_catalog").build_agent(model)
    M.agents[agent.name] = agent
    if not vim.tbl_contains(M._agents, agent.name) then
        table.insert(M._agents, agent.name)
        table.sort(M._agents)
    end
    M.refresh_state({ agent = agent.name, live_agent = model })
    vim.cmd("doautocmd User ParleyAgentChanged")
end
```

and, immediately **before** the fallback guard:

```lua
-- Re-register the last live pick before the guard below, or a catalog agent
-- silently reverts to M._agents[1] on every restart.
if type(M._state.live_agent) == "table" and M._state.live_agent.id then
    local a = require("parley.cliproxy_catalog").build_agent(M._state.live_agent)
    M.agents[a.name] = M.agents[a.name] or a
    if not vim.tbl_contains(M._agents, a.name) then
        table.insert(M._agents, a.name)
        table.sort(M._agents)
    end
end
```

- [ ] **Step 4: Run it and watch it pass**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: PASS

- [ ] **Step 5: End-to-end check against the real proxy**

Pick `claude-opus-5` from the picker, send a message that needs a tool and a web
lookup, and confirm from `:ParleyLog` that the request carried both the client
tools and a `web_search` tool on the Anthropic wire. Record the evidence in
`## Log` — this is the Done-when the spec names.

- [ ] **Step 6: Document THIS milestone's surface, before the boundary**

`atlas/providers/agents.md` → the live section, its exact row format, `<C-a>`,
the `(logged out)` row, and the `<id>*` naming. `README.md` → `live_models`.

- [ ] **Step 7: Commit + close the milestone**

```bash
git add lua/parley/init.lua tests/unit/live_agent_state_spec.lua atlas/providers/agents.md README.md
git commit -m "#205 M3: live agents register, persist, and survive restart"
make test
sdlc milestone-close --issue 205 --milestone M3
```

---

## Chunk 4: M4 — retire the hardcoded lists

### Task 4.1: Resolve channel CANDIDATES and let health pick among them

**Files:**
- Modify: `lua/parley/cliproxy_config.lua` (`resolve_channel` → `resolve_channels`, `resolve_login_provider`)
- Modify: `lua/parley/cliproxy.lua` (`credential_health_for_login:474-491`, `recover:1236`, the give_up text at `:1249`)
- Test: `tests/unit/cliproxy_config_spec.lua`, `tests/integration/cliproxy_recovery_e2e_spec.lua`
- Note: Task 2.2 must expose `cliproxy._write_catalog(models)` as the cache's test
  seam (it already writes that file; this only names the entry point) so this spec
  can seed a catalog without a live proxy.

**Two rejected designs, so the third is understood.** Inverting
`PROVIDER_OWNED_BY` is an axis error: its keys are login-shaped and
`CHANNEL_LOGIN:140-149` has no `google` — that login is three channels. But
narrowing to candidates and returning nil when several remain is *worse*: both
providers the default config ships (`claude` → {claude, antigravity},
`codex` → {codex, antigravity}) are ambiguous, so every diagnosis would degrade
to "no cliproxy channel is configured" precisely where it works today. The
`expired` kinds a dead Claude token produces (`cliproxy_auth.lua:31-34`) capture
no `provider`, so with the alias block deleted there would be no resolver left.

The resolution is that **ambiguity is not the end of the answer** — health
decides it. `credential_health_for_login` already fans out across the channels
of one login and reduces with `ca.healthier`. Diagnosis needs the same fan-out
with the opposite reducer: the LEAST healthy candidate is the one that plausibly
failed. So the fan-out gets extracted once and both callers share it (ARCH-DRY).

- [ ] **Step 1: Write the failing tests**

```lua
describe("resolve_channels", function()
    it("returns the operator's explicit pin alone", function()
        local alias = { codex = { { name = "claude-opus-5", alias = "claude-opus-5" } } }
        assert.same({ "codex" }, cc.resolve_channels("claude-opus-5", alias, {}))
    end)

    it("returns every candidate that can serve the owner", function()
        local models = { { id = "claude-opus-5", owner = "anthropic" } }
        assert.same({ "antigravity", "claude" },
            cc.resolve_channels("claude-opus-5", {}, models))
    end)

    it("returns empty when neither alias nor catalog knows the model", function()
        assert.same({}, cc.resolve_channels("who-knows-1", {}, {}))
    end)
end)
```

and the regression test that the CURRENT proof spec cannot express — note it
passes an **empty** alias block, which is what the default config will ship:

```lua
it("names the claude login for an expired token with NO alias block", function()
    -- cliproxy_recovery_e2e_spec.lua:74-77 builds its own oauth-model-alias, so
    -- it passes with or without Task 4.2's deletion. This case is the one that
    -- actually detects the regression.
    -- `serve(error_mode, overlay)` and `query()` are the spec's own helpers
    -- (cliproxy_recovery_e2e_spec.lua:41 and :85); the overlay is where that
    -- spec builds its oauth-model-alias today, so an empty one is the variation.
    serve("expired", { ["oauth-model-alias"] = {} })
    cliproxy._write_catalog({ { id = "claude-opus-5", owner = "anthropic" } })
    local msg = query()
    assert.is_true(msg:find("claude", 1, true) ~= nil)
    assert.is_nil(msg:find("oauth-model-alias", 1, true),
        "the diagnosis must stop telling operators to add a key the config no longer has")
end)
```

- [ ] **Step 2: Run them and watch them fail**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: FAIL — `resolve_channels` is nil; the diagnosis still names the alias block

- [ ] **Step 3: Extract the fan-out, then add the second reducer**

```lua
-- Which cliproxy CHANNELS can serve a model of a given catalog `owned_by`.
-- THE SOURCE of the owner→channels relation — it exists nowhere else in the
-- codebase and is not derivable: PROVIDER_OWNED_BY (cliproxy_config.lua:227-234)
-- is the login axis, and a catalog row carries a single owner while antigravity
-- demonstrably serves anthropic-, openai- and google-owned models alongside the
-- native channels. Plural on purpose; Step 4 lets health decide between them.
local OWNER_CHANNELS = {
    anthropic   = { "antigravity", "claude" },
    openai      = { "antigravity", "codex" },
    google      = { "aistudio", "antigravity", "gemini", "gemini-cli" },
    antigravity = { "antigravity" },
    moonshot    = { "kimi" },
    xai         = { "xai" },
}

---@param owner string # a catalog row's owned_by
---@return string[] # sorted candidate channels; empty when the owner is unknown
function M.channels_for_owner(owner)
    return vim.deepcopy(OWNER_CHANNELS[owner] or {})
end

--- Alias pin first, else the owner's candidates from the catalog, else empty.
---@return string[]
function M.resolve_channels(model, oauth_model_alias, models)
    local pinned = M.resolve_channel(model, oauth_model_alias)  -- existing fn, kept
    if pinned then
        return { pinned }
    end
    for _, m in ipairs(models or {}) do
        if m.id == model then
            return M.channels_for_owner(m.owner)
        end
    end
    return {}
end
```

and in `cliproxy.lua`:

```lua
--- Read credential health across several channels and reduce to one.
--- The fan-out both callers share: `credential_health_for_login` wants the
--- HEALTHIEST reading (is this account usable at all), diagnosis wants the
--- LEAST healthy (which credential plausibly caused this failure). One
--- traversal, injected comparator (ARCH-DRY).
---@param channels string[]
---@param prefer fun(a: table, b: table): boolean # true when `a` should win
---@param cb fun(health: table, channel: string|nil)
function M.credential_health_across(channels, prefer, cb)
    -- …the existing loop from credential_health_for_login, tracking the winning
    -- channel alongside the winning health so the caller can name the login…
end
```

`credential_health_for_login` becomes a two-line caller with `ca.healthier`;
`recover` calls it with the inverse and gets back both the health AND the channel
that owns it.

- [ ] **Step 4: Rewire `recover`**

```lua
local channels = verdict.provider and { verdict.provider }
    or cc.resolve_channels(verdict.model, alias_block() or {}, M.catalog_cached())
```

- `#channels == 0` → today's give_up, with the message rewritten: it must stop
  instructing the operator to add an `oauth-model-alias` key (`cliproxy.lua:1249`
  and the second copy at `:1291`), since Task 4.2 removes that block from the
  default config. Both copies, not one — grep `oauth-model-alias` under `lua/`.
- `#channels == 1` → today's path, unchanged.
- `#channels > 1` → `credential_health_across(channels, least_healthy)`; the
  diagnosis names the login of the channel it returns.

- [ ] **Step 5: Sweep every caller**

```bash
grep -rn "resolve_channel\|resolve_login_provider\|oauth-model-alias" lua/ tests/
```
All of them threaded in this commit: `resolve_login_provider`
(`cliproxy_config.lua:218`, whose docstring promises it derives from the same
source), `recover` (`cliproxy.lua:1236`), and both give_up texts.

- [ ] **Step 6: Run the specs that would catch a regression**

```bash
make test-spec SPEC=providers/cliproxy-managed
make test-spec SPEC=providers/cliproxy-managed
make test-spec SPEC=providers/cliproxy-managed
make test-spec SPEC=providers/cliproxy-managed
```
Expected: PASS, including the new empty-alias case

- [ ] **Step 7: Commit**

```bash
git add tests/ lua/
git commit -m "#205 M4: channel candidates resolved by credential health, not by guessing"
```

### Task 4.2: Delete the model lists from the default config

**Files:**
- Modify: `lua/parley/config.lua:130-152` (delete `oauth-model-alias`), add `cliproxy.live_models`

- [ ] **Step 1: Delete the alias block**

`live_models` already shipped in M3 — do NOT re-add it here. This step removes
`oauth-model-alias` and nothing else.

(the knob's shipped form lives in `lua/parley/config.lua`)


- [ ] **Step 2: Verify routing still works without the alias block**

This is the claim the whole milestone rests on, so prove it rather than assume:

```bash
curl -s -H "Authorization: Bearer ${CLIPROXYAPI_API_KEY:-parley-local}" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-opus-5","messages":[{"role":"user","content":"hi"}],"max_tokens":16}' \
  http://127.0.0.1:8317/v1/chat/completions
```
Expected: a completion, not `unknown provider for model`

- [ ] **Step 3: Verify the auth diagnosis still names the right login**

The load-bearing case is Task 4.1's empty-alias test, NOT the pre-existing
recovery spec — that one builds its own `oauth-model-alias`
(`cliproxy_recovery_e2e_spec.lua:74-77`) and so passes whether or not this
deletion regresses anything.

```bash
make test-spec SPEC=providers/cliproxy-managed   # incl. the empty-alias case
make test-spec SPEC=providers/cliproxy-managed
```
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lua/parley/config.lua
git commit -m "#205 M4: retire oauth-model-alias from the default config"
```

### Task 4.3: Docs for M4's surface only

**Files:**
- Modify: `atlas/providers/cliproxy-managed.md` (the alias block's retirement)
- Modify: `README.md` (the cliproxy section)

Every earlier milestone documents its OWN surface at its own boundary — see the
docs step inside Tasks 1.7, 2.2 and 3.3. This task carries only what M4 changes.

- [ ] **Step 1: Record that `oauth-model-alias` is no longer required** for
  routing, that it survives as an explicit channel pin, and how model→channel
  now resolves (candidates from the catalog, disambiguated by credential health).

- [ ] **Step 2: Full suite + close**

```bash
make test
sdlc close --issue 205 --verified '<evidence>'
```

---

## Notes for the implementer

- **`sdlc change-code` first.** It owns the branch decision, the plan-quality gate, and the estimate. Don't start Task 1.1 before it.
- **Do not run `superpowers-requesting-code-review` at the milestone boundaries.** `sdlc milestone-close` auto-dispatches the one mandatory fresh-context review (AGENTS.md §3).
- **Every name must have a referent.** Three findings on this issue named
  something that did not exist — `_spawned_pids`, `free_port`, then an
  owner→channels relation with no source. The rule covers **any identifier or
  relation** a code block, test block, or rationale sentence names, not just test
  helpers: before a task ships, each one must resolve to a `file:line` that exists
  today, be defined in that task's own code block, or appear in its **Files**
  section as newly created. The mechanical check, run over the whole plan rather
  than per finding:

  ```bash
  grep -oE '\b[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+\s*\(' \
    workshop/plans/000205-*-plan.md | sort -u
  # for each leaf: grep -rn "<leaf>" lua/ tests/ — no hit means define it or cite it
  ```

  A rationale sentence that justifies a design by naming existing machinery is
  covered too: either a step in that same task invokes it, or the sentence goes.

  **Run it in BOTH directions.** The grep above matches dotted call syntax only,
  so a bare table cell (`catalog_write`) is structurally exempt — which is how a
  non-existent entity survived a round that reported the sweep clean. The second
  direction: every function the milestone's diff adds to a module named in the
  tables must APPEAR in a table row.

  The check must enumerate **every definition form this codebase uses** and
  **every referent KIND a plan cell can name** — a regex covering one form of one
  kind is how a non-existent entity survived a round reported clean, twice.

  Definition forms: `function M.x(`, `M.x = function(`, `M.x = <expr>` (the alias
  form `M._catalog_path = catalog_path`), and `local function x(`.
  Referent kinds a plan names: functions, fixture MODES (`--mode <name>` on
  fake_cliproxy), HTTP routes, file paths, and config flags — none of which the
  dotted-call regex can see.

  ```bash
  PLAN=workshop/plans/000205-*-plan.md
  # reverse: every entity the diff adds, in any definition form, must appear in a table
  git diff <boundary>..HEAD -- lua/ \
    | grep -oE '^\+\s*(function M\.[A-Za-z0-9_]+|M\.[A-Za-z0-9_]+ = )' \
    | grep -oE 'M\.[A-Za-z0-9_]+' | sort -u
  # forward: every backticked name in the plan must resolve somewhere real
  grep -oE '`[A-Za-z_][A-Za-z0-9_./-]*`' $PLAN | tr -d '`' | sort -u \
    | while read -r n; do grep -rqs "$n" lua/ tests/ || echo "NO REFERENT: $n"; done
  # fixture modes named in the plan must exist in the fixture's own mode list
  grep -oE 'mode[s]? [`"][a-z_]+[`"]' $PLAN | grep -oE '[a-z_]+"?$' | sort -u
  ```
- **Never `git add -u` or `git add -A` on this issue.** The working tree carries
  an operator-owned `config.lua` cleanup that deletes configured agents; sweeping
  it into a milestone commit happened twice on this issue, and once put a spec's
  test port and api-key into the operator's live proxy config. Stage the files a
  task names, explicitly. `git status --short` before every commit.
- **The fixtures are the spec.** The four `curate` cases are real renders from the live catalog on 2026-08-31. If a change makes one fail, decide whether the catalog moved or the code broke — don't edit the expectation to match the code.

## Revisions

### 2026-08-31 — M1 boundary review (BR-2..BR-5 + two Minors)

- **BR-2 (Critical).** `build_agent`'s `"none"` was discarded by
  `get_cliproxy_strategy`, which whitelisted only the three ACTIVE strategies and
  fell through to the provider default — so a gemini pick shipped the exact
  `web_search` payload that "none" existed to avoid. `none` is now a recognized
  model-level value, and the value set is single-sourced (`CLIPROXY_STRATEGIES`)
  rather than spelled out twice. The regression test forces the provider default
  to an active strategy first: written without that, it passed against the buggy
  resolver, since the fallback also returns "none" in a bare unit environment.
- **BR-3.** `cliproxy_default_web_search_strategy` now has six direct tests; Task
  1.6's steps had been folded into build_agent's coverage rather than executed.
- **BR-4.** `rank_key` read the first numeral in a display name as a version, so
  "GPT-OSS 120B (Medium)" outranked every Gemini row in the created-less band. It
  now takes the first number below 100 — above that it is a parameter count.
- **BR-5.** The `antigravity:pro` render is asserted by equality; it is the one
  case exercising displayName matching and created-less ranking together, so its
  ordering is part of what is under test.
- **Minor (entity table).** `providers.lua` was modified by M1 without appearing
  in the Core concepts table, which is what would have made its missing test row
  visible. Added, along with `get_cliproxy_strategy`.
- **Minor (unmeasured branch).** `owned_by == "antigravity"` now yields "none"
  regardless of family, and `build_agent` forwards the owner. Measured: gemini
  breaks outright there, and `gpt-oss-120b-medium` answers while silently never
  searching. A claude model served by antigravity stays unmeasured, so it is no
  longer claimed to work.

### 2026-08-31 — M1 boundary review round 2 (BR-5, BR-12)

- **BR-12 (Important, and a real design error).** `web_search_strategy` also
  selects the WIRE — `cliproxy_route` returns "anthropic" only for
  `anthropic_tools_route` — so round 1's "antigravity ⇒ none" rule let an
  UNSTABLE `owned_by` decide the transport: the same claude-sonnet-4-6 would
  have spoken Anthropic or OpenAI depending on which owner that proxy start
  reported. Resolved by measurement rather than by choosing: an
  antigravity-served `claude-opus-4-6-thinking` answers 200 on the anthropic
  wire, so the family test runs FIRST and owner is consulted only below it,
  where every remaining family gets the openai wire either way and owner can
  therefore only affect the search tool. Two tests pin it, one asserting that
  the two owners of a shared id resolve identically.
- **BR-5 (repeat).** The remaining `tbl_contains` — in the rank-band test added
  in round 1 — is now a full-render equality. Order is what that case exists to
  check, and containment cannot see order. No `tbl_contains` remains in the spec.

### 2026-08-31 — M1 boundary review rounds 3-4 (BR-1, BR-5..BR-9, BR-13)

Six of these are one failure repeated: an instance was patched where a rule was
needed. Recorded together because the pattern is the finding.

- **BR-13.** `rank_key` guarded against parameter counts with a `< 100`
  threshold, which only excludes the sizes that happen to be large — "GPT-OSS
  20B" would still have read as version 20. The rule the code needed: a numeral
  in free text is a version only when DELIMITED, never when glued to a letter.
- **BR-5.** Pinning one more render was not the fix either. The spec now derives
  its cases from a `SPEC_RENDERS` table keyed by the documented spec string, so
  every row in the Spec's table is an equality by construction and a new row
  cannot be added without a test.
- **BR-6.** An unknown provider resolved to `owner = nil`, and `m.owner == owner`
  then pooled every row whose `owned_by` was absent. Unknown providers now
  contribute nothing.
- **BR-7.** `series("")` returned "". Fixed at the boundary rather than in
  `series`: a row with no id is not a model, so `parse` drops it — one guard
  instead of a defence in every consumer.
- **BR-8.** `build_agent` raised on a row without an id. It returns nil now; its
  callers are a picker callback and a session restore, where raising means a
  stack trace over the UI or an aborted setup.
- **BR-1 / BR-9.** The plan named `M._logged_out_providers` and `provider_states`
  for a capability implemented as `_providers_without_models`, and repeated
  `SPEC=unit/…` at twelve steps when `make test-spec` takes atlas feature keys
  (`SPEC=providers/cliproxy-managed`). Both swept across the whole plan, and the
  referent grep the Notes prescribe was actually run this time.

### 2026-08-31 — M1 close round 5 (BR-1, BR-13)

- **BR-13.** The delimiter rule was right but *unpinned*: restoring the `< 100`
  threshold left all 41 tests passing, so nothing defended the rule. The new case
  uses magnitudes that a threshold would wave through — "GPT-OSS 20B", "Llama
  70B", "Ctx 32K", "Mixtral 8x7B" — and was confirmed to FAIL against the old
  threshold before being kept. This is the second time on this issue that a fix
  shipped with a test that could not fail; both times the check was the same one:
  break the code on purpose and watch the test go red.
- **BR-1.** Task 3.1 credited `_providers_without_models` without any step
  creating or testing it. Steps 4-6 now do, including why the catalog is the
  logged-out signal and what it deliberately does not cover.

### 2026-08-31 — M2/M3 boundary review (BR-24, BR-25, BR-26)

All three are second occurrences, so each is recorded as the rule it needed.

- **BR-24.** No atlas entry existed for any of the new surface. The instance was
  not the fix: docs were lumped into a terminal Task 4.3, which structurally
  guarantees every earlier milestone crosses its boundary undocumented, contra
  AGENTS.md §8. Dissolved into a docs step inside each milestone naming the file
  and section; 4.3 now carries only M4's own surface.
- **BR-25.** The picker's rows drifted from the documented render — hyphen for
  em dash, no separator, no grouping — and the tests only used
  `find(..., plain)`, which cannot see what is absent. BR-5 had already settled
  "equality, not containment" for `curate`; the picker's rows are documented
  renders in the same Spec and did not inherit the rule. They are now pinned as
  full-string equalities, and the `── live · cliproxy ──` separator the Spec
  documents is implemented (inert: `on_select` ignores it, since float_picker has
  no non-selectable row).
- **BR-26.** The Integration table named `catalog_write`, which never existed
  (`_write_catalog` ships), and omitted `catalog_stale`, `_catalog_path` and
  `register_live_agent`. The referent grep matched dotted call syntax only, so
  bare table cells were exempt from the check meant to keep names honest. It now
  runs in both directions.

### 2026-08-31 — M2/M3 review round 7 (BR-30 Critical, BR-22, BR-23, BR-25, BR-31)

- **BR-30 (Critical).** A picked live model rendered twice — once from the
  configured loop (`register_live_agent` inserts `<id>*`, and the restart restore
  does the same) and once from the catalog — both checkmarked, both keyed
  identically for `recall_id_fn`. The exclusion lives in `view_for` so the
  `<C-a>` path inherits it, and the test builds the state a live pick actually
  creates, which `make_plugin` never reached. It was visible in smoke-test output
  I had already read.
- **BR-22.** `view_for` returned early on an empty catalog, suppressing the
  logged-out rows in exactly the case they exist for; and `fetch_catalog` gated
  its write on `#models > 0`, conflating "every channel logged out" with "the
  proxy is down". The write now keys on request success, not list length.
- **BR-23.** The promotion left the duplication in place: `free_port` was
  file-local in EIGHT specs, not the three named. All eight now call the shared
  helper, and the docstring's claim is true.
- **BR-25.** Spec and code disagreed on the dash and on grouping, and the atlas
  restated the code's version a third time. The Spec now documents what ships,
  with the reason: a different dash on the live rows would make one list look
  like two conventions, and float_picker has no non-selectable row, so group
  headers would each be a selectable, fuzzy-matchable item.
- **BR-31.** The bidirectional check I added had blind spots on both passes — the
  reverse matched only `function M.x(`, missing the `M.x = function` and
  `M.x = alias` forms; the forward matched only dotted call syntax, so fixture
  modes, routes, files and flags escaped, including a `catalog` mode this plan
  named that never existed. The rule now enumerates definition FORMS and referent
  KINDS, and the fixture-mode reference is corrected to what shipped.

### 2026-08-31 — M2/M3 review round 8 (BR-22, BR-30, BR-33)

- **BR-30 (Critical, repeat).** The code fix was right; the TEST could not fail —
  it re-implemented the exclusion in the spec body and handed `_build_items` an
  already-filtered list, so reverting the fix left the file green. Third time on
  this issue. The structural answer is `M._view_for(models, cfg, opts)`: a pure
  function on the production path that a test can call directly. Both this fix
  and BR-22's were then verified by reverting them and watching 3 and 1 tests go
  red respectively.
- **BR-22 (repeat).** The class survived two more sites in the same function:
  `all` decided both "bypass curation" and "hide the login rows", and the
  background repaint gated on `#models > 0`, so the 200-with-empty-registry case
  the write gate had just been fixed to record never repainted. `all` now scopes
  to curation alone, and the repaint keys on the fetch resolving.
- **BR-33.** `<C-a>` was a literal while every sibling picker key carries a
  registry row — so it appeared in no help screen and could not be rebound, and
  the mapping immediately above it binds the help that omits it. It now resolves
  through the new `keybinding_registry.key_for(id, config)`. The wider rule: a
  sweep without a guard is a snapshot. `tests/arch/single_source_sweeps_spec.lua`
  now guards all three of this issue's consolidations — no re-declared
  `free_port`, no cliproxy spec without `_set_data_dir`, no new hardcoded picker
  key (with the pre-existing seven listed as debt that may shrink, never grow).
  Each guard was confirmed to fail when its invariant is violated.

### 2026-08-31 — M2/M3 review round 9 (BR-19 Critical, BR-21)

- **BR-19.** Deleting the restart-restore left every spec green: the persistence
  test stubbed `refresh_state`, so it never reached the code it claimed to cover,
  and `M.agent_picker`'s selection branches had no test at all. Fourth instance
  of the same failure on this issue. Two structural changes, matching `_view_for`:
  the spec now drives the REAL `refresh_state` from a persisted `state.json` —
  which is what a restart actually is, and what exposed that `_state` is reloaded
  from disk — and the selection branches are extracted as `M._select(plugin,
  item)` so each is reachable. **Every fix in this round was mutation-checked**:
  deleting the restore block fails 2, removing the live branch fails 1, removing
  the cache guard fails 1.
- **BR-21.** Not merely a missing guard — two live throws: `_view_for`
  concatenated a nil id and `_build_items` rendered a nil display, so a corrupt
  or hand-edited `catalog.json` crashed the agent picker on open. That file
  persists between sessions and can be written by an older parley, so it is
  untrusted input. Sanitized at the single boundary every consumer reads
  through (`catalog_cached`), the way BR-7's empty id was fixed in `parse`.

### 2026-08-31 — M2/M3 review round 10 (the demoted backlog, cleared)

The gate had stopped blocking on these (round cap), so they are recorded as
fixed rather than as gate work.

- **BR-21.** Three more data-loss and crash paths, each measured: a *foreign*
  200 on the endpoint wiped a warm catalog (HTTP status alone does not say the
  body is cliproxy's), the picker rendered `(nil)` for an ownerless row, and
  `_providers_without_models` was unguarded. The write now gates on `classify` —
  the existing single source for "is this cliproxy's /v1/models contract" —
  after three weaker gates each lost data in turn (`#models > 0`, curl exit
  code, HTTP 200). The foreign test needed fixing too: it reused the just-killed
  port, so the dying process answered and reverting the fix left it green.
- **BR-37.** `fetch_catalog` returned without calling its callback on the
  in-flight path, so a picker opened during a refresh never repainted. Every
  exit path now resolves the callback exactly once.
- **BR-20.** `catalog_cached` re-read and re-`mkdir`ed on every picker open,
  toggle and repaint — a keystroke path. Memoized on the file's mtime. And
  `providers = nil` returned `{}` rather than "every known provider" as
  config.lua documents, which silently emptied the live section for anyone who
  omitted the key.
- **BR-36.** The `or "<C-a>"` fallback was a second copy of the registry's
  default, invisible to the guard written one round earlier — the same
  enumerate-the-forms rule BR-31 had already stated. The literal is gone (no key
  ⇒ no mapping) and the guard now matches the fallback forms too.
- **BR-28.** `id .. "*"` lived at three sites that must agree, or a model
  renders twice again. Single-sourced as `cliproxy_catalog.agent_name`.
- **BR-24 / BR-32 / BR-35 / BR-34 / BR-27.** README documents `live_models` and
  `<C-a>`; the catalog section no longer orphans the flow narrative; the
  keybinding row is scoped `parley_buffer` rather than Global; the fake's
  v1beta branches mirror /v1/models with the reason stated; and the plan records
  that `live_models` shipped in M3.

### 2026-08-31 — M2 close (FIX-THEN-SHIP): BR-38..BR-41 and the BR-20/21 remainders

- **BR-41.** `fetch_catalog` pulled `render_opts()`, whose bundle MINTS a 0600
  `management.key` — so opening the agent picker created a credential file.
  It now reads only host, port and secret. Pinned by a test asserting no
  `management.key` exists after a refresh.
- **BR-40.** `providers = { "claude", "claude:opus" }` rendered claude-opus-5
  twice, both marked current, one shared recall key — BR-30's symptom reached by
  a second route, because `curate` resets its per-series memo per entry. The live
  list is deduped by id as well as against registered agents.
- **BR-21 remainder.** An ownerless cache row printed a literal `(nil)`, and
  `_providers_without_models` offered `:ParleyProxy login claud` for a typo and
  for `anthropic` (an owner name, not a provider). Only names parley can
  actually log into earn a login row.
- **BR-20 remainder.** The "logged at debug" the operating envelope promised is
  implemented, and `catalog_path()` no longer mkdirs on every read — only the
  write needs the directory.
- **BR-39.** The guard written last round claimed to count "any bracketed key
  literal" while matching three specific forms, and its allowance for
  `agent_picker.lua` was 0 while the file held one — a guard asserting a
  measurable falsehood. Pattern widened to any `"<…>…"` literal, allowances set
  from measurement, and `float_picker` excluded with the reason: it is the
  widget, not a caller, and its built-in keys are deliberately not per-picker
  rebindable.
- **BR-38.** `agent_name` was missing from the tables the plan's own
  bidirectional rule covers, and `_select` sat under Pure entities while calling
  `vim.cmd` and `vim.schedule`. Moved to Integration points.

### 2026-08-31 — M3 close review (BR-42..BR-47)

- **BR-42.** `is_managed()` gated the catalog refresh, so an operator running
  their own cliproxy (`manage = false`) got an empty catalog and a picker
  claiming every configured provider was logged out. `manage` governs whether
  parley STARTS a proxy, not whether one exists; `fetch_catalog` spawns nothing,
  so the dormancy contract is untouched by dropping the gate.
- **BR-43.** The background repaint restored the selection by INDEX, and a
  refresh that inserts or removes rows moves what that index points at — so
  `<CR>` could fire on a row the operator never pointed at. `float_picker`'s
  handle now exposes `selected()`, and the repaint restores by name.
- **BR-45.** Spec Component 3 named the management API as the logged-out source
  while the code reads the catalog; the design was reconsidered during M3 and the
  Spec never restated. Corrected, with the case it does not cover named.
- **BR-46.** The plan's close recipe swept the whole tree, which carries the
  operator's uncommitted `config.lua`. That exact sweep happened twice on this
  issue, once putting a spec's port and api-key into their live proxy config. The
  recipe now names files, and the Notes carry the rule.
- **BR-47.** M3's Done-when is recorded in `## Log` with the payload, the
  response block types and the answer — the answer being the evidence, since the
  inert paths return a stale version rather than an error.
- **BR-44.** Commit 747c8ff falls in no review window (M2's ended at 60b964b,
  M3's begins after it), so its content is ungated. Recorded in the Log for the
  issue-close review to take deliberately.

### 2026-08-31 — M3 close review round 2 (BR-49..BR-57)

- **BR-52.** The BR-43 fix was wrong in a way the finding measured: `sel_idx`
  indexes the FILTERED list, and the repaint computed its index against the full
  `items` list — so with a query active the cursor landed on a different row than
  before, the exact failure BR-43 existed to stop. Fixed in the WIDGET, which
  owns that coordinate space: `update` now accepts an identity string and
  resolves it after filtering. Pinned by a test with an active query, verified to
  fail without the fix.
- **BR-53.** Staleness was keyed on the last SUCCESS, so a proxy that is down
  never set the clock and every picker open re-spawned two curls — an unbounded
  retry on a keystroke path. It keys on the last ATTEMPT now.
- **BR-50.** `_catalog_inflight` was set before two `vim.system` calls with no
  failure path clearing it; one uncaught error stranded it true and the catalog
  never refreshed again that session. Every path settles through one function,
  and the parse is guarded.
- **BR-49.** The BR-41 fix introduced a second byte-identical host/port/secret
  derivation; extracted as `endpoint_opts`, which `render_opts` now builds on.
- **BR-42/BR-54.** The window changed runtime behaviour in two modules with zero
  test changes — 5th in that family. Both behaviours are now pinned and
  mutation-checked, and the RULE is in `workshop/lessons.md`: a boundary whose
  diff touches `lua/` and no spec does not close.
- **BR-55/BR-56/BR-57/BR-51.** Commit recipes name real paths again (BR-46's
  prose made them unexecutable); `workshop/lessons.md` gained the four recurring
  failures with the check that catches each; `*.parley-backup.*` is gitignored;
  and this plan now states that the issue file, not these checkboxes, is the
  record.

### 2026-08-31 — M3 close review round 3 (BR-58..BR-63)

Two of these are regressions from the previous round's own fixes.

- **BR-58 (Critical).** The attempt-based staleness added for BR-53 silenced the
  picker for the full ten-minute success TTL after a failure — including
  immediately after the operator logs in through the `(logged out)` row, which is
  exactly when the catalog HAS just changed. Two clocks now: a successful cache
  is good for `CATALOG_TTL`, a failed attempt backs off for
  `FAILED_ATTEMPT_BACKOFF` (30s), and a completed login clears the failure clock
  outright.
- **BR-59.** The BR-52 test passed with the bug reintroduced: its target was the
  last filtered row, which `get_selected_item`'s clamp reaches from any
  out-of-range index. The previous round CLAIMED it mutation-checked — and it had
  been, but with the weaker mutation (deleting the block) rather than the
  specific wrong implementation (resolving in items-space). **The mutation must
  be the wrong implementation, not merely deletion**; the fixture now puts the
  target at filtered index 1 of 3, and the items-space mutation fails it.
- **BR-60.** `update`'s numeric argument meant items-space at callers and
  filtered-space in the widget. Both forms are now stated in the caller's terms
  and resolved by the widget in its own space.
- **BR-61 / BR-62 / BR-63.** `atlas/ui/pickers.md` documents `selected()` and
  `update`'s third argument; the arch spec sweeps code→table so a module-public
  entity missing from Core concepts fails a test rather than a review; and the
  stacked doc blocks above `catalog_stale` are untangled.

### 2026-09-01 — BR-58's login half (the part the previous round got wrong)

The failure-backoff half was fixed and revert-verified. The LOGIN half was not,
and was reported as fixed: `catalog_stale` short-circuits on a fresh cache
before it consults the attempt clock, so clearing that clock was inert in the
one case that matters — a `(logged out)` row exists BECAUSE a successful fetch
lacked that provider's models, which means the cache is fresh. An operator
logging in through the row kept seeing it for up to the full TTL.

An explicit `invalidate_catalog()` now outranks both clocks, and the login path
calls that rather than the clock reset. The two acts are separate functions on
purpose: a spec setting up a clean clock is not a login announcing that the
catalog changed, and one function serving both made every spec that reset the
clock see everything as stale — which is how the first attempt broke two
existing tests. Mutation-checked: removing the invalidation fails the new test.
