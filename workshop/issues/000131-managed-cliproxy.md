---
id: 000131
status: working
deps: []
github_issue:
created: 2026-06-12
updated: 2026-06-12
estimate_hours: 16
---

# Manage cliproxyapi lifecycle + config

## Problem

Parley talks to `cliproxyapi` as a normal provider (`lua/parley/config.lua` →
`http://127.0.0.1:8317/v1/chat/completions`, dual OpenAI/Anthropic adapter in
`providers.lua`), but assumes the proxy is **already running and configured
out-of-band**. Today that means: `brew install`, `brew services start`, and
hand-editing config under `/opt/homebrew` — a path that can't live in the user's
version-controlled dotfiles (yadm). Setup friction + non-committable config +
manual lifecycle. Parley owns the client cleanly and owns *nothing* of the
proxy's binary / config / lifecycle. This issue closes that gap.

## Spec

Make parley able to **manage a cliproxyapi instance** — opt-in, off by default,
distributable to parley's general users (not just one machine).

### Decisions (brainstorm 2026-06-12)
- **Audience:** parley's general users → portable, no brew/Go assumption, no
  personal paths in core logic, **opt-in / off by default**.
- **Ownership:** orchestrator spine (config + lifecycle, bring-your-own-binary)
  as the M1 default; `auto_download` (parley fetches the binary) deferred to M2.
- **Config source of truth:** rendered from Lua `setup{}` — the generated
  `config.yaml` is a *derived, gitignored artifact*, so nothing hand-maintained
  ever lives in `/opt/homebrew` again. The committed Lua **is** the config.
- **Platforms:** macOS + Linux tested in v1; Windows written portably,
  best-effort, not gated on.

### Verified cliproxyapi facts (research 2026-06-12)
- `--config /path/to/config.yaml` flag → we can point it anywhere.
- Config holds `host`/`port` (default `8317`), `api-keys` (client tokens), and
  an `auth-dir` pointer (default `~/.cli-proxy-api`).
- **Clean secret split already exists:** static config in `config.yaml`
  (committable); OAuth subscription tokens are JSON files in `auth-dir`, written
  by `cli-proxy-api login`. Secrets never need to touch config or git.
