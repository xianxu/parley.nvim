# Boundary Review — parley.nvim#197 (milestone M3)

| field | value |
|-------|-------|
| issue | 197 — cliproxy auth failures must self-heal: detect, diagnose, recover |
| repo | parley.nvim |
| issue file | workshop/issues/000197-cliproxy-auth-self-healing.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | addb7057956759608c29cb7084b3f66a2bc659e2..HEAD |
| command | sdlc milestone-close --issue 197 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-08-01T14:48:23-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

**First, a structural note the gate needs:** the stated window `addb705..HEAD` is **empty** — `addb705` *is* `HEAD`. M3's code landed at `ba0992d`, `bf98f8d`, and `918261f`, all ancestors of the base, because the M2 review rounds outlasted the M2 work. The plan discloses this (plan.md:620-623), but combined with the M2 close recording `review verdict: not-run` (rounds 7–8 died on API errors, waived via `--no-judge`), **no fresh-context review verdict has ever been recorded against the final state of this branch**. So I reviewed the M3 surface by content rather than by window: `parse_peers`/`lstart_sec`, `peers`/`reap`/`stop`, `callback_port_blocked`/`await_credential`/`run_login`/`_usage_has_flag`/`login_argv`, the `:ParleyProxy reap` command, and the fake's login modes. The code is in good shape — the pure/IO split is real, the peer-scan and login paths are defensive in the specific ways the M2 rounds beat into them, and I independently confirmed green: 53 lifecycle / 61 auth / 10 login / 19 auth_login / 4 conformance / 4 e2e, `make lint` 0/0 across 313 files. Two Important gaps keep it off SHIP, both cheap: `codex-device` is a login provider with no channel mapping, which silently disarms the login watch's peer-refresh filter; and the `hangs` login branch is untestable by construction, so a fake mode built for it (PQ-6) is dead.

## 1. Strengths

- **`parse_peers` matches the executable token, not a substring** (`cliproxy_auth.lua:288-303`) — and the fixture actually contains the `zsh -c` wrapper that would have been SIGTERMed. Both binary names (`cliproxyapi`, `cli-proxy-api`) are covered, which is the omission that made this issue's own survey undercount.
- **`callback_port_blocked` probes by CONNECT, not bind** (`cliproxy.lua:983-994`), with the reason stated: libuv sets `SO_REUSEADDR`, so a bind probe reports "free" for exactly the case the preflight exists to catch. That is a non-obvious correctness call, correctly made.
- **`run_login`'s single-settle latch guards the notify as well as the callback** (`cliproxy.lua:1043-1058`), and `cliproxy_login_spec.lua:104-125` pins the operator-visible half — the abandoned watcher may not speak after the login already settled. That test would fail on the naive fix.
- **The peer-scan latch arms on the scan, not on finding peers** (`cliproxy.lua:866-871`), with a spec asserting the zero-peer case arms it (`cliproxy_lifecycle_spec.lua:909`). This is the case the operator lives in after `reap`, and it was a ~150ms blocking `ps`+`lsof` per dispatch.
- **`reap` counts only kills the OS accepted** (`cliproxy.lua:910-915`) — luv's `kill` returns `nil+err` rather than raising, so a bare `pcall` would report the rotation race resolved when nothing was stopped. Pinned at `cliproxy_lifecycle_spec.lua:956`.
- **`login_argv` validates the flag against `<binary> -h`** with whole-token matching (`cliproxy.lua:772-780`), and the new conformance check reports the real delta — it correctly flags `google` unsupported on the installed 7.2.110.

## 2. Critical findings

None.

## 3. Important findings

**I1 — `codex-device` has no channel mapping, which silently disables the login watch's peer-refresh filter and drops the account from the success notice.**
`lua/parley/cliproxy.lua:949` · `lua/parley/cliproxy_config.lua:195` · `lua/parley/cliproxy.lua:744-752`

`LOGIN_FLAGS` has seven keys; `CHANNEL_LOGIN`'s value set has six. Verified empirically — `channels_for_login("codex-device")` returns `{}` while every other provider resolves:

```
antigravity -> {antigravity}   claude -> {claude}   codex -> {codex}
codex-device -> {}             google -> {aistudio, gemini, gemini-cli}
kimi -> {kimi}                 xai -> {xai}
```

Two consequences on `:ParleyProxy login codex-device`, which the completer offers:

1. `newest_credential_mtime` falls to `local matches = next(channels) == nil` (`cliproxy.lua:949`) and accepts **any** `.json` in the auth-dir. A peer proxy's 15-minute refresh rewriting an unrelated credential satisfies the watch → parley reports "codex-device login succeeded" for a login that is still pending or already dead. That is the precise hazard the comment three lines above (`cliproxy.lua:946-948`) says the filter prevents, and `atlas/providers/cliproxy-managed.md:220` states as a guarantee: *"watches the auth-dir (filtered to the login's own channels, so a peer proxy's refresh cannot satisfy it)"*. False for this provider.
2. `credential_health_for_login("codex-device")` takes the `#channels == 0` fallback (`cliproxy.lua:476-478`) and queries channel `"codex-device"`, which no record carries — the real channel is `codex`. So a genuinely successful login reports `health.state == "missing"`, and the notice at `cliproxy.lua:1129` drops the account. That contradicts the Done-when: *"a successful one is detected and reported with the account."*

