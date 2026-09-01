---
id: 000205
status: working
deps: []
github_issue:
created: 2026-08-31
updated: 2026-08-31
estimate_hours: 4.61
started: 2026-08-31T18:19:21-07:00
---

# live cliproxy model picker; retire hardcoded model lists

## Problem

Every cliproxyapi model parley can reach is named twice in `lua/parley/config.lua`:
once in `cliproxy.config["oauth-model-alias"]` and once per agent entry. cliproxyapi
already advertises its catalog, and the per-model config parley adds is minimal
(a name, a tool set, a web-search strategy), so the duplication buys nothing and
rots: as of 2026-08-31 the block lists `claude-fable-5` twice and pins
`claude-opus-4-8` while the proxy advertises `claude-opus-5`, leaving all three
Opus agents a model generation behind without any visible signal.

Evidence gathered against the live proxy on 2026-08-31 (running parley's own
rendered config — wrong bearer → 401, `parley-local` → 200):

- **The alias block is not needed for routing.** `claude-opus-5` and `gpt-5.5`,
  neither listed, both answered normally. `gemini-3.1-pro-preview` (channel not
  declared at all) reached Google and returned an upstream *license* 403 — i.e.
  routing worked. The comment at `config.lua:133` ("Without this, cliproxyapi
  answers `unknown provider for model claude-…`") was verified against 7.1.71 and
  no longer holds; cliproxy resolves from its own registry.
- **The block has exactly one live job left in parley**: `cc.resolve_channel` at
  `cliproxy.lua:1236`, answering "which login does this model need" when a
  credential fails.
- **The catalog is self-updating.** An antigravity login registered mid-session
  through the proxy's own file watcher: 30 → 43 models, no restart.

## Spec

Stop enumerating models in config. Read the live catalog and offer it in the agent
picker; keep the six configured cliproxyapi agents as pinned favorites.

### Catalog metadata (what the proxy actually offers)

There is **no flagship/tier field**. `/v1/models` carries only `id`, `owned_by`,
`created`. `/v1beta/models` on the same proxy (gemini shape) adds `displayName`,
`description`, `version`. Tier exists only in prose — Sol is "Our most capable
model yet", Terra "Balanced agentic coding model for everyday work", Luna "Fast
and affordable". So parley must not model tiers; it ranks by recency-per-series
and shows the vendor's own name and one-liner.

Two measured constraints:

- **All 13 antigravity models lack `created`**, and their ids mislead —
  `gemini-pro-agent` displays as "Gemini 3.1 Pro (High)". displayName is the truth
  for that owner; ranking must degrade to a version parsed from displayName.
- **`owned_by` is not stable.** `claude-sonnet-4-6` landed under `anthropic` on one
  proxy start and `antigravity` on the next, for the same auth dir. It is a display
  grouping, never a durable key and never a channel identifier.

### Components

1. **`lua/parley/cliproxy_catalog.lua` — pure core** (ARCH-PURE, no IO).
   - `parse(v1_json, v1beta_json)` joins the two endpoints on id →
     `{ id, owner, created, display, description, series }`.
   - `curate(models, opts)` → the default view: apply each provider's model filter,
     dedupe by series, rank by `created` falling back to a version parsed from
     `displayName`, take `per_provider` (default 3) per provider.
   - `parse_provider_spec("claude:opus,sonnet")` → `{ provider = "claude",
     terms = { "opus", "sonnet" } }`. Split on `:`, then on `,`.
   - Series is derived by stripping version numerals from the id.

2. **Catalog cache — IO shell in `cliproxy.lua`.** Fetch both routes through the
   existing `api_argv` seam (ARCH-DRY). Cache in memory; persist to
   `stdpath('data')/parley/cliproxy/catalog.json` so the picker is instant and
   populated on a cold start. Refresh on picker open when stale, **only if the
   proxy already answers** — opening a picker must never spawn the daemon, which
   preserves the "dormant unless a cliproxyapi agent runs" contract from #131.

3. **Live section in the agent picker.** Configured agents, a
   `── live · cliproxy ──` separator, then the curated live models in configured
   provider order, rendered as `Claude Opus 5 - claude-opus-5 (anthropic)`.
   `<C-a>` toggles the entire catalog — filter and curation both bypassed — for
   the rest (haiku, gpt-oss-120b, …). A model already registered as an agent is
   dropped from the live section, so it never appears twice.

   **Logged-out providers stay visible.** A provider named in config that has no
   healthy credential contributes no models to the catalog (measured: antigravity
   models appeared only once its auth file registered), so it would silently
   vanish. Instead it gets one placeholder row — `antigravity - (logged out)` —
   and selecting it runs `:ParleyProxy login <provider>`. The picker thus answers
   both "which model" and "why is my provider missing".

   **The catalog is the logged-out signal, not the management API.** cliproxy
   registers a channel's models only once that channel has a credential —
   measured: antigravity's 13 models appeared the moment its auth file landed,
   with no restart — so a configured provider contributing no rows is one you are
   not logged into. That keeps the check synchronous on a keystroke path, where a
   `/v0/management/auth-files` round trip does not belong. Catalog rows attach to
   a provider through the static `PROVIDER_OWNED_BY` map, which is unaffected by
   the shared-id instability above, and only a name parley can actually log into
   earns a row. The case this deliberately does NOT cover is a credential that is
   loaded but dead: the registry keeps listing its models (#197 established
   exactly that), and the dispatch-failure path owns that diagnosis.

4. **Ad-hoc agent on selection** (pure constructor, unit-tested):
   `provider = cliproxyapi`, `tools = {"@all"}`, `synthetic_system_prompt = true`,
   default chat system prompt, and `web_search_strategy` derived from the model
   family by a single source in `providers.lua`. **Tools and web search are on by
   default.** Registered into `M.agents` / `M._agents` for the session so the tool
   badge, header prefix, `:ParleyAgent <name>` and `get_agent` work unchanged.

   **Server-side web search is enabled differently per family** — measured
   against the live proxy 2026-08-31, and the reason the strategy is three-way:

   | family | server-side web search |
   |---|---|
   | `claude-*` | `anthropic_tools_route`; the OpenAI route returns an empty completion |
   | `gpt-*` / codex | `openai_tools_route` — returns a cited answer |
   | gemini / antigravity | **neither**: `{type="web_search"}` makes the model answer with `finish_reason: "malformed_function_call"` and no content, so the strategy is `none` |

   Client-side function tools work over the OpenAI route for **all three**
   (verified), so `tools = {"@all"}` stays unconditional; only the server-side
   search varies. Google's own `{google_search={}}` on the gemini route DOES work
   through cliproxy, so a `google_tools_route` strategy is a real future
   extension — out of scope here, and until it exists shipping `none` beats
   shipping an agent that answers with nothing.

5. **Survives restart.** `_state.live_agent` is re-registered at setup *before* the
   `M.agents[M._state.agent]` fallback at `init.lua:1329`; without that ordering a
   live pick silently reverts to the first agent on the next launch.

6. **Config cleanup.** Delete `cliproxy.config["oauth-model-alias"]` (16 lines).
   `resolve_channel` derives from the catalog instead, with the alias block still
   honored as an override when present so pinning a channel stays possible. One
   small knob replaces the model lists:

   ```lua
   cliproxy = {
     live_models = {
       providers = { "claude:opus,sonnet", "codex:gpt-5.6", "antigravity" },
       per_provider = 3,   -- nil providers = every known provider, unfiltered
     },
   },
   ```

   **Entry syntax: `"<provider>[:<term>[,<term>…]]"`.** The provider is the thing
   you log into; the optional terms are case-insensitive substrings matched
   against **both the model id and its displayName**. Matching displayName is
   required, not a nicety: antigravity's ids are opaque handles
   (`gemini-pro-agent` is "Gemini 3.1 Pro (High)"), so an id-only match would make
   that provider unfilterable.

   The terms narrow; the curation above then picks the newest per series and caps
   at `per_provider`. **Term order is display order**, so the config expresses
   preference. Verified against the live 43-model catalog on 2026-08-31:

   | entry | renders |
   |---|---|
   | `claude:opus,sonnet` | Claude Opus 5, Claude Sonnet 5 |
   | `claude:opus,sonnet,fable` | Claude Opus 5, Claude Sonnet 5, Claude Fable 5 — the shipped default |
   | `claude` | Claude Opus 5, Claude Sonnet 5, Claude Fable 5 |
   | `codex:gpt-5.6` | GPT 5.6 Luna, GPT 5.6 Sol, GPT 5.6 Terra |
   | `antigravity:pro,flash` | Gemini 3.1 Pro (Low), Gemini 3.1 Pro (High), Gemini 3.7 Flash |
   | `antigravity` | Claude Opus 4.6 (Thinking), Claude Sonnet 4.6 (Thinking), Gemini 3.7 Flash |

   Every row here is a `curate` equality test keyed by its exact spec string —
   the spec derives its cases from this table, so a row cannot be added without a
   test. Equality, not containment: order is part of the render.

   The knob names providers and families, never model versions, so it does not go
   stale against the catalog. A listed provider that is logged out shows as
   `(logged out)` rather than disappearing. `<C-a>` bypasses both filter and
   curation and shows the entire catalog — the escape hatch stays total.

## Done when

- The picker offers live cliproxy models with no model named in `config.lua`.
- Picking one runs a query with tools and web search active, on the right wire for
  its family.
- A live pick survives a nvim restart.
- A configured provider with no healthy credential shows as `(logged out)` and
  selecting that row starts its login.
- `oauth-model-alias` is gone from the default config and auth diagnosis still
  names the right login for a failing model — proven by a case that runs with an
  EMPTY alias block, since a test that builds its own passes either way. Where
  several channels could serve the model, credential health picks between them
  rather than the code guessing or giving up.
- Opening the picker never starts the proxy.

## Plan

Durable design: `workshop/plans/000205-live-cliproxy-model-picker-plan.md`
(authored via superpowers-writing-plans; per-task TDD steps live there).

- [x] M1 — pure catalog core: `parse` (join /v1/models + /v1beta/models), `series`,
      `rank_key`, `parse_provider_spec`, `curate`, `build_agent`; real captured
      fixtures, no mocks (ARCH-PURE)
- [x] M2 — IO shell: `fetch_catalog` + disk cache + staleness; `fake_cliproxy`
      gains /v1beta/models and the created-less row shape (ARCH-MOCK)
- [x] M3 — picker: live section, `(logged out)` login rows, `<C-a>` full catalog,
      background repaint, live agent registered + persisted across restart
- [ ] M4 — retire the lists: `resolve_channel` derives from the catalog (alias
      block becomes an override), delete `oauth-model-alias`, add `live_models`,
      atlas + README

## Log


- 2026-09-01: closed M3 — BR-58 closed on the exact measurement the reviewer used. (1) The CALL SITE is now covered: a spec calling _on_login_success directly left the invocation inside the credential watch untested — deleting that line kept every spec green — so cliproxy_login_spec drives run_login against the fake and asserts the catalog was invalidated; deleting the call fails it. (2) A residual the fix itself introduced: _force_stale was cleared at the START of an attempt, so the first DECLINED refresh discarded a login invalidation and put the operator back into BR-58 symptom by a new route; it clears on a STORED result now, pinned by a test that logs in, declines a fetch and asserts staleness holds. Both mutations verified to fail. Round-16 work also stands: catalog_stale is pure in cliproxy_config with six unit cases and no seams/clock/network; <C-a> keeps the cursor; the declined-write path resolves with the cache; the vim.system launch is guarded; the code->table guard is scoped to this issue diff and fails when a row is deleted; no logger.error on a picker-open path. Lint clean across 146 files; providers/cliproxy-managed mapping green 0 failures; catalog integration 18/18, login 13/13, float_picker 77/77, arch 4/4. Picker verified end to end against the live proxy with server_tool_use + web_search_tool_result and the correct current version.; review verdict: FIX-THEN-SHIP
### 2026-08-31 — M3 Done-when, evidenced

A live pick carries client tools AND server-side web search on the Anthropic
wire. Verified by building the payload through the production path
(`register_live_agent` → `get_agent` → `cliproxyapi.format_payload`) and POSTing
those exact bytes to the live proxy:

```
agent=claude-opus-5* provider=cliproxyapi model=claude-opus-5
  strategy=anthropic_tools_route tools={ "@all" }   (10 client tools selected)
wire route = anthropic
server tools in payload: web_search, web_fetch
→ response block types: thinking, server_tool_use, web_search_tool_result, text
→ text: "Neovim v0.12.5"   (stop_reason=end_turn)
```

The answer is the tell: the paths where the tool is inert returned v0.11.x from
memory, so a correct current version is evidence the search actually ran rather
than that the request merely succeeded.

**Review-window gap (BR-44).** Commit 747c8ff — M2's FIX-THEN-SHIP bundle — falls
in no boundary window: M2's window ended at 60b964b and M3's begins after
747c8ff. Its content (BR-38..BR-41 fixes) is therefore unreviewed by any gate.
Recorded here so the issue-close review can take it deliberately rather than
inherit the gap silently.

### 2026-08-31
- 2026-08-31: closed M2 — providers/cliproxy-managed mapping green (0 failures), arch guards green, keybindings 24/24. Demoted backlog cleared, including three more live data-loss/crash paths measured and pinned: a foreign 200 on the endpoint wiped a warm catalog (the write now gates on classify(), the existing single source for cliproxy /v1/models contract, after #models>0, curl exit code and HTTP-200 each lost data in turn); fetch_catalog dropped its callback on the in-flight path so a picker opened during a refresh never repainted; catalog_cached re-read and re-mkdird on every keystroke-path open and `providers = nil` returned {} instead of every known provider as config.lua documents. Every fix mutation-checked by reverting it — including the foreign-200 test itself, which initially reused a just-killed port so the dying process answered and the revert stayed green. Also: id.."*" single-sourced as agent_name (3 sites that must agree or a model renders twice), the `or "<C-a>"` literal removed and the arch guard widened to the fallback forms, README documents live_models and <C-a>, atlas heading no longer orphans the flow narrative, keybinding scoped parley_buffer, fake v1beta branches mirror /v1/models.; review verdict: FIX-THEN-SHIP
- 2026-08-31: closed M1 — cliproxy_catalog_spec 41/41 green (every documented Spec render pinned as an equality, derived from a table keyed by the spec string so a new row cannot skip a test); providers/cliproxy-managed mapping green, 0 failures. Round 3-4 findings addressed as RULES: rank_key uses a delimiter rule not a magnitude threshold (BR-13); unknown provider contributes nothing instead of pooling ownerless rows (BR-6); empty ids rejected at the parse boundary rather than defended per-consumer (BR-7); build_agent returns nil instead of raising into a picker callback (BR-8); plan referents and all 26 invalid SPEC keys swept, referent grep re-run clean (BR-1, BR-9). BR-12 resolved by measurement: an antigravity-served claude answers 200 on the anthropic wire, so family decides the transport and owner only reaches the search tool.; review verdict: FIX-THEN-SHIP

- Brainstormed with operator. Verified against the live proxy: alias block is
  vestigial for routing; `/v1beta/models` carries displayName/description/version;
  antigravity models carry no `created`; `owned_by` is unstable for shared ids.
  Test proxies on 8319/8320 (copied auth dir) used to isolate `force-model-prefix`
  — it makes no difference; the 30 vs 43 model gap was registration timing.
- Design decisions: live picker only (configured agents untouched); `<C-a>` toggle
  for the full catalog; a configured PROVIDER list (not owners) that also drives
  `(logged out)` placeholder rows; `provider:term,term` model filters matched
  against id AND displayName; tools + web search on by default for ad-hoc picks.
- Filter syntax verified against the live catalog before speccing — the four rows
  in the Spec table are real renders, captured as the `curate` test cases.

## Estimate

Method A primitive decomposition. Step 3 spec-quality discount (x0.2 on design)
applied to the *implementation* primitives — this issue has a dense Spec plus a
~1,490-line plan with per-task TDD steps, so their design dialogue is
front-loaded. It is deliberately NOT applied to `issue-spec` (you cannot discount
authoring a spec by that spec's own quality) or to `ux-rename-iteration` (operator
feedback on a rendered UI is exactly what a spec cannot pre-empt). Step 2.5
library-availability: N/A, no novel stack — every seam already exists in-repo
(`api_argv`, `float_picker`'s update handle, the `fake_cliproxy` process fake).
Per v3.1 the design buffer is +15% rather than +30% because of that plan doc, and
`impl=` values are written at 40% of the v2 table.

`milestone-review` covers five boundaries at ~0.15 each: M1-M4 plus the review
`sdlc close` dispatches on its own window. `real-api-discovery` is one external
surface (cliproxy `/v1beta/models`) and is already partly spent — the routes, the
created-less antigravity rows and the per-family web-search behavior were all
probed live during design. `ux-rename-iteration` budgets one round on the picker's
row format, grouping and `<C-a>` affordance, which are the parts that invite
operator feedback once seen.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec              design=0.5  impl=0.1
item: lua-neovim              design=0.3  impl=0.4
item: lua-neovim              design=0.2  impl=0.3
item: lua-neovim              design=0.3  impl=0.5
item: lua-neovim              design=0.2  impl=0.3
item: ux-rename-iteration     design=0.15 impl=0.1
item: real-api-discovery      design=0.0  impl=0.15
item: milestone-review        design=0.0  impl=0.75
item: atlas-docs              design=0.05 impl=0.05
design-buffer: 0.15
total: 4.61
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.*

**Re-derived 2026-08-31 after M4 grew.** The first derivation (3.92h) costed M4 as
`cross-cutting-refactor` (0.25h) before the PQ-10/PQ-12 rounds rewrote Task 4.1
into a behavioural change to credential diagnosis with a new shared reducer seam.
That is a `lua-neovim` item, not a rename. Also added: one UX-iteration round and
a fifth review boundary.

The four `lua-neovim` items are, in order: the pure catalog core (M1), the
fetch/cache IO shell (M2), the picker integration (M3), and M4's channel
resolution rework.

## Revisions

### 2026-08-31 — three-way web-search strategy; series claim withdrawn

**Reason:** operator flagged that server-side web search is enabled differently
per family; probing the live proxy confirmed it and showed the original two-way
rule would ship a broken gemini agent.

**Delta:**
- Component 4: `web_search_strategy` is three-way (`anthropic_tools_route` /
  `openai_tools_route` / `none`), single-sourced in `providers.lua` beside the
  existing canonical family test rather than re-implemented in the catalog
  module. Evidence table added.
- Components: withdrew the "series falls back to a displayName-derived stem"
  claim. The id rule already yields the correct curation for every verified
  case — including antigravity, where "Gemini 3.1 Pro (Low)" and "(High)" are
  different offerings that SHOULD stay separate series. Specifying a fallback
  nothing implemented was the actual defect (plan-gate PQ-4).
- Component 6 / M4: catalog-derived channel resolution narrows to channel
  CANDIDATES and returns a channel only when exactly one is possible; `owned_by`
  is not a channel and antigravity serves several owners' models (plan-gate
  PQ-1). The alias block stays the operator's explicit override.

### 2026-08-31 — channel ambiguity resolved by health, not abandoned

**Reason:** plan-gate PQ-10. The candidate-narrowing fix returned nil for both
providers the default config ships (anthropic and openai are each served by their
native channel AND antigravity), so M4 as written would have degraded every
real diagnosis to "no cliproxy channel is configured".

**Delta:** `resolve_channel` becomes `resolve_channels` (plural). When more than
one candidate remains, the existing cross-channel health fan-out decides — the
same traversal `credential_health_for_login` uses, extracted with an injectable
reducer so "healthiest" and "least healthy" share one implementation. The
give_up texts that tell the operator to add an `oauth-model-alias` key are
rewritten in the same pass, and Done-when now demands a proof that runs with an
empty alias block.

### 2026-08-31 — render corrected to what ships (BR-25)

**Reason:** the Spec documented an em dash and "one group per configured
provider"; the implementation renders a hyphen and expresses grouping as
ordering. Left unstruck, the drift was restated a third time in the atlas.

**Delta:** the Spec now documents the shipped render. The hyphen is deliberate —
the configured-agent rows above are built by existing code as
`<name> - <model> (<provider>)`, and a different dash on the live rows would make
one list look like two conventions. Grouping is ordering rather than headers,
because the separator already delimits the section and float_picker has no
non-selectable row: every header would be a selectable, fuzzy-matchable item.
Both are pinned as full-string equalities in picker_items_spec, so a future drift
fails a test instead of accumulating another restatement.

### 2026-08-31 — logged-out source restated to match the code (BR-45)

**Reason:** Component 3 named `cliproxy_auth.lua` / `channels_for_login` as the
credential source and forbade `owned_by`, while the implementation derives the
signal from the catalog. The Spec was describing a design that was reconsidered
during M3 and never restated.

**Delta:** Component 3 now documents the catalog heuristic, why it is preferred
on a keystroke path, and the case it deliberately does not cover (a loaded but
dead credential, which #197's dispatch-failure path owns).
