# Managed cliproxyapi (opt-in)

Parley can manage a local [cliproxyapi](https://github.com/router-for-me/CLIProxyAPI)
instance — render its config, start it on demand, reuse it if it's already up —
so users stop hand-maintaining `/opt/homebrew/etc/cliproxyapi.conf` and
`brew services`. Issue #131.

**On by default** (`config.lua` ships `cliproxy = { manage = true, … }`), but
**dormant** — it only acts when a cliproxyapi-provider agent actually runs, and
it **reuses** an already-running proxy (e.g. `brew services`) when one answers
healthy. So the default is safe for users who don't use cliproxyapi (it never
fires) and cooperative for those who run their own (it reuses it). Set
`cliproxy = { manage = false }` to opt out. A new machine needs only
`brew install cliproxyapi` + a one-time `:ParleyProxy login <provider>`.

## Pieces

- **`cliproxy_config.lua`** (pure): `parse_endpoint` (host:port from the provider
  endpoint — the single source of truth, no separate port knob), `render` (merge
  raw `config` passthrough + wiring fields + the resolved client secret), `encode`
  (JSON-as-YAML — valid YAML 1.2, no emitter needed), and the model-discovery
  trio `providers`/`provider_owned_by`/`filter_models_by_owner` (#132 — see Models
  & providers). Unit-tested, no mocks.
