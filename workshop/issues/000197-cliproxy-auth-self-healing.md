---
id: 000197
status: working
deps: []
github_issue:
created: 2026-08-01
updated: 2026-08-01
estimate_hours: 9.2
started: 2026-08-01T00:24:22-07:00
---

# cliproxy auth failures must self-heal: detect, diagnose, recover

## Problem

On 2026-08-01 every cliproxyapi query failed and parley reported only:

```
Parley.nvim: cliproxyapi response is empty: body_bytes=215
parley: provider request failed (HTTP 503): {"type":"error","error":{"type":"api_error",
"message":"auth_unavailable: no auth available (providers=claude, model=claude-opus-4-8);
check Claude auth/key session and cooldown state via /v0/management/auth-files"}}
```

Parley has an auth-failure→guided-login path (#131 M3) and it did **not** fire.
Root causes, all verified against the live system:

1. **Detection is a single stale pattern.** `cliproxy_config.detect_auth_failure`
   (`cliproxy_config.lua:131`) matches only `"unknown provider for model <X>"`.
   The two messages 7.1.71 actually emitted — `auth_unavailable: no auth
   available (providers=…, model=…)` (503) and, on 2026-07-27, `OAuth access
   token has expired. Re-authenticate to continue.` (401) — match nothing.
   `check_auth_failure` ran (it sits at `dispatcher.lua:312`, four lines after
   the `response is empty` log that appeared) and no-op'd.
2. **The pre-flight health gate is blind to auth state.** `classify`
   (`cliproxy.lua:91`) calls 200 + non-empty `/v1/models` "healthy" and reserves
   `needs_login` for an *empty* list. Probed live with the credential dead:
   `/v1/models` still returned 31 models including the whole claude family. So
   `needs_login` is unreachable for expired auth and `ensure_running` greenlights
   every query. #131's recorded assumption ("the dynamic registry drops models at
   auth-error time") does not hold for this failure mode.
3. **No introspection channel.** The 503 names `/v0/management/auth-files`, but
   the rendered config carries no `remote-management.secret-key`, so that route
   404s. Parley cannot see expiry, cooldown, or failure counts.
4. **Root cause of the expiry itself: refresh-token rotation race.** Four
   leaked proxies from #131 verification (Jun 12–14, ports 8327/8331/8333/8335,
   configs long deleted) were still running against the shared default auth-dir.
   Each proxy runs `core auth auto-refresh (interval=15m0s)` and attempts a
   refresh at startup — verified in an isolated probe. Claude OAuth refresh
   tokens rotate on use, so N proxies over one auth-dir invalidate each other.
   The credential expired 2026-07-25T20:06 and never recovered.
   `cliproxy.stop()` (`cliproxy.lua:368`) reaps only this session's PIDs plus the
   managed port, which is how they survived seven weeks.
5. **The login flow dies silently.** `:ParleyProxy login claude` jobstarts into a
   terminal split (`init.lua:423`). Tonight that process exited mid-flow; its
   callback listener on `:54545` went with it, so the browser's redirect had
   nowhere to land and the account chooser appeared inert. Nothing reported the
   death.

## Spec

**Principle: stop inferring auth state, ask for it.** `/v0/management/auth-files`
is the source of truth; detection, diagnosis, and recovery all derive from it
(ARCH-PURPOSE — every consumer derives from one vocabulary, no parallel
regex-guessing left behind).

Verified contract (captured from 7.1.71 with a fabricated credential, so no real
token was touched): the route returns one record per credential with `provider`,
`account`/`email`, `status`, `status_message`, `unavailable`, `disabled`,
`failed`, `success`, `modtime`, `path`. Forcing an upstream failure flipped
`status` to `error` and carried the upstream error verbatim in `status_message`.
The route authenticates with the `remote-management.secret-key` bearer only — the
normal api-key gets 401. The proxy hot-reloads auth files (fsnotify /
`watcher.AuthUpdate`), so a fresh login needs no restart; restart is a fallback.

### Components

