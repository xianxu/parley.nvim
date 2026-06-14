---
id: 000132
status: done
deps: []
github_issue:
created: 2026-06-14
updated: 2026-06-14
estimate_hours: 2.5
actual_hours: 0.18
---

# ParleyProxy models + providers commands

## Problem

After #131 (managed cliproxyapi), the `:ParleyProxy` command exposes lifecycle +
login, but there's no way to (a) list the models a provider currently serves, or
(b) discover which provider names are even supported. And the usage line only
names `{status|start|stop|restart|login}` with no per-subcommand help.

## Spec

Add three things to `:ParleyProxy` (`init.lua` `register_proxy_command`):

1. **`:ParleyProxy models <provider>`** — list the AVAILABLE models for a
   provider. Implementation: `ensure_running` → `GET /v1/models` with the client
   bearer (the OpenAI-compatible endpoint parley already uses) → filter by
   `owned_by`. Chosen over the management API because `/v1/models` reads the
   *dynamic registry* (loaded/authenticated providers only), so it (a) shows
   what's actually callable and (b) **naturally detects "not authenticated"** —
   an unauthenticated provider's models simply aren't present → empty list →
   prompt `:ParleyProxy login <provider>`. The management API's static catalog
   can't detect auth and would need a new `remote-management.secret` + a
   mutation-capable surface — rejected.
   Provider → `owned_by` map (verified against the CLIProxyAPI catalog
   `internal/registry/models/models.json`): claude→anthropic, codex→openai,
   google→google, xai→xai, kimi→moonshot, antigravity→antigravity.

2. **`:ParleyProxy providers`** — list the supported provider names (the keys of
   the map above: claude, codex, google, xai, kimi, antigravity).

3. **Usage help** — `:ParleyProxy` with no/invalid subcommand prints every
   subcommand with a one-line description (incl. the existing stop/etc.), so the
   surface is discoverable. Completion: `models <X>`/`login <X>` complete the
   provider list.

### Design (PURE vs IO)
- **Pure** (`cliproxy_config.lua`): `providers()` (sorted provider names),
  `provider_owned_by(provider)` (→ owned_by or nil), `filter_models_by_owner(
  models_json, owned_by)` (parse `/v1/models` body → sorted model ids). Unit-
  tested, no IO (ARCH-PURE).
- **IO** (`cliproxy.lua`): `list_models(provider, cb)` — resolve owned_by →
  `ensure_running` → curl `/v1/models` with the bearer → `filter_models_by_owner`
  → `cb(ids, err)`. Tested against the process-level fake (extend it to answer
  `/v1/models` with an owned_by-tagged list).
- **Command** (`init.lua`): the `models`/`providers` branches + a `SUBS_HELP`
  table driving both the usage text and completion (DRY — one source for the
  subcommand list).

## Done when

- `:ParleyProxy providers` lists claude/codex/google/xai/kimi/antigravity.
- `:ParleyProxy models claude` on an authed proxy lists the anthropic-owned
  models; on an unauthed one (no anthropic models) prompts `login claude`.
- `:ParleyProxy models bogus` → "unknown provider" pointing at `providers`.
- `:ParleyProxy` (bare) prints per-subcommand help including models/providers.
- Pure functions unit-tested; `list_models` integration-tested vs the fake;
  `make test` green; luacheck clean.

## Plan

- [x] Pure `cliproxy_config`: `providers` / `provider_owned_by` /
      `filter_models_by_owner` + unit tests.
- [x] IO `cliproxy.list_models` + extend `fake_cliproxy` to serve `/v1/models`
      with owned_by tags; integration test (authed → list, unauthed → empty).
- [x] `init.lua`: `models`/`providers` command branches + `SUBS_HELP`-driven
      usage + provider completion; command-spec test. Then milestone-close.

## Log

### 2026-06-14
- 2026-06-14: closed — TDD, all green: 12 unit assertions for providers/provider_owned_by/filter_models_by_owner (cliproxy_config_spec); 4 integration cases for list_models vs the process-level fake (list/discriminate/unauthed-empty/unknown-provider); 4 command-spec cases (bare-help lists all 8 subcommands incl models/providers, providers output, models-no-arg usage, unknown-subcommand WARN). Full `make test` suite green, luacheck 0 warnings/0 errors across 185 files. Atlas updated (Models & providers section + Pieces). Single-pass atomic — no Mx.; review verdict: SHIP
- Designed with the operator: chose /v1/models (dynamic, auth-detecting) over the
  management API (static, needs a management secret). owned_by map extracted from
  the CLIProxyAPI source catalog. Single-pass (atomic) — no Mx split.
- Plan-quality gate: INFO. Folded in its three refinements: (1) ARCH-DRY —
  extracted `models_argv` so the `/v1/models` curl shape has one source (was built
  in `health_probe` + `port_holds_cliproxy`, would've been a 3rd copy in
  list_models); (2) kept the `models`-provider axis (owned_by set) and the
  `login`-provider axis (LOGIN_FLAGS, has codex-device) explicitly distinct in
  both completion + docs — no silent drop of codex-device; (3) made the fake's
  `healthy` mode a mixed-owner list (anthropic + openai) so filtering is proven to
  discriminate, not pass through.
- Implemented TDD: pure trio (12 unit assertions) → `list_models` + fake extension
  (4 integration cases incl. discriminate + unauthed-empty) → command branches +
  SUBS_HELP usage + split completion (command-spec: bare-help, providers, models-
  no-arg, unknown-subcommand). Full suite green, luacheck 0/0.
