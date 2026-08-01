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
  `status`/`start`/`stop`/`restart`/`login_argv`. The curl argv is built once in
  `api_argv` (route-parameterized since #197) and shared by `health_probe`, the
  stop-time identity check, `list_models`, and the management read (ARCH-DRY).
  Tested against a process-level fake.
- **`cliproxy_auth.lua`** (pure, #197): the auth-failure vocabulary, credential
  health, and the diagnosis text — see Auth-failure → diagnosis and recovery.

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
`skill_invoke` clears its in-flight guard; `memory_prefs` advances its batch),
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

## Auth-failure → diagnosis and recovery (#197)

**The principle: parley does not infer credential state, it asks.**

#131 M3 inferred it two ways and both were wrong by 2026-08-01: a single
response pattern (`"unknown provider for model <X>"`, which 7.1.71 no longer
emits for a dead credential) and the shape of `/v1/models` (which still lists
every model while the credential is dead). The source of truth is now the
proxy's own **`GET /v0/management/auth-files`**.

- **`cliproxy_auth.lua`** (pure, no IO):
  - `classify_response(http_status, body, request_model)` → `{kind, provider,
    model, message}` over a pattern table of the messages the binary actually
    emits (`auth_unavailable`/`no auth available (providers=…, model=…)`,
    `unknown provider for model`, `OAuth access token has expired`,
    `payment_required`, …). **Returns nil for every 2xx, whatever the body
    says** — the patterns are broad enough to match ordinary assistant prose, and
    the caller sees successful bodies too. A property test pins it.
  - `classify_auth_files(files, channel)` → `{state, message, account, failed,
    modtime}`, `state ∈ healthy|error|unavailable|disabled|missing`. The single
    interpreter of the management schema; healthiest record wins.
  - `diagnosis(verdict, health)` → the sentence a human reads. Quota and
    model-unavailable never say "log in".
- **`cliproxy.lua`**: `management_key()` (read-or-create `management.key`, 0600,
  beside the rendered config — *not* the vault, which is in-memory and
  setup{}-populated), `auth_files()` (the raw read), `credential_health()` (adds
  the one unattended repair, below), `recover()` (the policy).
- **`api_argv`** replaces `models_argv`, parameterized by route, so the health
  probe, the stop-time identity check, `list_models`, and the management read
  share one request shape (ARCH-DRY).

### One owning seam

Auth-failure reaction lives in **`dispatcher.lua`'s terminal closure** — the only
scope holding HTTP status, body, and the request's model — reached via the
optional adapter hook **`recover_query(failure, retry, give_up)`**. The old
`check_auth_failure` call in `finish_stdout` is gone: that path runs on *every*
completed response, so classifying there classified assistant prose (a chat
quoting `authentication_error` would have popped a login prompt).

**The claim contract.** `on_error` is terminal downstream — it finishes the
pending session and tears down the chat leg (`chat_respond.lua`
`teardown_chat_leg`) — while recovery is async. So the hook cannot merely "run
first"; it **claims** synchronously (cheap: `classify_response` is pure):

- falsy → the dispatcher calls `on_error` immediately, exactly as before. Every
  adapter without the hook takes this path.
- truthy → `on_error` is withheld and the adapter owes exactly one of
  `retry()`/`give_up(msg)`, both behind one `tasker.once`. A 15s
  `recovery_timeout_ms` backstop degrades a hung recovery to today's behavior
  rather than stranding the chat leg.

cliproxy claims only when: a verdict exists, `attempt == 0`, and nothing has
streamed (`failure.streamed`) — a retry after partial content would duplicate
text. `failure.model` carries `payload.model`, the only path by which the
expired-token 401 (which names neither provider nor model) resolves to a channel
via `resolve_login_provider`.

### The recovery ladder

`cliproxy_auth.decide(verdict, health, proxy_state, attempt, login)` is the whole
policy, pure and table-tested: one action out of `start` | `restart` | `retry` |
`prompt_login` | `report`. `recover` gathers the inputs (liveness probe,
credential health, the auth-dir mtime) and executes exactly one action, settling
the claim exactly once.

| situation | action |
|---|---|
| proxy not running | `start`, then retry |
| credential `healthy` (failure was transient) | `retry` — **no prompt** |
| the credential file changed **after** the proxy loaded it (`modtime` > `updated_at`) | `restart`, then retry |
| `missing` / `disabled` / `unavailable` | `prompt_login` with the proxy's own reason |
| `error` whose message is auth-shaped | `prompt_login` |
| `error` that isn't (DNS, upstream 5xx) | `report` — a login won't fix it |
| `quota` / `model_unavailable` | `report`, never "log in" |
| credential state unreadable | `report` honestly |
| `attempt >= 1` | never a repair — pinned by a property test |

`attempt` is the entire anti-loop mechanism: no repair action exists above
attempt 0, so a retry cannot beget another. A `prompt_login` with no resolvable
login provider degrades to `report` — a prompt you cannot act on is a worse
report.

**Timeout budget.** The repair must finish inside
`dispatcher.recovery_timeout_ms`, or the backstop spends the claim's one-shot and
replaces a correct diagnosis with "recovery timed out". The budget is *derived*
in `cliproxy._repair_budget_sec` from the constants each step uses
(`CURL_MAX_TIME`, `PORT_RELEASE_MS`, `POLL_BUDGET_MS`, plus the one extra probe
each bounded poll can overrun by), and `cliproxy_budget_spec` asserts it stays
comfortably under the backstop — deliberately no numbers restated here, because
three successive reviews re-opened this drift when the docs carried the
arithmetic. The compound case (a 404 repair followed by a `restart` decision) is
made unreachable rather than budgeted: one restart per claim.

### The management route, and the 404 that matters

cliproxy registers `/v0/management/*` only when it **booted** with a
`remote-management.secret-key`, and authenticates it with that key specifically
(the `api-keys` bearer gets 401 — pinned by the conformance spec). `render` now
emits that key, defaulting `disable-control-panel: true` and never setting
`allow-remote`, so the surface stays loopback-only.

A proxy started before the key existed therefore answers **404**, and that is the
honest signal to restart it — `credential_health` does so **at most once per consecutive run of 404s** — the
guard clears on any successful lookup, so a proxy the operator restarts
mid-session is still repairable. The repair is skipped entirely when
`manage = false`: `stop()` would reap the operator's own proxy and
`ensure_running` does not spawn for an unmanaged instance. There is deliberately no config-file drift check: `ensure_running`
rewrites the rendered config *before* it probes, so a file-vs-render comparison
is always false and never reflects what the running process loaded.

### Peer proxies, and the login flow

**Peers.** Every cliproxy runs a 15-minute auth refresh over its auth-dir, and
Claude's OAuth refresh tokens rotate on use — so N proxies sharing one auth-dir
invalidate each other's credential. That is what broke auth in #197 (five leaked
instances from June). `peers()` finds cliproxy processes parley neither spawned
nor manages, matching on the **executable** rather than a substring (a real `ps`
contains a `zsh -c` wrapper quoting the proxy path — substring matching would
SIGTERM the operator's shell) and on **both** binary names (`cliproxyapi` from
brew, `cli-proxy-api` from the tarball). `ensure_running` warns once per session
naming that mechanism, and `:ParleyProxy reap` stops them after showing what it
found. `stop()` no longer leaks parley-spawned proxies on non-managed ports.