- **`lua/parley/cliproxy_auth.lua` — new, pure (ARCH-PURE).** No IO, no clock
  beyond an injected `now`. Three functions:
  - `classify_response(http_status, body)` → verdict `{kind, provider, model}`,
    driven by one pattern table built from the binary's real message templates
    (`auth_unavailable … (providers=%s, model=%s)`, `unknown provider for model
    %s`, `OAuth access token has expired`, `401 unauthorized`,
    `payment_required`, `model unavailable`). Replaces `detect_auth_failure`;
    that function's one caller migrates (ARCH-DRY — one detector, not two).
  - `classify_auth_files(files, provider)` → credential health from the
    management records.
  - `decide(verdict, health, proxy_state)` → an **action**
    (`start` | `restart` | `retry` | `prompt_login` | `report`) plus the message
    to show. The recovery *policy* is pure and unit-tested; the IO shell only
    executes the action it returns.
- **Management channel — `cliproxy.lua` + `cliproxy_config.lua`.** Render
  `remote-management.secret-key` (generated once, stored in the vault beside the
  client secret; config stays 0600; `allow-remote` unset ⇒ localhost-only). Add
  `M.auth_files(cb)` built on the same argv helper `models_argv` uses, extended
  to take a route + bearer (ARCH-DRY). A proxy started before the key existed is
  detected by the `no_management_route` 404 — a signal from the *running*
  process — and restarted into the fresh config (see Revisions: a file-vs-render
  drift check cannot work here).
- **Recovery ladder — `cliproxy.lua`.** One entry point consuming `decide`:
  proxy down → start; credential healthy but request failed → retry once; auth
  file newer than the proxy's `modtime` → restart, retry; `unavailable` /
  `disabled` / expired-with-failed-refresh → prompt **carrying the real
  `status_message` and expiry**, not "needs login". Prompting stays the only
  human-facing step (operator decision, this session).
- **One owning seam — `dispatcher.lua`.** Optional `adapter.recover_query(failure,
  retry)` beside the existing `pre_query`, placed in the terminal closure — the
  only scope holding HTTP status, body, and the request's model. The dispatcher
  owns the mechanism, cliproxy owns the policy. Exactly one retry, never a loop.
  `check_auth_failure` in `finish_stdout` is **deleted**, not kept beside it.
- **Prevention.** `M.peers()` enumerates `cli-proxy-api` processes parley did not
  spawn; warn once per session naming the rotation race, with `:ParleyProxy reap`
  to clean them. `stop()` stops leaking instances on non-managed ports.
- **Login robustness.** Preflight the callback port (`-oauth-callback-port` is
  the documented escape hatch), run `-no-browser` and capture the URL so parley
  opens it and keeps the job off a closable terminal buffer, watch the auth-dir
  for the written credential, then report success and resume.

### Testing (ARCH-MOCK)

The dependency surface is the `cli-proxy-api` binary: `/v1/models`,
`/v1/chat/completions` errors, `/v0/management/auth-files`, and the login argv.
A **stateful fake** behind the same seam persists a credential store as a
portable folder of JSON files and serves those routes, scriptable through the
states this issue turns on: `active`, `error`, `unavailable`, `disabled`,
missing. Integration tests drive parley's real dispatch/recovery path against the
fake. A **live conformance check** boots the real binary against a fabricated
credential in a temp auth-dir — the technique used to capture the contract above,
which exercises the real routes without touching operator credentials — and
asserts the record fields the fake models still exist.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=1.0 impl=0.1
item: lua-neovim design=0.3 impl=0.45
item: api-integration design=0.4 impl=0.5
item: lua-neovim design=0.5 impl=0.6
item: cross-cutting-refactor design=0.1 impl=0.15
item: real-api-discovery design=0.0 impl=0.15
item: smaller-go-module design=0.05 impl=0.18
item: lua-neovim design=0.3 impl=0.35
item: lua-neovim design=0.3 impl=0.5
item: smaller-go-module design=0.05 impl=0.15
item: lua-neovim design=0.3 impl=0.5
item: lua-neovim design=0.35 impl=0.55
item: smaller-go-module design=0.05 impl=0.15
item: atlas-docs design=0.04 impl=0.12
item: milestone-review design=0.0 impl=0.45
design-buffer: 0.15
total: 9.2
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only. Re-derived after plan rounds 2 and 3 (see
Revisions) — the first block was written against a 15-task plan and never
revisited; **the increase is funding previously unfunded work, not a reaction to
the judge's low-side-bias note.** Item order follows the plan's task order.

