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
`cliproxy = { manage = false }` to opt out. A new machine needs a binary —
`:ParleyProxy update` downloads the latest release (the first chat does too,
via `auto_download`), or `brew install cliproxyapi` — and a one-time
`:ParleyProxy login <provider>`.

## Pieces

- **`cliproxy_config.lua`** (pure): `parse_endpoint` (host:port from the provider
  endpoint — the single source of truth, no separate port knob), `render` (merge
  raw `config` passthrough + wiring fields + the resolved client secret), `encode`
  (JSON-as-YAML — valid YAML 1.2, no emitter needed), and the model-discovery
  trio `providers`/`provider_owned_by`/`filter_models_by_owner` (#132 — see Models
  & providers). Unit-tested, no mocks.
- **`cliproxy_release.lua`** (pure, #237): the release version grammar
  (`parse_version`/`compare_versions`), the parsers for GitHub's
  `releases/latest` redirect and the proxy's `X-Cpa-Version` header,
  `running_identity` (who holds the managed port), the update decision table
  (`update_refusal`, `plan_update`), and the status text (`version_summary`).
  Unit-tested, no mocks.
- **`cliproxy.lua`** (IO): `discover_binary` (`cliproxy.binary_path` → parley's
  managed download → `cliproxyapi`/`cli-proxy-api` on PATH), `health_probe`
  (`GET /v1/models` with the bearer →
  `healthy`/`needs_login`/`client_key_mismatch`/`foreign`/`down`),
  `version_probe` (#237: the running version from `X-Cpa-Version`, no
  credential), `spawn` (detached, PID-tracked), `ensure_running`
  (reuse-if-healthy → else discover/spawn/poll, bounded — never hangs),
  `list_models` (#132), the release IO (`latest_release`, `resolve_target`,
  `download`, `installed_version`, `update` — see Releases), and
  `status`/`start`/`stop`/`restart_managed`/`login_argv`. The curl argv is built
  once in `api_argv` (route-parameterized since #197; `dump_headers` since #237)
  and shared by `health_probe`, the stop-time identity check, `list_models`, the
  management read and `version_probe` (ARCH-DRY). Tested against process-level
  fakes.
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
a process that actually answers as cliproxy. `:ParleyProxy restart` is
`restart_managed`: `stop`, wait (≤2 s) for the old proxy to release the port,
then ensure — without the wait a proxy still shutting down could be reused
(#237). A cliproxyapi still answering when the wait ends is reported as an
error, never taken for the replacement.

## Model catalog (#205)

Three modules, split by what they touch: **`cliproxy_catalog.lua`** is the pure
core (parse the two model routes, derive a model's series, rank it, apply the
operator's filters, build the agent a picked row implies) and is unit-tested
against fixtures captured from a real proxy with no mocks;
**`cliproxy.lua`** is the IO shell that fetches and caches it; and
**`cliproxy_config.lua`** owns the channel relations the diagnosis path needs.


cliproxyapi advertises what it serves, and that set moves without warning — an
antigravity login registered 13 new models mid-session with no restart. Parley
reads that catalog instead of carrying model names in Lua.

- **Two routes, joined on id.** `/v1/models` carries `created` (the recency
  signal); `/v1beta/models` carries `displayName` + `description`. Neither is
  sufficient: for antigravity the display name is the only truthful naming, since
  its ids are opaque handles (`gemini-pro-agent` is "Gemini 3.1 Pro (High)").
- **`catalog.json`** — a derived artifact beside `config.yaml` under
  `stdpath('data')/parley/cliproxy/`, written `0600`. The picker renders from it
  synchronously, so a cold start is instant and a dead proxy still lists models.
  Refreshed on picker open when older than 10 minutes — but that cadence has two
  escape hatches, because a plain TTL is wrong in both directions. A FAILED
  attempt backs off only ~30s (keying failures on the 10-minute clock silenced
  the picker while the proxy came back), and a completed login INVALIDATES the
  cache outright: a login is what registers a channel's models, and a
  `(logged out)` row exists precisely because a successful fetch lacked them — so
  the cache is fresh, and without the invalidation the operator kept seeing the
  row they had just logged in through.
- **The catalog does not depend on `manage`.** `cliproxy.manage = false` means
  parley will not START a proxy, not that there is no proxy — a bring-your-own
  instance answers the same GET. The refresh therefore runs either way; gating it
  on `manage` left those operators with an empty catalog and a picker claiming
  every configured provider was logged out.
- **Any dispatch warms it, not just the picker.** The adapter's `pre_query` hook
  kicks a stale-gated refresh — the one seam EVERY cliproxy request passes
  through, managed or bring-your-own — so a machine that has never opened an
  agent picker still has a catalog — which matters because the catalog is what resolves
  model→channel for auth diagnosis. Its only writer used to be the picker, so a
  cold install reported "no cliproxy channel is configured" with no account and
  no login offered: worse than the `oauth-model-alias` block it replaced. Warming
  inside `ensure_running` is NOT enough — `pre_query` returns before it when
  `manage = false`, so the bring-your-own operator never reached it.
- **`fetch_catalog` never spawns the proxy.** It is a plain GET; a
  connection-refused is a no-op that leaves the cache in place. Opening a picker
  must not start a daemon — that is the dormancy contract from #131, pinned by a
  test that points at a free port and asserts it stays free.
- **`cliproxy.live_models`** — `{ providers = { "claude:opus,sonnet,fable", … },
  per_provider = 3 }`. An entry is `"<provider>[:<term>,…]"`; terms are
  case-insensitive substrings matched against the id **and** the display name
  (required, not cosmetic: antigravity's ids are unfilterable otherwise). Terms
  narrow, then the newest of each model line is kept, capped at `per_provider`.
  Term order is display order. It names providers and families, never versions,
  so it does not go stale.
- **No `oauth-model-alias` is required (#205).** cliproxyapi exposes an OAuth
  channel's models automatically once that channel has a credential — verified
  against a live proxy: models absent from any alias block answer normally, and a
  login registers its channel's models with no restart. The block parley used to
  ship claimed routing needed it (true of 7.1.71, not since) and went stale the
  moment a new model appeared. It is still HONORED as an explicit channel PIN,
  which is the one thing the catalog cannot decide: antigravity re-serves claude,
  gemini and gpt-oss models alongside their native channels, so pinning is how you
  say which channel should serve a given id.
- **Model → channel now resolves from the catalog**, and where several channels
  could serve one id, CREDENTIAL HEALTH picks between them — **eligibility first,
  ranking second**. A channel holding NO credential cannot have served the
  request, so it is not a candidate at all; among those that could have, the
  likeliest culprit is named. Getting that order wrong inverts the answer, because
  `missing` ranks worst: an "unhealthiest wins" reducer names the channel you
  have never logged into and leaves the credential that actually failed unnamed. A pin still wins over both. If nothing resolves, parley says so
  rather than naming an account at random.
- **`owned_by` is a display grouping, not a channel.** The same id was reported
  under `anthropic` on one proxy start and `antigravity` on the next, so nothing
  durable keys off it — in particular the wire is chosen by model FAMILY, never
  by owner.
- **The strategy is CORRECTED, not restated.** An agent need not carry
  `web_search_strategy`: the resolution chain is agent override → a provider-level
  `none` (a global off switch) → a correction when the configured strategy is one
  the family cannot use → the provider default → none. It corrects and never
  invents, so an unconfigured setup still resolves to `none`. **Behaviour change
  (#205):** a claude model under the shipped `openai_tools_route` default now
  takes the ANTHROPIC route by default, because measurement showed claude returns
  an empty completion on the openai route with web_search on. Set
  `web_search_strategy` on the agent to override.
- **Server-side web search differs per family** (measured 2026-08-31): claude
  needs the anthropic route; gpt/codex works on `openai_tools_route`; gemini and
  anything antigravity re-serves gets `none`, because `{type="web_search"}` makes
  gemini answer `malformed_function_call` with no content. The decision is
  single-sourced in `providers.cliproxy_default_web_search_strategy`.

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
  `retry()`/`give_up(msg)`, both behind one `tasker.once`. A
  `recovery_timeout_ms` backstop degrades a hung recovery to today's behavior
  rather than stranding the chat leg.

cliproxy claims only when: a verdict exists, `attempt == 0`, and nothing has
streamed (`failure.streamed`) — a retry after partial content would duplicate
text. `failure.model` carries `payload.model`, the only path by which the
expired-token 401 (which names neither provider nor model) resolves to a channel
via `channel_login on a resolved channel`.

### The recovery ladder

`cliproxy_auth.decide(verdict, health, proxy_state, attempt, login)` is the whole
policy, pure and table-tested: one action out of `start` | `restart` | `retry` |
`prompt_login` | `report`. `recover` gathers the inputs (liveness probe and
credential health — staleness lives entirely inside the record) and executes exactly one action, settling
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
arithmetic. The compound case (a 404 repair followed by a `restart` decision) is made
unreachable by a **per-claim** latch — module state cannot serve here, because
the repair clears its own flag before the decision is computed — and
`cliproxy_budget_spec` asserts the compound arithmetic so the claim stays
checkable.

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
2. **surfaces the binary's own output** (debounced, so the whole instruction
   block arrives together) — deliberately WITHOUT `-no-browser`: each provider's
   flow differs, and suppressing the binary's browser while matching only a
   claude-shaped URL left every other provider with a silent, uncompletable
   login. Parley adds visibility; it does not take over the flow;
3. keeps the job **off a closable terminal buffer** — in #197 the terminal-split
   job died mid-flow, taking its callback listener with it, and the browser's
   redirect had nowhere to land while nothing reported the death;
4. **watches the auth-dir** (filtered to the login's own channels, so a peer
   proxy's refresh cannot satisfy it) and reports the real outcome exactly once:
   success with the account, a non-zero exit with the binary's output, or a
   bounded timeout telling the operator to re-run.

It does **not** resume the query that triggered the prompt. A login takes minutes
and the recovery claim is bounded by `recovery_timeout_ms`; holding a chat leg
open across it would guarantee the timeout it exists to avoid. The claim settles
with the diagnosis, and the operator re-sends once the login lands.

`login_argv` validates the flag against `<binary> -h` rather than a static table:
the flag set is version-dependent (7.2.110 dropped `-login`, which 7.1.71 had),
so `:ParleyProxy login google` on a newer build now says so instead of silently
not logging in.

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

## Releases: auto_download and update (#131 M2, #237)

**One target rule.** `:ParleyProxy update` and the first-run `auto_download`
(`cliproxy = { manage = true, auto_download = true }`, which removes the
`brew install` step) both install `cliproxy.download_version` when it is set
(the pin), else the **latest** release. There is no pin in code. CLIProxyAPI
presents itself to Anthropic as a Claude Code version, and Anthropic refuses
newer models to builds below a minimum: the old built-in 7.1.71 (Claude Code
2.1.63) could not reach Fable. `resolve_target` applies the rule;
`latest_release` reads GitHub's `releases/latest` redirect
(`curl -w %{redirect_url}`: no API token, no quota), and
`cliproxy_release.parse_latest_response` turns it into `X.Y.Z` or an error. If
the latest cannot be resolved, update fails and suggests `download_version`.

**Install.** `download({ version })` builds the asset URL only from a parsed
version (`cliproxy_config.platform` + `asset_name`), curls the tarball and
`checksums.txt`, **sha256-verifies (refuses on mismatch)**, extracts
`cli-proxy-api` into `<data root>/staging`, and **renames** it over
`stdpath('data')/parley/cliproxy/bin/cli-proxy-api` — so a running proxy keeps
its old file and an interrupted install leaves the previous binary. It then
records the version in `cli-proxy-api.version`; `installed_version` reads it
back and treats a missing or garbled record as unknown. The fetch is
synchronous (it blocks the editor, bounded by curl's timeouts). Windows (`.zip`)
is not auto-downloaded — install manually.

**Update** (`:ParleyProxy update`, `M.update(cb)`). It refuses first when
`cliproxy.manage` is off or `binary_path` is set, since parley would not run
what it installs. It then resolves the target, reads the running version
(`version_probe`) and who holds the port, and lets
`cliproxy_release.plan_update` decide what to install and whether to restart.
**Parley restarts only its own proxy**: the listener is "ours" when its command
line carries parley's rendered `-config <config.yaml>`, from any nvim session,
read with `ps` through the same grammar as `peers()` (`cliproxy_auth.parse_ps`).
A proxy parley did not launch (a brew service, say) is left running, and the
message says how to replace it, shown as a warning since the old version still
serves; a port holder that reports no version is not assumed to be a
cliproxyapi. **Every claim in the message comes from an observation.** If `ps`
or `lsof` cannot be read, or the listener is missing from the process table,
update says it could not tell who started the proxy, names the reason, and
leaves it running. The restart goes through `restart_managed` behind a 20 s
deadline, and an in-flight guard refuses a second update until the first has
answered. Once the restart answers, one `version_probe` confirms what the port
serves: "updated 7.1.71 → 7.2.158 — restarting the proxy; now serving 7.2.158",
or a warning that it still reports the old version, or that it could not
confirm (`cliproxy_release.restart_outcome`). Other messages name the versions:
"already at 7.2.158", "… (pinned by cliproxy.download_version)".

**Testing.** `tests/fixtures/fake_github_releases` is a stateful fake of the
release endpoints (latest redirect, assets, checksums, and a request log) over a
directory the spec owns. `tests/helpers/fake_releases.lua` publishes releases
whose `cli-proxy-api` execs `fake_cliproxy` stamping that version, so "which
release is running" is observable end to end. Specs point lookups at the fake
with `_set_releases_url`; `tests/minimal_init.vim` points them at a dead local
port (`$PARLEY_CLIPROXY_RELEASES_URL`) so no spec reaches GitHub by accident;
parley reads that variable only under `$PARLEY_TEST_MODE`, which the harness
also exports. `PARLEY_FAKE_EXIT_DELAY_MS` keeps `fake_cliproxy` serving after
SIGTERM, as the real binary's graceful shutdown does, and `_set_process_tools`
names a missing `ps` or `lsof` to reproduce a machine without one.
`tests/fixtures/fixture_watchdog.py` makes a fixture exit when the nvim that
started it dies — always for the release fake, and for `fake_cliproxy` when
`PARLEY_FAKE_EXIT_WITH_PARENT=1` (#220 owns making that the default). The
identity cases run in every shell: where an agent sandbox refuses `ps`,
`tests/fixtures/fake_ps` prints the rows a real `ps` would (`PARLEY_FAKE_PS_ROWS`,
through `_set_process_tools`), and where `ps` works they read the real table.

### Versions and status

`:ParleyProxy status` prints a `version:` line, built by
`cliproxy_release.version_summary` from three reads that run in parallel and
answer once, when the last lands: health, the running version, and the latest
release. The `binary:` line names where the binary came from (`binary_path`,
`managed` for parley's download, or `PATH`).

- **Running version.** `version_probe` reads the `X-Cpa-Version` header from an
  unauthenticated `GET /v0/management/latest-version`. The proxy stamps it on a
  management response even when it answers 401, so no credential is sent. With
  remote management disabled it sends none, and the line says so rather than
  guessing. The conformance spec pins both against the real binary (7.1.71 and
  7.2.158, checked 2026-09-12).
- **Across releases.** 7.2.x stamps a credential's `updated_at` with its own
  load clock, where 7.1.71 copied the file's mtime. The staleness rung compares
  `modtime > updated_at + skew`, which reads both the same way.
- **Latest release.** The same `releases/latest` redirect that update uses,
  bounded at 5 s for status. When `cliproxy.manage` is off, status does not
  contact GitHub.
- **Forms.** `7.2.158 (latest)`; `7.1.71 (latest 7.2.158 — run :ParleyProxy
  update)`; `7.1.71 (pinned to 7.1.71; latest 7.2.158)`; `not running (installed
  7.2.158; latest 7.2.158)`; `unknown — the proxy sent no version header (…)`;
  `… (latest unknown: <why>)`.
- **Live checks.** `tests/integration/cliproxy_conformance_spec.lua` boots a
  real binary (parley's download, or one on `PATH`) to pin that the header
  exists and whether it survives with management disabled; the cases report
  `pending` when no binary is found. `PARLEY_LIVE_GITHUB=1` adds a check
  against the real redirect.