- Prebuilt release tarballs for every platform:
  `CLIProxyAPI_<ver>_{darwin,linux,freebsd,windows}_{aarch64,amd64}.tar.gz` +
  `checksums.txt`. **Source builds are unnecessary** (kills brainstorm idea #1).
- `login` is interactive OAuth (`--no-browser` prints the URL) — the one
  unavoidable per-machine manual step.

### Activation & config model
Activated only when `setup{}` contains a `cliproxy = { manage = true, ... }`
block. Shape:
```lua
cliproxy = {
  manage = true,
  auth_dir = "~/.cli-proxy-api",  -- machine-local OAuth token dir
  binary_path = nil,              -- optional explicit path (else PATH lookup)
  config = { ... },               -- raw passthrough of cliproxy's own schema (ARCH-DRY: don't re-model it)
}
```
Parley merges its wiring fields **over** the raw `config` table, then writes the
result to a derived path *outside the user's dotfiles repo*
(`stdpath('data')/parley/cliproxy/config.yaml`, perms `0600`) on each
ensure-start, and spawns `cli-proxy-api --config <that path>`.

### host:port — single source of truth (resolves the double-source risk)
The existing `providers.cliproxyapi.endpoint` (`config.lua`,
`http://127.0.0.1:8317/v1/chat/completions`) already says *where the client
dials*. That endpoint is **the** source of truth: parley **parses host:port out
of the provider endpoint** and renders those into the proxy config's `host`/
`port` (and uses them for the health probe). There is deliberately **no
`cliproxy.port` field** — a second port knob is exactly the drift the reviewer
flagged. If the raw `config` passthrough also sets `host`/`port`, the
endpoint-derived values win and parley logs a warning naming both. Net: change
the port in one place (the provider endpoint) and client + proxy stay aligned.
*M1 note:* decide bind-vs-dial host explicitly — the client dials `127.0.0.1`
but the proxy may need `host: localhost`/`0.0.0.0` to bind; don't render the dial
host blindly as the bind host.

**Emission:** JSON is valid YAML 1.2 and parley already has `vim.json.encode`,
so it writes JSON-as-`.yaml` and needs no YAML emitter. **This bet is an early
gating task in M1** (write a render, feed it to a real `cli-proxy-api --config`,
confirm it boots) — go/no-go *before* the lifecycle work, so a failure can't
silently balloon M1. If it fails, the fallback emitter must handle **nested maps
+ lists** (the config has an `api-keys` list and nested sections) — a flat
emitter is not a viable fallback; budget it as its own M1 sub-task if triggered.

### Secret & auth-dir wiring (must NOT leak)
- **Client token:** the `cliproxyapi` secret can be a plaintext string, an env
  var, **or a command table** (`{ "cat", "/path" }`, keychain lookup, …) per
  `config.lua`. Parley resolves it through the **existing vault**
  (`vault.get_secret`, already populated at setup — ARCH-DRY, don't re-read
  `api_keys`) and injects the *resolved* value into the rendered config's
  `api-keys` list — single source; proxy and client can't drift.
- **Plaintext-on-disk, acknowledged:** the rendered `config.yaml` therefore
  contains the resolved client token in cleartext under `stdpath('data')`. That
  is why the file is written `0600`. This is a real (small) exposure the spec
  owns explicitly rather than hides. The *committed Lua* still holds zero
  secrets — the on-disk artifact is machine-local and unversioned.
- **OAuth tokens:** stay in `auth_dir` (machine-local JSON), never rendered into
  config, never committed.

### Binary discovery (M1, bring-your-own)
Order: `cliproxy.binary_path` → managed download dir (M2) → `cli-proxy-api` on
PATH. None found → actionable error naming `brew install …` / `auto_download`.

### Lifecycle
- **Lazy:** ensure-running fires on dispatch to a cliproxy-provider agent, never
  on nvim launch.
- **Ensure-on-every-use (auto-revive):** ensure-running runs on **every** such
  dispatch, not once-per-session — it's just a cheap health probe. So if the
  proxy died, crashed, or was explicitly stopped, the next dependent request
  transparently re-spawns it. There is **no persistent "disabled" state**.
- **`stop` is transient:** `:ParleyProxy stop` means "kill it now" (free the
  port / force a fresh config render); it is **not** a suppress flag — the next
  cliproxy-provider call revives it. (To actually stop using the proxy, switch
  off `manage` or stop using cliproxy-provider agents.)
- **Reuse-if-healthy:** probe the endpoint's host:port first; spawn only if
  nothing healthy answers (cooperative with an existing brew service / other
  nvim).
- **Detached & shared:** spawned via `vim.uv` detached so it outlives nvim and
  is shared across instances. Never auto-killed; stopped only explicitly.

### Health probe & failure modes (the dispatch path must never hang)
The probe must **identify cliproxy specifically**, not just accept any TCP
listener — hit a cliproxy-distinguishing HTTP route (e.g. its models endpoint),
so a foreign server squatting the port isn't mistaken for ours.
- **Spawn fails** (missing/!exec/wrong-arch binary, immediate exit): surface a
  clear error on the dispatch path and **fail the request** — never hang the
  chat — pointing at `:ParleyProxy status`.
- **Foreign process on the port:** probe fails the cliproxy-identity check →
  error "port N held by a non-cliproxy process" (don't spawn a doomed second
  instance, don't silently dial the stranger).
- **Spawned but never healthy:** bounded wait (~5s, a few retries); on timeout,
  abort with an error and leave the (logged) process for `:ParleyProxy status`
  to report — the dispatch does not block indefinitely.
- **Healthy but unauthenticated (login not done → 401 storm):** this is the
  *most likely* first-run state. Lifecycle is parley's job; OAuth is the manual
  step. `status` reports **auth state** (probe returns 401 / `auth_dir` empty),
  and the not-yet-logged-in error tells the user to run `:ParleyProxy login`.

### Module boundary (ARCH-PURE)
Two units, tested independently:
- `cliproxy_config.lua` — **pure**: merge raw `config` with wiring fields, parse
  host:port from the endpoint, inject the resolved secret, emit JSON-as-YAML,
  map platform→asset name (M2). No IO. Colocated unit tests.
- `cliproxy.lua` — **IO**: binary discovery, `vim.uv` spawn, health probe,
  reuse logic, the `:ParleyProxy` commands. Tested against a process-level fake
  proxy binary. Resolves the secret via the existing vault; writes the file.

### Commands
`:ParleyProxy status | start | stop | restart | login`. `login` wraps
`cli-proxy-api login [--no-browser]`. `status` reports binary source,
running/healthy, **auth state**, host:port, auth-dir, rendered-config path, and
flags **"running config differs from rendered"** so the user knows a `restart`
is needed after a Lua change. `stop`/`restart` are **best-effort by port/PID**;
since the daemon is shared, other nvim instances simply re-spawn lazily on their
next request. *M1 note:* `stop` should only stop a daemon **parley spawned**
(track our PID); a reused/foreign daemon (brew service) is left alone.

### M2 — auto_download (deferred)
`auto_download = true` → fetch the **pinned** (not "latest") release tarball for
detected os/arch, verify against `checksums.txt`, extract into the managed dir.
Adds `:ParleyProxy update`; binary-discovery falls through to the managed dir.

### Explicitly OUT (YAGNI)
Management-center/GUI integration; multi-proxy orchestration; auto-restart on
config change (Lua change needs explicit `:ParleyProxy restart`); managing the
OAuth flow beyond shelling out to `login`.

## Done when

Parley-verifiable (no manual login needed):
- `cliproxy = { manage = true, ... }` is opt-in; absent → zero behavior change,
  no spawn on nvim launch.
- A cliproxy-provider chat with no proxy running lazily renders config from Lua,
  starts the binary, the proxy becomes healthy, and the request reaches it.
- A healthy proxy already on the port (e.g. brew service) is reused, not
  re-spawned; a foreign process on the port produces the identity-check error,
  not a silent mis-dial.
- Spawn failure / never-healthy each surface an error on the dispatch path
  within the bounded timeout — the chat never hangs.
- After the proxy dies or is `:ParleyProxy stop`'d, the **next**
  cliproxy-provider dispatch transparently re-spawns it (no persistent disabled
  state; no manual `start` required).
- Rendered `config.yaml` carries the *resolved* `cliproxyapi` secret in
  `api-keys` at perms `0600`; no secret appears in any committed file; the port
  in the rendered config matches the provider endpoint.
- `:ParleyProxy status` reports binary source, healthy/auth state, host:port,
  and config-drift accurately.

Requires manual one-time login (documented as such):
- Post-`:ParleyProxy login`, a real cliproxy-provider completion returns
  end-to-end.

Platform:
- The above pass on macOS + Linux.

## Plan

- [x] M1 — orchestrator spine (macOS + Linux). Gating task FIRST: prove
      JSON-as-YAML boots a real `cli-proxy-api --config` (go/no-go before the
      rest). Then: pure `cliproxy_config.lua` (merge, parse host:port from
      endpoint, vault-resolved secret injection, JSON-as-YAML emit) +
      colocated unit tests; IO `cliproxy.lua` (binary discovery, `vim.uv`
      detached spawn, cliproxy-identifying health probe with bounded timeout,
      reuse-if-healthy, `:ParleyProxy status|start|stop|restart|login`) tested
      against a process-level fake proxy binary (per AGENTS.md external-service
      rule). Failure modes (spawn-fail, foreign-port, never-healthy, 401/auth)
      each covered.
- [x] M2 — `auto_download`: platform→asset-name mapping (pure, with its
      consumer here — not M1), pinned cross-platform release fetch + checksum
      verify + extract; `:ParleyProxy update`; discovery falls through to managed
      dir.
- [x] M3 — auth-failure → guided login. On a cliproxy response that fails for a
      missing/invalid upstream credential (cliproxyapi collapses this to
      `"unknown provider for model <X>"` — verified against the source:
      `util.GetProviderName` only reads the *dynamic* registry, so an unloaded
      auth makes the model unresolvable), detect it and resolve which login the
      model needs **from parley's own `oauth-model-alias` config** (NOT name
      inference): find the channel whose model list contains `<X>` → map channel
      → login flag over cliproxyapi's fixed channel set (claude/codex/gemini-cli/
      vertex/aistudio/kimi/antigravity). Then prompt-and-confirm
      `:ParleyProxy login <provider>`. Also: re-key the default oauth-model-alias
      to the canonical `claude` channel (verified to serve the whole family), so
      the config key == the provider. Pure resolution functions in
      `cliproxy_config` (unit-tested); detection wired at the dispatcher's
      cliproxy response path.