M1: `issue-spec` (the live diagnosis + brainstorm + three plan-gate rounds — no
×0.2 discount, this design dialogue actually happened); `lua-neovim` Tasks 1–2
(pure classification); `api-integration` Tasks 3–5 (key render, `management_key`,
`auth_files`, `api_argv`, the 404-driven restart); a **separate** `lua-neovim`
for Task 6 — the plan's riskiest task, dispatcher surgery plus the PQ-8 claim
contract across four files, which the first block left buried inside another
item; `cross-cutting-refactor` for deleting `check_auth_failure` /
`detect_auth_failure` and migrating their callers and specs;
`real-api-discovery` for the conformance check (genuinely reduced — this session
already captured the contract — and now written in v3.1-scaled units, which the
first block was not); `smaller-go-module` for the fake's management route,
credential store, and error modes, which the first block never funded at all.

M2: `lua-neovim` Task 9 (`decide`), `lua-neovim` Tasks 10–11 (ladder + e2e),
`smaller-go-module` Task 12 (collapsing `:ParleyProxy models`' prompt — added by
PQ-5 after the first block).

M3: `lua-neovim` Task 14 (peers/reap + `parse_peers` + the `stop()` fix),
`lua-neovim` Task 15 (login robustness), `smaller-go-module` for the fake's four
login modes.

Cross-cutting: `atlas-docs` covers three atlas passes plus the
`atlas/traceability.yaml` registrations; `milestone-review` is 3 boundaries
× 0.15 (M1-close, M2-close, final close).

Every `impl=` is now inside its v3.1-scaled band (40% of the v2 range) — the
first block wrote `lua-neovim impl=0.7`, `real-api-discovery impl=0.25`, and
`atlas-docs` at raw-table values, all above their scaled ceilings. Design hours
carry the ×0.2 spec discount everywhere the plan pre-resolves the decision
(schemas, the decide table, message contracts), with the +15% thorough-plan
buffer. `familiarity: 1.0` — cliproxy is #131's module and this session traced
dispatch → recovery live against the failing system.

## Done when

- The exact 503 `auth_unavailable` body from this issue produces a diagnosis
  naming the credential, its real status, and the next action — not
  `response is empty`.
- A recoverable failure (proxy down, stale in-memory auth, transient) is repaired
  and the query retried **without** a prompt; only a genuinely dead credential
  prompts.
- `/v0/management/auth-files` is reachable from parley on a freshly rendered
  config, and a config rendered before the key existed is restarted into it.
- Leaked non-managed proxies are detected and reapable; the rotation-race reason
  is stated once, not per query.
- A login that dies mid-flow reports the failure instead of leaving an inert
  browser window; a successful one is detected and resumes the query.
- Stateful fake + live conformance check both run in `make test`.

## Plan

Durable plan: `workshop/plans/000197-cliproxy-auth-self-healing-plan.md`

- [ ] M1 — Diagnose: pure classification vocabulary + management channel
- [ ] M2 — Recover: pure recovery policy + retry seam in the dispatcher
- [ ] M3 — Prevent: stale-proxy reaping + login-flow robustness

## Revisions

### 2026-08-01 — plan-quality round 1 (PQ-1…PQ-7)

Reason: the plan gate found two Critical design errors in the first draft. Delta:

- **PQ-1** — dropped the `config_drift`-in-`ensure_running` task entirely. It was
  dead code: `ensure_running` writes the rendered config at `cliproxy.lua:295`
  *before* it probes, so `config_drift()` in the probe callback compares the file
  to itself and never observes what the running proxy loaded. Replaced with the
  `no_management_route` 404, which is a signal from the running process.
- **PQ-2** — `classify_response` now takes `http_status` and returns nil for
  **every** 2xx, whatever the body says. The first draft would have classified
  ordinary assistant prose: `check_auth_failure` runs on every completed response
  (`dispatcher.lua:266-314`), and a chat about this very issue quotes
  `authentication_error`, `401 unauthorized`, and `payment_required`. Pinned by a
  property test over bodies × 2xx statuses, not hand-picked cases.