**Login.** `:ParleyProxy login <provider>` now:
1. **preflights the callback port** (claude's redirect is fixed at
   `localhost:54545`) by *connecting*, not binding — libuv sets `SO_REUSEADDR`,
   so a bind probe reports "free" for exactly the case this catches;
2. runs with `-no-browser` and **captures the authorize URL**, opening it via
   `vim.ui.open` and surfacing it so a failed auto-open is still recoverable;
3. keeps the job **off a closable terminal buffer** — in #197 the terminal-split
   job died mid-flow, taking its callback listener with it, and the browser's
   redirect had nowhere to land while nothing reported the death;
4. **watches the auth-dir** for a written credential and reports the real
   outcome: success with the account, a non-zero exit with its stderr, or a
   bounded timeout telling the operator to re-run.

### Testing

The fake (`tests/fixtures/fake_cliproxy`) serves the management route from a
**portable credential store** — a folder of auth JSONs plus a `state.json`
overlay tests mutate between calls — and models the 200/401/404-without-key
cases. It also serves the real 503/401/402 bodies on `/v1/chat/completions`
(`--error-mode`), which is what lets `cliproxy_recovery_e2e_spec.lua` drive a
real failure through `dispatcher.query` → `recover_query` → the operator-facing
notice rather than hand-building failure tables.
`cliproxy_conformance_spec.lua` boots the **real** binary against a
*fabricated* credential in a throwaway auth-dir and asserts the fields
`classify_auth_files` reads still exist — including the 404-without-key
behavior the entire repair branches on. Never point that at the real auth-dir:
cliproxy refreshes at startup and every 15m, and Claude's refresh tokens rotate
on use — the race that caused this issue.

## Models & providers (#132)

`:ParleyProxy` is self-documenting and can list what a provider serves:

- **`:ParleyProxy providers`** — the supported model-owning provider names
  (`cliproxy_config.providers()`: antigravity, claude, codex, google, kimi, xai).
- **`:ParleyProxy models <provider>`** — `list_models(provider, cb)`:
  `ensure_running` → `GET /v1/models` with the bearer → `filter_models_by_owner`
  keeps only ids whose `owned_by` matches the provider (map verified against the
  CLIProxyAPI catalog: claude→anthropic, codex→openai, google→google, xai→xai,
  kimi→moonshot, antigravity→antigravity). `/v1/models` reads the **dynamic**
  registry, so an empty list means "this provider serves no models right now" —
  **not** "not authenticated". #197 disproved that inference (the registry kept
  listing every model with the credential dead), so an empty list now triggers a
  credential-health read on the CHANNEL axis
  (`credential_health_for_login`: `google` → gemini / gemini-cli / aistudio) and
  the shared `credential_action` policy decides between "authenticated but no
  models — check the catalog", a login prompt carrying the proxy's own reason,
  and an honest "state could not be read".
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