## Log


- 2026-06-14: closed M3 — measured increment = total 11.51h - (M1 2.74 + M2 1.29) (sdlc actual cannot scope per-milestone; this window had heavy interactive debugging + reading the CLIProxyAPI Go source). make test exit 0 (JOBS=4): 97 spec files, luacheck 0/0 across 185. M3: cliproxy_config detect_auth_failure + resolve_login_provider 9 unit tests; cliproxy_auth_login 4 integration (prompt-on-failure / no-op-success / no-op-non-cliproxy / canonical-channel resolution). Resolution is CONFIG-DRIVEN (oauth-model-alias channel key == provider), NOT name inference — verified against the CLIProxyAPI source (dynamic registry drops models at auth-error time; static catalog keyed by canonical channels claude/codex/gemini-cli/...). Re-keyed default to canonical `claude` channel, verified it serves the whole family against real 7.1.71. Window also covers post-M2 side-quests: stop-reaps-by-port (2 tests), oauth-model-alias default (verified e2e), and two topic-gen fixes (system-prompt leak into the title, incl the synthetic leading-user-turn form).; review verdict: FIX-THEN-SHIP
### 2026-06-12
- 2026-06-12: closed M2 — measured increment = total 4.03h - M1 2.74h (sdlc actual cannot scope per-milestone). make test exit 0: 95 spec files, luacheck 0/0 across 183. M2: cliproxy_config platform/asset_name/parse_checksums 9 unit (injectable uname, deterministic); cliproxy_download 3 integration (fixture release over local HTTP, no network: download→sha256-verify→extract + tampered-checksum REFUSAL); discover_binary managed-dir fall-through; ensure_running auto_download trigger (opt-in); :ParleyProxy update. Grounded on real release v7.1.71 (asset naming aarch64, "<sha>  <name>" checksums, tarball roots cli-proxy-api).; review verdict: FIX-THEN-SHIP
- **M2 FIX-THEN-SHIP resolved (no Critical; 2 Important + minors).** (1) Added the
  missing test for the `ensure_running` auto_download *trigger* (auto_download=true
  + nothing found → download() called → spawn proceeds; unset → not called → "no
  binary"). (2) Bounded the download curls (`--connect-timeout`/`--max-time`) so a
  stalled synchronous fetch can't freeze the editor. Minors: `BIN_NAME` const;
  `os.remove(tmp)` on the download-failure path; FreeBSD-best-effort comment.
  Re-verified after `make test-clean-env`: make test exit 0 — 95 spec files,
  luacheck 0/0 across 183 (a transient chat_dirs failure was test-env pollution
  from manual single-file runs, not a regression).
- 2026-06-12: closed M1 — make test exit 0: 93 spec files pass, luacheck 0/0 across 181 files. New: cliproxy_config 13 unit (pure, no mocks), cliproxy_lifecycle 22 integration (process-level fake: discover/probe/spawn/ensure_running full failure matrix, never hangs), cliproxy_dispatch 3 e2e (real pre_query→ensure_running→on_abort chain: foreign aborts fast/healthy proceeds/transient-stop revive), cliproxy_command 3, dispatcher Group H abort channel, providers_pre_query 3. Task 2.0 gating validated against real cliproxyapi v7.1.60 (JSON-as-YAML boots; /v1/models identity route; 401 vs 200-empty semantics).; review verdict: FIX-THEN-SHIP
- **FIX-THEN-SHIP resolved (no Critical; 4 Important + minors fixed).**
  (1) ARCH-DRY: extracted `cliproxy.render_opts()` (write/drift/status share it);
  (2) ARCH-DRY: `cliproxy.login_providers()` is the single source for completion
  + validation. (3) Per-caller on_abort teardowns now tested for real —
  `cliproxy_caller_teardown_spec`: memory_prefs via the real abort chain
  (process_next keeps the batch moving), chat_respond + skill_runner via a
  D.query mock invoking the real on_abort (block-collapse on the default path /
  `_in_flight` clear), exposed `skill_runner.is_in_flight`. (4) Added a 0600 +
  secret-in-`api-keys`-on-disk assertion. Minors: `login_argv` renders config
  first (honors custom auth_dir); `jobstart({term=true})` over deprecated
  termopen; doc note that `api_keys.cliproxyapi` is required even when managed.
  Recorded Python-fake + tests-at-close deviations in the plan `## Revisions`.
  Re-verified: **make test exit 0 — 94 spec files, luacheck 0/0 across 182.**
- Side-quest (user request): ship managed cliproxy **on by default** — `config.lua`
  now has an active `cliproxy = { manage = true, config = {disable-control-panel} }`,
  and `api_keys.cliproxyapi` defaults to `"parley-local"` (a loopback-only
  client↔proxy handshake token, not subscription auth) so a fresh machine works
  with zero env setup. Safe: dormant unless a cliproxyapi agent runs, and
  reuses an existing proxy. README + atlas updated to "on by default but dormant".
  make test still exit 0 (94 specs).
- **Live e2e validated by operator** (the last Done-when, "post-login real
  completion"): fresh nvim, brew service stopped → parley spawned its own
  cliproxyapi and a cliproxyapi-provider chat completed end-to-end. The
  real-subscription path the automated tests couldn't exercise now confirmed.

### 2026-06-12 (M2 — auto_download)
- M2 SHIPPED: pure `cliproxy_config.platform/asset_name/parse_checksums` (9 unit
  tests, injectable uname); `cliproxy.download()` resolves the pinned release
  (7.1.71) for the host platform, curls tarball + checksums.txt, **sha256-verifies
  (refuses on mismatch)**, extracts `cli-proxy-api` into stdpath('data')/.../bin;
  `discover_binary` falls through binary_path → managed dir → PATH;
  `ensure_running` auto-downloads (one-time, notify) when `auto_download` is set;
  `:ParleyProxy update` re-fetches. Integration test serves a fixture release over
  local HTTP (no network) — download/extract + tampered-checksum refusal (3 tests).
  Grounded on the real release (asset naming `aarch64`, `<sha>  <name>` checksums,
  tarball roots `cli-proxy-api`). `auto_download` kept **opt-in** (auto-fetching a
  binary is an explicit choice; brainstorm's "A is opt-in").
- Full suite: **make test exit 0 — 95 spec files, luacheck 0/0 across 183.**

### 2026-06-12 (follow-up — stop reaps by port)
- Operator hit the detached-proxy rough edge: a leftover cliproxy parley spawned
  in an earlier session (brew 7.1.60 on :8317) was reused by reuse-if-healthy, so
  a no-binary auto_download test never fired the download (correct, but the
  leftover was unreachable — `:ParleyProxy stop` was session-scoped). Fixed:
  `stop` now reaps a leftover cliproxy on the managed port across sessions
  (lsof → kill), but **identity-probes the port first** (same `/v1/models`
  classifier), so a foreign process is never killed. `restart` inherits it.
  2 integration tests (reap-leftover, don't-kill-foreign). make test exit 0 — 95
  spec files, luacheck 0/0.

### 2026-06-13 (M3 — auth-failure → guided login)
- Read the cliproxyapi Go source (../CLIProxyAPI): it keeps the model→provider
  map in a STATIC catalog (`model_definitions.go` + embedded models.json) keyed
  by canonical channels (claude/codex/gemini-cli/vertex/aistudio/kimi/antigravity)
  and exposes it auth-independently via the management API
  (`/v0/management/model-definitions/:channel`, `/oauth-model-alias`, `/config`).
  But `/v1/models` + the "unknown provider" error read the DYNAMIC registry
  (loaded auth only) — so the model vanishes at error time. Conclusion: resolve
  from parley's OWN `oauth-model-alias` config (the channel key == provider), no
  name inference. Verified the canonical `claude` channel key serves the whole
  family.
- M3 SHIPPED: pure `cliproxy_config.detect_auth_failure` (pulls the model from
  the error) + `resolve_login_provider` (channel→login over the fixed channel
  set) with 9 unit tests; IO `cliproxy.check_auth_failure` (detect → resolve →
  `vim.ui.select` prompt → `:ParleyProxy login <provider>`, throttled) wired at
  the dispatcher's cliproxy response path; 4 integration tests. Re-keyed the
  default oauth-model-alias to the canonical `claude` channel. make test exit 0:
  97 spec files, luacheck 0/0 across 185.
- **M3 FIX-THEN-SHIP resolved (no Critical).** (1) **Test-isolation bug (also hit
  the operator live):** `config_path()`/`bin_dir()` used `stdpath('data')`
  unconditionally, so a bare `PlenaryBustedFile` run (no XDG redirect) wrote to
  the real `~/.local/share/nvim/parley/cliproxy/` — it had clobbered the
  operator's rendered config with a test `testkey`/ephemeral-port, then a proxy
  spawned from it rejected the real bearer (`client_key_mismatch`). Fix: a
  `data_root()` with a `cliproxy._set_data_dir` test seam; every cliproxy spec
  redirects to a temp dir at load. Verified a BARE lifecycle run is now 28/0 AND
  leaves the real dir untouched. (2) Added the untested `check_auth_failure`
  no-login-resolved WARN branch test (model absent from the alias → notify, no
  prompt). (3) `auto_download = true` is the operator's intentional default —
  kept on, fixed the now-false "off by default" comment to note it's a trust
  decision a general distribution may revert. **Revision:** auto_download default
  off→on is the operator's choice for this config (Spec's stated default is
  opt-in). make test exit 0: 97 spec files, luacheck 0/0 across 185.

### 2026-06-13 (follow-up — oauth-model-alias default)
- After auto_download spawned a clean 7.1.71, a cliproxy chat failed with
  "unknown provider for model claude-opus-4-8": the minimal rendered config had
  no provider/model routing. Root cause (operator-diagnosed): the brew conf's
  `oauth-model-alias` block maps model NAMES → the Claude OAuth credential
  (`fork: true`); the auth-dir token alone isn't enough. Per operator direction
  ("use parley's config to control cliproxyapi as a wrapped dependency"), baked a
  default `oauth-model-alias` into `config.lua` `cliproxy.config` for the models
  parley's cliproxyapi agents use (claude-sonnet-4-6 / claude-opus-4-8 /
  claude-fable-5). **Verified end-to-end**: rendered via the real module, booted
  the downloaded 7.1.71 against the real auth-dir → `/v1/models` now lists
  claude-opus-4-8 (+ the family). Added a unit test that the nested map+list
  passthrough survives JSON-as-YAML round-trip. make test exit 0 — 95 specs,
  luacheck 0/0. (Confirmed the chat_dirs failures were a parallel-runner load
  flake — isolated + JOBS=4 runs are green.)
- Brainstormed via superpowers-brainstorming. Converged design captured in
  `## Spec`. Five decisions logged inline (audience, ownership, config source,
  auto_download deferral, platform scope). cliproxyapi CLI/release facts
  verified against help.router-for.me + GitHub releases API (latest v7.1.68).
- Idea "build cliproxyapi from source" rejected: prebuilt tarballs exist for all
  platforms; source build would force a Go toolchain on every machine for no
  gain.
- Fresh-eyes spec review (subagent) found 2 blockers + arch gap; spec revised:
  (1) **host:port single source of truth** — dropped `cliproxy.port`, parse it
  from the provider endpoint (kills the double-source drift). (2) **secret
  resolution** — resolve via existing vault (handles command-table/env forms),
  acknowledge plaintext-on-disk at `0600`. (3) **lifecycle failure modes** —
  added health-identity probe, spawn-fail / foreign-port / never-healthy bounded
  timeout / 401-auth handling; dispatch never hangs. (4) **module boundary** —
  pure `cliproxy_config.lua` vs IO `cliproxy.lua`. (5) JSON-as-YAML made an early
  M1 go/no-go gating task; platform→asset mapping moved to M2 (its consumer);
  Done-when split into parley-verifiable vs post-login.
- Clarified (user): `:ParleyProxy stop` is **transient**, not a disabled state.
  Ensure-running runs on *every* cliproxy dispatch (cheap health probe), so a
  dead/stopped/crashed proxy auto-revives on the next dependent request — no
  manual restart. Already implied by lazy + reuse-if-healthy; now stated
  explicitly in Lifecycle + Done-when.
- Claimed (est 16h) → working. `start-plan`: ARCH-DRY + ARCH-PURE delivered;
  both already shaped the design (reuse `pre_query`/`vault`; pure config core vs
  IO shell). Implementation plan written to
  `workshop/plans/000131-managed-cliproxy-plan.md` via superpowers-writing-plans.
  Fresh-eyes plan review found 2 real issues — a dead line in `parse_endpoint`
  and `make test-spec SPEC=` being a traceability key (not a filename, would
  no-op the TDD loop) — both fixed; reviewer confirmed the `pre_query` abort path
  genuinely can't hang the chat (D.query only runs the query inside the
  callback) and that `vault.get_secret` is resolved by `run_with_secret` before
  `pre_query` fires.
- Branch hygiene: #131 spec commits were relocated off the in-flight #128 branch
  onto a fresh `000131-managed-cliproxy` branch based on `main`; #128 restored.
- `change-code` plan-quality gate FAILED (correctly): the planned abort path
  (pre_query not calling its callback) returns from `D.query` cleanly but leaves
  the caller's spinner — started in `chat_respond.lua` *before* `D.query`, torn
  down only in the qid-coupled `on_exit` — running forever, so the chat hangs
  from the user's view (violates "dispatch must never hang"). Both prior reviews
  missed it (they stopped at `D.query`, not the caller). Plan revised: add an
  **abort channel** — `pre_query(on_success, on_error)` + a trailing `on_abort`
  on `D.query`; on pre_query error the dispatcher calls `on_abort`, and
  `chat_respond` passes a qid-free `on_abort` that stops the spinner + clears the
  indicator + `vim.notify`s the actionable error. New Task 3.0 (dispatcher) +
  3.2 (chat_respond teardown) + a spinner-stopped test (Task 3.2/3.4). Also
  folded: 401-semantics decision into the Task 2.0 gating check; secret name via
  `providers.get_secret_name` not a literal (ARCH-DRY). Contract is additive —
  copilot's one-arg `pre_query` ignores the new arg.
- `change-code` round 2 FAILED (correctly), two more real gaps: (1) the abort
  channel was wired at only 2 of **4** `D.query` callers — `skill_runner.lua`
  (leaks `_in_flight[buf]=true` → that buffer's skill runs blocked forever) and
  `memory_prefs.lua` (batch stalls) also route through cliproxy. (2) The
  main-path teardown/test was spinner-scoped, but the spinner is
  web-search-gated — off the default path nothing spins; the real leftover is
  the inserted `agent_header`/`stream_placeholder` blocks, and the "spinner
  stopped" test passes vacuously. Fixed: wire `on_abort` at all 4 callers
  (per-caller teardown); extract a shared `collapse_empty_answer` helper reused
  by `on_exit` + `on_abort` (ARCH-DRY); test asserts blocks removed on the
  *default* path. Minor folds: port-less-endpoint caveat; read merged config via
  `require("parley").config.cliproxy`, not the module's `M`.

### 2026-06-12 (build)
- Chunk 1 SHIPPED: `lua/parley/cliproxy_config.lua` (parse_endpoint/render/encode),
  13 unit tests green, luacheck clean, traceability key `providers/cliproxy-managed`
  registered. Commit e98a432.
- **Task 2.0 gating check → GO.** Rendered a config via the real `cliproxy_config`
  module (JSON written to `.yaml`) and booted the installed `cliproxyapi`
  (v7.1.60) on a throwaway port 8319: **it boots cleanly from JSON-as-YAML — the
  bet holds, no fallback YAML emitter needed.** Decisions:
  - **Identity/health route = `/v1/models`** (no `/health` → 404). Probe WITH the
    client bearer.
  - **401 semantics (resolves plan-quality INFO):** with the *correct* bearer,
    `/v1/models` returns **200 `{"data":[],"object":"list"}`** even with NO
    upstream login. So: **401 = client-key drift** (wrong/absent `api-keys`);
    **200 + empty `data` = up but not logged in** (the "run login" signal);
    refused = down; 200 non-`{object:"list"}` = foreign.
  - **Binary name is `cliproxyapi`** (brew), NOT `cli-proxy-api`. `discover_binary`
    tries both.
  - **Config flag `-config`** (single dash; Go flag also accepts `--config`).
  - **Login = per-provider flags**, NOT a subcommand: `-claude-login`,
    `-codex-login`, `-codex-device-login`, `-login` (Google), `-kimi-login`,
    `-xai-login`, `-antigravity-login`, `-no-browser`. `:ParleyProxy login <provider>`
    → `-<provider>-login`.
  - `api-keys` (plural) confirmed; `host`/`port`/`auth-dir` as rendered; `~` ok.
  - Boot downloads a management control-panel asset from GitHub; docs should
    recommend `remote-management: { disable-control-panel: true }` in the user's
    `config` passthrough (avoids the network hit, faster lazy-spawn readiness).
- Chunk 2 SHIPPED: `cliproxy.lua` IO seam — discover_binary, health_probe
  (/v1/models classification), spawn (detached/PID-tracked), ensure_running
  (reuse → spawn → poll, full failure matrix, never hangs), status/stop/restart/
  login_argv. 22 integration tests vs the process-level fake. Commits 69e8f36,
  6178867.
- Chunk 3 SHIPPED: D.query abort channel + cliproxyapi.pre_query (reuses the
  copilot pre_query seam; additive, backward-compatible) [34b6248]; on_abort
  teardown at all 4 D.query callers with a shared `collapse_empty_answer` helper,
  + e2e spec driving the real chain (foreign aborts fast / healthy proceeds /
  cold-start + transient-stop revive) [86867a4]; `:ParleyProxy` command
  [#131 M1 commit]; docs + atlas [fd0a252].
- **Full suite green: `make test` exit 0 — 93 spec files pass, luacheck 0/0
  across 181 files.** No regressions in chat_respond/skill_runner/memory_prefs/
  dispatcher/init from the shared-surface changes.