- **PQ-3** — the dispatcher's failure table gains `model` from `payload.model`,
  and `classify_response` backfills it, so the 401 form (which names neither
  provider nor model) can still resolve a login channel.
- **PQ-4** — the `recover_query` seam moves from M2 into M1 and becomes the
  *single* owner: `check_auth_failure` is deleted rather than left running beside
  it. Removes the ARCH-DRY violation and the un-implementable "pass http_status
  at `dispatcher.lua:311-313`" step (that scope has no status).
- **PQ-5** — added M2 Task 12: `:ParleyProxy models`' hand-rolled login prompt
  collapses onto `decide`, so both paths share one policy (ARCH-PURPOSE).
- **PQ-6** — named the fake's login modes (`success`, `port_taken`, `dies_early`,
  `hangs`) in the integration-points table.
- **PQ-7** — parley now defaults `disable-control-panel: true` when it renders
  the management key; only the JSON route is needed.

### 2026-08-01 — plan-quality round 2 (PQ-8, PQ-9)

Round 1's findings all disposed as addressed; one new Critical. Delta:

- **PQ-8** — the seam needed an ownership contract, not just an ordering. `on_error`
  is terminal and irreversible (`chat_respond.lua:1751-1765` latches
  `leg_teardown_done` and clears the lease), while recovery is async — so "call
  `recover_query` before `on_error`" still loses the race and the retry's fresh
  `qid` would stream into a dead session. `recover_query(failure, retry, give_up)`
  now **claims synchronously** (cheap, because `classify_response` is pure): falsy
  ⇒ today's path unchanged; truthy ⇒ `on_error` is withheld and the adapter owes
  exactly one of `retry()`/`give_up(msg)`, both behind one shared `tasker.once`,
  with a 15s timer degrading a hung recovery to today's behavior. Second half of
  the finding: `retry` cannot call `start_query` (a local in `D.query`) because
  `query` is `local query = function` and not self-referencable — the entry point
  is now threaded into `query` as a parameter.
- **PQ-9** (Minor, applied) — compressed the inlined implementation/test source in
  Tasks 1–2 to the non-obvious parts (pattern ordering, the status gate, the rank
  table) plus strategy lines; full source restates a diff that goes stale.

### 2026-08-01 — estimate re-derived (6.0 → 9.2)

The plan gate passed round 3; estimate-quality returned INFO. Its critique was
right on three counts and I re-derived rather than leave a stale number in the
calibration ledger:

- The block was written against the 15-task round-1 plan and never revisited
  after PQ-8 added an async ownership protocol (claim contract, shared
  `tasker.once`, timer backstop, threading `restart`/`attempt` through `query`)
  and PQ-5 added Task 12.
- Task 6 — the riskiest task in the plan, four files, two deletions, a changed
  `query` signature — had no funding line of its own after PQ-4 moved the seam
  from M2 into M1. It now has one.
- The stateful fake (management route, disk credential store, four error modes,
  four login modes) and the three atlas passes were unfunded; the fake is
  explicitly a deliverable, not scaffolding.
- Three items sat above their v3.1-scaled ceilings (`lua-neovim impl=0.7`,
  `real-api-discovery impl=0.25`, `atlas-docs` at raw values) — the 40% scale is
  now applied uniformly and every item is inside its band.

Deliberately **not** adjusted for the judge's advisory note that parley's two
`baseline-v3.1.md` rows (#144 at 0.61, #147 at 0.63) under-shoot by ~40%. That
is the ledger's job at close under #117; inflating an estimate to meet a
predicted miss would corrupt the very signal the ledger exists to collect. The
9.2 comes only from funding work that exists in the plan.

Also corrected from the repo itself: the test invocation is
`make test-spec SPEC=providers/cliproxy-managed` (not `make test SPEC=<path>`),
new files must be registered in `atlas/traceability.yaml`, and a retry is only
safe when nothing was streamed (`qt.response == ""`) or it duplicates buffer
content.

## Log

### 2026-08-01
