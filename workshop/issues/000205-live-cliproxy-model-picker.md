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

3. **Live section in the agent picker.** Configured agents, separator, then one
   group per configured provider: curated live models rendered as
   `Claude Opus 5 — claude-opus-5 (anthropic)`. `<C-a>` toggles the entire
   catalog — filter and curation both bypassed — for the rest (haiku,
   gpt-oss-120b, …).

   **Logged-out providers stay visible.** A provider named in config that has no
   healthy credential contributes no models to the catalog (measured: antigravity
   models appeared only once its auth file registered), so it would silently
   vanish. Instead it gets one placeholder row — `antigravity — (logged out)` —
   and selecting it runs `:ParleyProxy login <provider>`. The picker thus answers
   both "which model" and "why is my provider missing".

   Credential state comes from parley's existing `/v0/management/auth-files`
   reader (`cliproxy_auth.lua`, #197), keyed by CHANNEL via `channels_for_login`,
   never by `owned_by`. Catalog rows are attached to a provider through the
   existing `PROVIDER_OWNED_BY` map (claude→anthropic, codex→openai,
   antigravity→antigravity, google→google), which is a static map and so is
   unaffected by the shared-id instability noted above.

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
   | `claude` | Claude Opus 5, Claude Sonnet 5, Claude Fable 5 |
   | `codex:gpt-5.6` | GPT 5.6 Luna, GPT 5.6 Sol, GPT 5.6 Terra |
   | `antigravity:pro,flash` | Gemini 3.1 Pro (Low), Gemini 3.1 Pro (High), Gemini 3.7 Flash |

   These rows are the unit-test cases for `curate`.

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

- [ ] M1 — pure catalog core: `parse` (join /v1/models + /v1beta/models), `series`,
      `rank_key`, `parse_provider_spec`, `curate`, `build_agent`; real captured
      fixtures, no mocks (ARCH-PURE)
- [ ] M2 — IO shell: `fetch_catalog` + disk cache + staleness; `fake_cliproxy`
      gains /v1beta/models and the created-less row shape (ARCH-MOCK)
- [ ] M3 — picker: live section, `(logged out)` login rows, `<C-a>` full catalog,
      background repaint, live agent registered + persisted across restart
- [ ] M4 — retire the lists: `resolve_channel` derives from the catalog (alias
      block becomes an override), delete `oauth-model-alias`, add `live_models`,
      atlas + README

## Log

### 2026-08-31

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
