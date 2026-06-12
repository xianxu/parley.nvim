# Managed cliproxyapi (opt-in)

Parley can manage a local [cliproxyapi](https://github.com/router-for-me/CLIProxyAPI)
instance — render its config, start it on demand, reuse it if it's already up —
so users stop hand-maintaining `/opt/homebrew/etc/cliproxyapi.conf` and
`brew services`. **Off by default**; activated by a `cliproxy = { manage = true }`
block in `setup{}`. Issue #131.

## Pieces

- **`cliproxy_config.lua`** (pure): `parse_endpoint` (host:port from the provider
  endpoint — the single source of truth, no separate port knob), `render` (merge
  raw `config` passthrough + wiring fields + the resolved client secret), `encode`
  (JSON-as-YAML — valid YAML 1.2, no emitter needed). Unit-tested, no mocks.
- **`cliproxy.lua`** (IO): `discover_binary` (`cliproxy.binary_path` → `cliproxyapi`/
  `cli-proxy-api` on PATH), `health_probe` (`GET /v1/models` with the bearer →
  `healthy`/`needs_login`/`client_key_mismatch`/`foreign`/`down`), `spawn`
  (detached, PID-tracked), `ensure_running` (reuse-if-healthy → else
  discover/spawn/poll, bounded — never hangs), and `status`/`start`/`stop`/
  `restart`/`login_argv`. Tested against a process-level fake.

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

## Deferred (M2)

`auto_download` — fetch a pinned release tarball + checksum-verify + extract,
falling through `discover_binary`. Not in M1 (bring-your-own binary).