ARCH-DRY / ARCH-PURPOSE: `channels_for_login` correctly derives the inverse of `CHANNEL_LOGIN` rather than hand-maintaining it — but `LOGIN_FLAGS` is a *second* hand-maintained set on the same axis with no enforced correspondence, and this is the drift that produces.

Fix sketch: add an explicit alias in `cliproxy_config.lua` and route `channels_for_login` through it —

```lua
-- Device-code flows log into an existing channel; they are a login METHOD,
-- not a channel of their own.
local LOGIN_ALIASES = { ["codex-device"] = "codex" }
function M.channels_for_login(login)
    login = LOGIN_ALIASES[login] or login
    ...
end
```

plus the test that would have caught it: for every `cliproxy.login_providers()` entry, assert `#cc.channels_for_login(p) > 0`.

**I2 — the `hangs` login branch is untestable by construction; two of four modeled fake login modes are dead.**
`lua/parley/cliproxy.lua:1123` · `tests/fixtures/fake_cliproxy:176`

Plan Task 15 Step 3 is checked and says *"Test against `success`, `dies_early`, and `hangs`."* Only `success` and `dies_early` are driven — `PARLEY_FAKE_LOGIN_MODE` appears in specs at `cliproxy_login_spec.lua:59/74/84/95/108` and nowhere else. The `hangs` branch (`await_credential` returns false → `jobstop` → `"login did not complete"` WARN, `cliproxy.lua:1132-1136`) cannot be exercised because `run_login` hardcodes `180000` at `cliproxy.lua:1123` with no injection seam. `port_taken` is likewise never driven — the preflight spec binds :54545 in-process instead. So the fake models two states no test runs (ARCH-MOCK: a fake satisfies the principle only when production and test flow share the boundary; here the boundary exists but half the modeled states are unreachable from tests).

Fix sketch: `function M.run_login(provider, argv, on_done, timeout_ms)` defaulting to `180000`, then a spec driving `hangs` at ~1500ms asserting exactly one settle, `ok == false`, and the "did not complete" wording. Either drive `port_taken` through the fake or drop the mode.

**I3 — the M3 boundary window is empty; the close record should say what was actually reviewed.**
`workshop/issues/000197-cliproxy-auth-self-healing.md:310`

`sdlc milestone-close --issue 197 --milestone M3` computed `BASE_SHA = addb705 = HEAD`. The effective M3 content window is `ad2ce42..HEAD`. Combined with M2's `review verdict: not-run`, the tracker currently carries no recorded verdict covering `bf98f8d`/`918261f`. Record in `## Log` that this M3 review covered the M3 surface by content across `ad2ce42..HEAD` rather than by the empty computed window, and carry this verdict forward — otherwise the issue closes with two boundaries and zero recorded verdicts.

## 4. Minor findings

- `cliproxy.lua:951-952` — `vim.fn.readfile` is evaluated **outside** the `pcall` (arguments evaluate before the call). `readfile` on a directory raises `E17` (verified); inside `await_credential`'s `vim.defer_fn` poll a raise settles nothing and the login hangs silently — #197's own failure class. Wrap the read: `pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(p), "\n")) end)`.
- `cliproxy.lua:1188-1189` — `@param _retry fun() # unused in M1` is stale; M2's ladder calls `retry()` at `cliproxy.lua:1239/1257/1261`. Same class as M2 round-1's I3 (docs asserting deleted behavior).
- `cliproxy.lua:1010` — `await_credential`'s docstring declares `@param channel string`; the parameter is `login` and it is a login-provider name.
- `cliproxy_auth.lua:466` — `auth_file_is_stale(health, proxy_state)` passes two arguments to a one-parameter function (`cliproxy_auth.lua:389`). Harmless, but it reads as if `proxy_state` still participates in staleness, which the M2 rework removed.
- `cliproxy.lua:905-906` — `reap`'s inner comment ("a process we cannot identify as a proxy **we started** is left alone") inverts what reap does: it targets proxies parley did *not* start.
- `cliproxy.lua:884-888` and `init.lua:463-465` — the rotation-race explanation is duplicated near-verbatim (ARCH-DRY). The repo's own rule says error text is API; one source, two consumers.
- `tests/integration/cliproxy_lifecycle_spec.lua:876` — `if #peers == 0 and not vim.system then` is dead: `vim.system` is always truthy on nvim 0.10+. The real guard is the `ps_ok` check two lines down.

## 5. Test coverage notes

