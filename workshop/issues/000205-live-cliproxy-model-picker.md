---
id: 000205
status: working
deps: []
github_issue:
created: 2026-08-31
updated: 2026-08-31
estimate_hours:
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
   - `curate(models, opts)` → the default view: dedupe by series, rank by `created`
     falling back to a version parsed from `displayName`, take `per_owner` (default
     3) per owner, honoring an owner allowlist.
   - Series is derived by stripping version numerals from the id, and from
     `displayName` for owners whose ids are opaque.

2. **Catalog cache — IO shell in `cliproxy.lua`.** Fetch both routes through the
   existing `api_argv` seam (ARCH-DRY). Cache in memory; persist to
   `stdpath('data')/parley/cliproxy/catalog.json` so the picker is instant and
   populated on a cold start. Refresh on picker open when stale, **only if the
   proxy already answers** — opening a picker must never spawn the daemon, which
   preserves the "dormant unless a cliproxyapi agent runs" contract from #131.

3. **Live section in the agent picker.** Configured agents, separator, then one
   group per configured provider: curated live models rendered as
   `Claude Opus 5 — claude-opus-5 (anthropic)`. `<C-a>` toggles the full catalog
   for the uncurated rest (haiku, gpt-oss-120b, …).

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
   default chat system prompt, and `web_search_strategy` derived from the family —
   anthropic-owned ids get `anthropic_tools_route`, everything else inherits the
   provider default `openai_tools_route`. **Tools and web search are on by
   default.** Registered into `M.agents` / `M._agents` for the session so the tool
   badge, header prefix, `:ParleyAgent <name>` and `get_agent` work unchanged.

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
       providers = { "claude", "codex", "antigravity" },  -- nil = every known provider
       per_provider = 3,
     },
   },
   ```

   It names providers — the things you log into — never model versions, so it
   never goes stale against the catalog. A listed provider that is logged out
   shows as `(logged out)` rather than disappearing.

## Done when

- The picker offers live cliproxy models with no model named in `config.lua`.
- Picking one runs a query with tools and web search active, on the right wire for
  its family.
- A live pick survives a nvim restart.
- A configured provider with no healthy credential shows as `(logged out)` and
  selecting that row starts its login.
- `oauth-model-alias` is gone from the default config and auth diagnosis still
  names the right login for a failing model.
- Opening the picker never starts the proxy.

## Plan

- [ ]

## Log

### 2026-08-31

- Brainstormed with operator. Verified against the live proxy: alias block is
  vestigial for routing; `/v1beta/models` carries displayName/description/version;
  antigravity models carry no `created`; `owned_by` is unstable for shared ids.
  Test proxies on 8319/8320 (copied auth dir) used to isolate `force-model-prefix`
  — it makes no difference; the 30 vs 43 model gap was registration timing.
- Design decisions: live picker only (configured agents untouched); `<C-a>` toggle
  for the full catalog; a configured PROVIDER list (not owners) that also drives
  `(logged out)` placeholder rows; tools + web search on by default for ad-hoc
  picks.