- **`cliproxy.lua`** (IO): `discover_binary` (`cliproxy.binary_path` → `cliproxyapi`/
  `cli-proxy-api` on PATH), `health_probe` (`GET /v1/models` with the bearer →
  `healthy`/`needs_login`/`client_key_mismatch`/`foreign`/`down`), `spawn`
  (detached, PID-tracked), `ensure_running` (reuse-if-healthy → else
  discover/spawn/poll, bounded — never hangs), `list_models` (#132), and
  `status`/`start`/`stop`/`restart`/`login_argv`. The `GET /v1/models` curl argv is
  built once in `models_argv` and shared by `health_probe`, the stop-time identity
  check, and `list_models` (ARCH-DRY). Tested against a process-level fake.

## Flow

`setup{ cliproxy.manage = true }` → on the first dispatch to a cliproxy-provider
agent, the adapter's **`pre_query`** hook (the same seam copilot uses) calls
`ensure_running`:

1. parse host:port from `providers.cliproxyapi.endpoint`; render the config from
   Lua + the vault-resolved secret; write it `0600` to
   `stdpath('data')/parley/cliproxy/config.yaml` (a derived artifact — the
   committed Lua is the source of truth).
2. probe `/v1/models`. `healthy`/`needs_login` → proceed (reuse). `foreign`/
   `client_key_mismatch` → abort. `down` → discover the binary, spawn it
   detached, poll until healthy (≤5s) or abort.

On any failure, `ensure_running` drives **`on_error`** → the dispatcher's
**abort channel** (`D.query`'s trailing `on_abort`) → each caller's qid-free
teardown (`chat_respond` collapses the empty answer + stops the spinner;
`skill_runner` clears its in-flight guard; `memory_prefs` advances its batch),
so the request fails fast instead of hanging. **`:ParleyProxy stop` is transient**
— every dispatch re-`ensure_running`s, so a dead/stopped proxy revives on next use.

`stop` reaps **across sessions**: it kills this session's spawned PIDs *and* a
leftover cliproxy on the managed port spawned by an earlier nvim (parley's
proxies are detached + survive nvim exit, so `_spawned` alone can't reach them).
It **identity-probes the port first** (the same `/v1/models` classifier as
`health_probe`), so a *foreign* process holding the port is never killed — only
a process that actually answers as cliproxy. `restart` = `stop` + ensure.

## Auth & secrets

- The **client token** (`api_keys.cliproxyapi`) is resolved through the vault and
  written into the rendered `api-keys`; the committed Lua holds no secret.
- **OAuth subscription tokens** live in `auth-dir` (default `~/.cli-proxy-api`),
  written by `:ParleyProxy login <provider>` → `cliproxyapi -<provider>-login`
  (per-provider flags: claude, codex, codex-device, google, kimi, xai,
  antigravity). The one unavoidable manual, per-machine step.

## Required even when managed

`api_keys.cliproxyapi` must be set even with `manage = true` — the dispatcher's
`vault.run_with_secret` gate runs *before* `pre_query`, so a missing secret
silently skips the request (neither the query nor the abort fires). This is the
same gate all secret-backed providers use; just be aware managed mode doesn't
remove the secret requirement (the secret is the client↔proxy token).

## Auth-failure → guided login (M3)

When a cliproxy chat fails because the upstream credential is missing/invalid,
cliproxyapi returns `"unknown provider for model <X>"` (it resolves models only
from *loaded* auth clients — `util.GetProviderName` reads the dynamic registry,
so an unloaded auth makes the model unresolvable; the static catalog isn't
consulted). The dispatcher's cliproxy response path calls
`cliproxy.check_auth_failure`, which:
1. `cliproxy_config.detect_auth_failure` extracts `<X>` from that error.
2. `cliproxy_config.resolve_login_provider` finds the **channel** whose
   `oauth-model-alias` list contains `<X>` and maps it → a login provider — over
   cliproxyapi's fixed channel set (claude/codex/gemini-cli/vertex/aistudio/kimi/
   antigravity). This is **config-driven, not a name heuristic**: the channel
   key in the rendered `oauth-model-alias` *is* the provider (the default keys by
   the canonical `claude` channel for exactly this reason).
3. prompts (`vim.ui.select`) `:ParleyProxy login <provider>`.

## Models & providers (#132)

`:ParleyProxy` is self-documenting and can list what a provider serves:

- **`:ParleyProxy providers`** — the supported model-owning provider names
  (`cliproxy_config.providers()`: antigravity, claude, codex, google, kimi, xai).
- **`:ParleyProxy models <provider>`** — `list_models(provider, cb)`:
  `ensure_running` → `GET /v1/models` with the bearer → `filter_models_by_owner`
  keeps only ids whose `owned_by` matches the provider (map verified against the
  CLIProxyAPI catalog: claude→anthropic, codex→openai, google→google, xai→xai,
  kimi→moonshot, antigravity→antigravity). `/v1/models` reads the **dynamic**
  registry (loaded auth clients only), so an unauthenticated provider contributes
  no models → **empty list** → the command prompts `:ParleyProxy login <provider>`.
  Chosen over the management API precisely because it auth-detects for free and
  needs no management secret.
- **Bare `:ParleyProxy`** prints per-subcommand help; `SUBS_HELP` (init.lua) is the
  single source for both the usage text and the completion list (ARCH-DRY).

**Two provider axes, kept distinct.** `models`/`providers` use the *model-owning*
set (`cliproxy_config.providers()`, each with an `owned_by`). `login` uses the
*login-method* set (`cliproxy.login_providers()`, from `LOGIN_FLAGS`) which also
has `codex-device` — a login flow, not a distinct provider. Completion for
`models <X>` and `login <X>` draws from the matching axis, so neither leaks the
other's extras.

## auto_download (M2)

`cliproxy = { manage = true, auto_download = true }` removes the
`brew install` step: when `discover_binary` finds nothing, `ensure_running`
fetches the **pinned** release (`cliproxy.lua` `PINNED_VERSION`, overridable via
`cliproxy.download_version`) for the host platform — `cliproxy_config.platform`
+ `asset_name` build the asset name, `download()` curls the tarball +
`checksums.txt`, **sha256-verifies (refuses to install on mismatch)**, and
extracts `cli-proxy-api` into `stdpath('data')/parley/cliproxy/bin/`. That dir
sits between `binary_path` and PATH in `discover_binary`'s chain.
`:ParleyProxy update` re-fetches. The download is synchronous + one-time (cached
after first fetch). Windows (`.zip`) is not auto-downloaded — install manually.