- Independently verified green with the process table readable: `cliproxy_auth` 61, `cliproxy_config` 46, `cliproxy_budget` 3, `dispatcher_query` 56, `failure_notice` 6, `providers_pre_query` 6, `cliproxy_lifecycle` 53 (all 9 peer/reap tests ran), `cliproxy_login` 10, `cliproxy_auth_login` 19, `cliproxy_recovery_e2e` 4, `cliproxy_command` 10, `cliproxy_conformance` 4 (real 7.1.71 binary), `cliproxy_dispatch` 3, `cliproxy_caller_teardown` 5, `cliproxy_download` 3. `make lint`: 0 warnings / 0 errors across 313 files. The M3 log's numbers check out.
- The `peers()` integration test skips when the process table is unreadable (`cliproxy_lifecycle_spec.lua:884`) — it fired in my sandbox (`ps` → `EPERM`), which is the guard working correctly, not a code defect. Worth knowing that on a hardened CI runner all `peers()` *integration* coverage drops silently while the suite stays green; the 8 `parse_peers` unit tests are fixture-driven and always run, so the pure core stays covered.
- `stop()`'s non-managed-port leak fix has a real regression test (`cliproxy_lifecycle_spec.lua:994`). Good — that was the seven-week survival mechanism from `## Problem` §4.
- Gap beyond I2: nothing asserts `run_login` behaves when the binary exits **0** without writing a credential (a browser-side cancel). Today that waits the full 180s before reporting. Not wrong — the exit/write race justifies not settling on code 0 — but worth a comment or a shorter post-exit grace window.

## 6. Architectural notes

- **ARCH-DRY — flag (I1, plus the duplicated prose Minor).** Otherwise a genuine pass and visibly better than M1: `restart_managed` collapses the retyped stop→wait→ensure, `api_argv` serves four routes, `credential_action` is shared by `recover` and `:ParleyProxy models`, `channels_for_login` derives rather than restates. The one remaining hand-maintained pair on a single axis is `LOGIN_FLAGS` × `CHANNEL_LOGIN`, and it has already produced a defect.
- **ARCH-PURE — pass.** `parse_peers`, `lstart_sec`, `rfc3339_sec`, `decide`, `credential_action`, `diagnosis`, `classify_*` are all deterministic transforms in `cliproxy_auth.lua` with no `vim.system`/fs/clock, and 61 unit tests run without a proxy. `peers()`/`reap()`/`run_login()` are thin shells that gather and execute. `lstart_sec` correctly parses rather than string-comparing weekday-leading stamps — the same class of bug as M2's C1, caught proactively this time.
- **ARCH-PURPOSE — mostly pass.** Shadow-sweep on the issue's "one vocabulary, no parallel regex-guessing left behind": `detect_auth_failure`, `check_auth_failure`, and the `"empty list ⇒ not authenticated"` inference are genuinely gone from `lua/` (only historical comments remain). Every consumer derives from `classify_response`/`classify_auth_files`/`credential_action`. The login axis is the one place a hand-maintained restatement survives — I1.
- **ARCH-MOCK — mostly pass.** The fake is a real stateful double: a portable folder of credential JSONs plus a `state.json` overlay, serving `/v1/models`, `/v1/chat/completions` error bodies, the management route with the 404-without-key behavior, and `-h`. Production and test flow share the boundary. The live conformance check now pins the management record fields, the 404, the api-key 401, **and** the login-flag set against the real binary — that last one is the right instinct, since it caught a genuine version drift. Flag: `hangs` and `port_taken` are modeled but never driven (I2).

## 7. Plan revision recommendations

Add a `## Revisions` entry to `workshop/plans/000197-cliproxy-auth-self-healing-plan.md` recording what M3 actually shipped:

1. **Task 14 Step 3 did not use an identity probe.** The step says reap SIGTERMs peers *"after an identity probe (reuse `port_holds_cliproxy`'s discipline)"*. The code deliberately does not — a peer is by definition not on the managed port, so there is nothing to probe against; identity comes from `parse_peers`' executable-token match (`cliproxy.lua:893-895`). The reasoning is sound and documented in code, but the plan step still claims a mechanism that was replaced.
2. **Task 15 Step 2's text is stale.** It reads *"run with `-no-browser`, capture stdout, extract the `https://claude.ai/oauth/authorize…` line, `vim.ui.open()` it"* — all four reversed (`cliproxy.lua:1062-1067`; the spec at `cliproxy_login_spec.lua:65-67` asserts `#opened == 0`). The 2026-08-01 "what actually shipped" revision records the reversal at the summary level; the step text itself should be corrected so a reader of the checklist isn't misled.
3. **Task 15 Step 3's `hangs` test was not delivered** (I2). Either land the test or move the claim.
4. **Core-concepts table:** no contradictions found. All M3 rows verified present at their stated paths — `parse_peers` and `lstart_sec` in `lua/parley/cliproxy_auth.lua`; `peers`/`reap`, `callback_port_blocked`, `await_credential`, `run_login`, `_usage_has_flag`, hardened `login` in `lua/parley/cliproxy.lua`; login modes in `tests/fixtures/fake_cliproxy`. PURE rows test without IO; INTEGRATION rows are injected or command-invoked, not called from pure logic. No revision needed here.

The plan-gate ledger (`…-plan-gate.md`) has no open findings — PQ-1 through PQ-9 were all disposed at round 3, and I confirmed each disposition still holds in the code (notably PQ-2's 2xx property at `cliproxy_auth.lua:89-92` and PQ-8's claim contract at `dispatcher_query_spec` group J).
