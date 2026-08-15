# Boundary Review — parley.nvim#197 (whole-issue close)

| field | value |
|-------|-------|
| issue | 197 — cliproxy auth failures must self-heal: detect, diagnose, recover |
| repo | parley.nvim |
| issue file | workshop/issues/000197-cliproxy-auth-self-healing.md |
| boundary | whole-issue close |
| milestone | — |
| window | 375b6359a48a3f98acdec41532bc406f8c1a113a..HEAD |
| command | sdlc close --issue 197 |
| reviewer | claude |
| timestamp | 2026-08-01T15:00:39-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

This close boundary covers the whole issue (`375b635` is the branch point), and the work holds up under independent verification. I checked the load-bearing claims rather than trusting the Log: `rfc3339_sec` matches an external oracle exactly across every case the algorithm branches on — leap years, the epoch, the 100/400-year rules, out to `2400-02-29` — so the calendar defect that killed the restart rung is genuinely closed; the staleness check now compares two *different* quantities from one management record (`modtime` vs `updated_at`) rather than a value against itself, and its integration test reproduces the condition the way the system produces it (seed the proxy's load time with a real read, then `fs_utime`) plus the negative assertion that `stop()` is *not* called on the healthy path — the one line that makes `retry` and `restart` distinguishable at all. Measured: **292 examples across 15 mapped specs, 0 failed, 0 errors**, with the conformance spec booting a real binary (no SKIP) and correctly reporting a live delta (`google` unsupported on the installed 7.2.110); `make lint` **0 warnings / 0 errors in 313 files**; the plan is 55/56 ticked with only `sdlc close` open, and every Core-concepts row verified present at its stated path. Nothing here is Critical. What keeps it off SHIP is two reproduced strand-the-claim paths on the login flow — the exact symptom class this issue exists to remove (`## Problem` §5, "nothing reported the death") — plus one ARCH-MOCK conformance gap on the single behavior the restart rung branches on.

## 1. Strengths

- **`cliproxy_auth.lua` is honestly pure and externally validated.** No `vim.*` state, no clock, no IO (`lua/parley/cliproxy_auth.lua:1-474`); 61 unit examples with zero mocks. I re-derived `rfc3339_sec`'s arithmetic against Python's `datetime` on ten boundary dates including `2100-03-01` and `2400-02-29` — all exact. That is the difference between a parser tested against itself and one that can be falsified.
- **The staleness rung is finally correct, and correct for the right reason.** `auth_file_is_stale` (`cliproxy_auth.lua:389-393`) reads two fields of one record and needs no `fs_stat`, so the predicate got *more* pure while becoming right, and an IO term left the repair budget. The comment at `:385-388` names the real lesson — the bug was in the operands, not the comparison.
- **The claim contract is implemented as specified, including the parts that bite.** `dispatcher.lua:465-500`: one shared `tasker.once`, `pcall` around the hook with a raise normalised to "never claimed anything", a backstop that cannot double-fire, and a per-attempt `vim.deepcopy(payload)` because `format_headers` consumes payload fields. Group J pins all nine behaviors including the throwing hook (J7b) and the payload snapshot (J4b).
- **ARCH-MOCK is real at the boundary that matters.** The fake serves the management route from a portable credential folder plus a mutable `state.json`, models `updated_at` as *load* time (`fake_cliproxy:104-110`) so the touch-vs-reload distinction is honest rather than fixture-manufactured, and serves the captured 7.1.71 503/401/402 bodies — which is what lets `cliproxy_recovery_e2e_spec.lua` drive `dispatcher.query → recover_query → the operator notice` and assert the answer actually arrives, not merely that no prompt appeared.
- **`parse_peers` matches the executable token, and the fixture contains the trap.** `tests/fixtures/ps_cliproxy_peers.txt` carries the real `zsh -c` wrapper quoting the proxy path, plus both binary names — so the test would fail if substring matching returned.
- **Plan traceability is complete this time.** 55/56 checkboxes, milestone columns on both tables, and I verified all 26 named entities exist at their stated paths with `detect_auth_failure`/`check_auth_failure` absent from `lua/`.

## 2. Critical findings

None.

## 3. Important findings

**I1 — `newest_credential_mtime` calls `vim.fn.readfile` outside its `pcall`; an unreadable entry in the auth-dir strands the login watch with no notify and no callback.** `lua/parley/cliproxy.lua:951-952`

```lua
local ok, decoded = pcall(vim.json.decode,
    table.concat(vim.fn.readfile(dir .. "/" .. name), "\n"))
```

Arguments evaluate before `pcall` runs, so `readfile` is unprotected — and it *raises* (verified: `E17` on a directory, `E484` on a vanished file). Because `channels` is non-empty for every real login, this reads **every** `.json` in the auth-dir on **every** 500 ms poll for up to three minutes.

Reproduced end to end. With the hazard appearing while the watch is running — i.e. inside `await_credential`'s `vim.defer_fn` poll, which is exactly where `run_login`'s watcher lives:

```
[C]: in function 'readfile'
  .../cliproxy.lua:952: in function 'newest_credential_mtime'
  .../cliproxy.lua:1017: in function ''
ASYNC-PHASE await_credential SETTLED = false
```

Failure scenario: a credential file vanishes between `readdir` and `readfile` (peer proxies refresh every 15 minutes and rotate tokens — the race this issue is about), or the auth-dir holds an unreadable `*.json`. The raise lands in an async callback with no guard, so `run_login` never settles: no `on_exit` report, no success notice, no timeout notice. That is `## Problem` §5 reintroduced. The synchronous call at `:1063` also propagates out of `:ParleyProxy login` (visible error, no login started).

Fix sketch — wrap the read, not just the decode:
```lua
local ok, decoded = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(dir .. "/" .. name), "\n"))
end)
```
and consider guarding the `uv.fs_stat` branch's file too. Test: an auth-dir containing a directory named `x.json`, asserting `await_credential` still settles.

**I2 — `prompt_login`'s `vim.schedule` body is unguarded, so a raising `vim.ui.select` strands the claim and latches login prompts off for the session.** `lua/parley/cliproxy.lua:1153-1178`

Round 3 of the M1 review guarded `vim.cmd` *inside* the select callback; the call to `vim.ui.select` itself (`:1160`) is still bare, and `vim.ui.select` is routinely replaced (dressing.nvim, telescope-ui-select, snacks.nvim). Reproduced with a raising override:

```
Error executing vim.schedule lua callback: dressing.nvim: window creation failed
  .../cliproxy.lua:1160: in function 'select'
claimed=true  settled=nil
```

Failure scenario: the UI plugin errors → `done()` is skipped → the claim is stranded until the 30 s backstop replaces the diagnosis parley just computed with "recovery timed out"; and `_login_prompt_active` stays `true` for the rest of the session, so every later credential failure short-circuits at `:1154` and no login is ever offered again. Same class as the fix already applied one line below, and `workshop/lessons.md`'s own rule ("audit *every* path out") names it.

Fix sketch:
```lua
vim.schedule(function()
    local ok, err = pcall(function() ... vim.ui.select(...) ... end)
    if not ok then
        _login_prompt_active = false
        logger.error("cliproxy: login prompt failed: " .. tostring(err))
        done()
    end
end)
```
Test: throw from `vim.ui.select` and assert the claim settles once with the diagnosis, and that a second failure still prompts.

**I3 — the live conformance check pins that `modtime`/`updated_at` exist, not the behavior the restart rung branches on (ARCH-MOCK).** `tests/integration/cliproxy_conformance_spec.lua:24-32`

`REQUIRED_FIELDS` now includes both fields — good — but the *semantics* the ladder depends on ("a touch-only write advances `modtime` alone; a content rewrite advances both") is asserted nowhere against the real binary. It is stated in a code comment (`cliproxy_auth.lua:380-383`) as manually verified, and modelled by the fake. If a future cliproxy re-stats `updated_at` per request too, the fake keeps lying, every test stays green, and the restart rung becomes dead code again — for the fifth time in this issue, and silently. The spec already boots the binary and writes a credential, so this is a few lines:

```lua
local before = get_record()
vim.loop.fs_utime(cred_path, os.time() + 5, os.time() + 5)  -- touch only
local after = get_record()
assert.is_true(ca.rfc3339_sec(after.modtime) > ca.rfc3339_sec(before.modtime))
assert.equals(before.updated_at, after.updated_at, "updated_at now tracks mtime — the restart rung is dead")
```

## 4. Minor findings

- `cliproxy.lua:1190` — `@param _retry fun() # unused in M1: this milestone diagnoses, it never repairs`; the parameter is `retry` and drives the entire ladder. Flagged in six prior review rounds.
- `cliproxy.lua:417-419` — `credential_health`'s docstring says the compound case is blocked "when `_management_restart_done` shows this claim already restarted the proxy"; the shipped guard is `recover`'s per-claim `restarted_this_claim`, precisely because module state could not serve. The atlas has this right; the code comment does not.
- `cliproxy.lua:1255` — "past the dispatcher's 25s backstop"; `dispatcher.recovery_timeout_ms` is 30000.
- `cliproxy_auth.lua:466` — `auth_file_is_stale(health, proxy_state)` passes two arguments to a one-parameter function, and `:436` still documents `proxy_state` as `{ running, auth_file_modtime }`.
- `cliproxy.lua:1010` — `await_credential`'s `@param channel string`; the parameter is `login` and holds a login-provider name.
- `cliproxy.lua:905-906` — `reap`'s in-loop comment ("a process we cannot identify as a proxy **we started** is left alone") inverts what reap targets; identity comes from `parse_peers`, as the docstring correctly says.
- `init.lua:453` — `:ParleyProxy reap` calls `cliproxy.peers()` unguarded. `peers()` pcalls its `ps` call but not `pids_on_port`'s `lsof`, so a hardened runtime errors the command (the dispatch path is safe — `ensure_running` wraps it).
- `cliproxy.lua:474-491` — `credential_health_for_login` issues one full `/v0/management/auth-files` request per channel (3 curls + 3 key file reads for `google`) when a single response already carries every channel.
- `LOGIN_FLAGS.google = "-login"` does not exist on the installed 7.2.110. Now *honestly* reported (`_usage_has_flag` + the conformance NOTE), which is the right outcome — but `providers`/completion still advertise it and nothing records what the current release uses instead, so a dead gemini credential's `prompt_login` leads to a dead end.
- `run_login`: a login that exits **0** without writing a credential says nothing for the full 180 s (`on_exit` only settles on non-zero). Defensible given the exit/write race; worth a comment.
- The `## Log` and atlas present "`stop()` no longer leaks parley-spawned proxies on non-managed ports" as a fix. The M2 review established the `_stray_spawned` sweep was dead code and it was correctly deleted — `_spawned` already held those pids — so nothing changed there. `cliproxy.lua:678-681`'s `NB:` comment says this honestly; the tracker prose overstates it.
- Duplicated operator-facing prose: the rotation-race explanation is hand-copied in `init.lua:463-465` and `cliproxy.lua:884-888` (ARCH-DRY); `newest_credential_mtime:941-943` re-derives the `~/.cli-proxy-api` default.

## 5. Test coverage notes

Verified independently rather than from the Log: `cliproxy_auth` 61, `cliproxy_config` 48, `cliproxy_budget` 3, `dispatcher_query` 56, `failure_notice` 6, `providers_pre_query` 6, `cliproxy_lifecycle` 53, `cliproxy_login` 11, `cliproxy_auth_login` 19, `cliproxy_command` 10, `cliproxy_recovery_e2e` 4, `cliproxy_conformance` 4, `cliproxy_dispatch` 3, `cliproxy_caller_teardown` 5, `cliproxy_download` 3 — **292 examples, 0 failed, 0 errors**. `make lint` 0/0 in 313 files.

Two environment caveats I could not eliminate, both honest:

- **`make test` is not verifiable clean here.** `git_markdown_source_spec` and `markdown_finder_async_spec` fail, but the cause is my sandbox: `git init` returns 128 with `cannot copy '.../hooks/commit-msg.sample': Operation not permitted`. I reproduced that directly outside the suite. Every unit spec passed and no cliproxy spec failed. So plan Task 16's "`make test` clean" claim isn't contradicted, but it also isn't confirmed by this run.
- **`SKIP: ps unavailable — peer detection not exercised.`** The process table is unreadable in this sandbox, which is exactly the degradation `peers()` is written to survive — the loud skip is the right design. It does mean M3's live peer-detection path had no coverage in this run; the eight `parse_peers` unit cases are fixture-driven and always run.

Gaps, in the order I'd close them:

1. **`newest_credential_mtime` has no test at all** (I1) — neither the channel filter nor the error path, on a function whose raise strands the login watch.
2. **`prompt_login`'s raise surface is only half-tested** (I2). `cliproxy_auth_login_spec.lua` throws from `vim.cmd` *inside* the select callback; nothing throws from `vim.ui.select` itself.
3. **No conformance for the touch-vs-reload distinction** (I3) — the one live behavior the restart rung reads.
4. `run_login`'s exit-0-without-credential path (the 180 s silent wait) is unexercised.
5. `:ParleyProxy reap`'s command branch (the confirmation list, the zero-peer message) has no test; only `cliproxy.reap()` itself does.

The strongest patterns here are worth keeping: the `attempt >= 1` property sweep over 5 kinds × 6 states × liveness, the external-oracle epoch assertions, the fixture-tie test that classifies the captured 7.1.71 payload so the hand-written `rec()` helper can't drift, and the "reproduce the condition the way the system produces it" staleness test.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — pass.** Every consolidation this issue made has ≥2 live callers and one source: `api_argv` (four routes), `split_status` (absorbed both pre-existing regex copies), `restart_managed` (both repair callers get the port-release wait), `credential_action` (`decide` + `:ParleyProxy models`), `channels_for_login` (derived from `CHANNEL_LOGIN`, not a third table), `healthier`, `lstart_sec`, and `SUBS_HELP` now covering `reap`. `_stray_spawned` was deleted after the deletability check rather than kept — the right response. Remaining duplication is prose and a default path, not logic (Minor).
- **ARCH-PURE — pass.** The pure core is substantial and mock-free; `recover` is gather-then-execute with no policy in it, which closes the M1 carry-forward. Two moves in this window are the model to reuse: pulling the oldest-peer comparison out of the IO shell into `lstart_sec`, and making `auth_file_is_stale` read two fields of one record instead of stat'ing a file. Both made a predicate *both* purer and correct — the general lesson being: when a pure predicate needs an IO-gathered second operand, first check whether the record already carries it.
- **ARCH-PURPOSE — pass.** Shadow sweep on "who infers auth state": the dispatch path derives from the management API ✓; `:ParleyProxy models` derives, on the channel axis, with the `{aistudio, gemini, gemini-cli}` set asserted ✓; `detect_auth_failure`/`check_auth_failure` are gone with no live callers ✓; all three hand-maintained restatements of the disproved empty-list inference are corrected (`cliproxy.lua:1303-1307`, `cliproxy_config.lua:255-259`, `atlas/…:259-268`) ✓. Done-when by item: the 503 diagnosis ✓ (e2e), self-repair with the answer arriving ✓ (e2e), management route + 404 restart ✓, peers detected/reapable and stated once ✓, login death reported ✓, and "resumes the query" **explicitly descoped with its reason recorded** in both the issue and the plan ✓.
- **ARCH-MOCK — flag (I3).** The fake is a genuine stateful double behind the boundary production uses, with a portable file-backed credential store, captured real error bodies, `_once` transient modes, and three login modes all now driven by specs (`port_taken` was deleted rather than left as untested fixture code — the correct answer to the "a fake state no test drives is documentation" lesson). The live conformance check runs for real and reports an actual dependency delta. The one gap is depth, not shape: the behavior the restart rung *branches on* is the one behavior the live check doesn't assert.
- **Plan-gate carry-forward:** `workshop/plans/000197-cliproxy-auth-self-healing-plan-gate.md` `## Open findings` reads "(none — every finding has been disposed)", verified on disk. I re-checked each disposition against the code — PQ-1 (404-driven, no config-drift check), PQ-2 (status gate at `cliproxy_auth.lua:89-92` + the property test), PQ-3 (`model` from `payload.model`, `dispatcher.lua:434`), PQ-4 (single seam, both old functions deleted), PQ-5 (Task 12 landed on the channel axis), PQ-6 (login modes, three of four, the fourth deliberately removed), PQ-7 (`disable-control-panel` default true, `allow-remote` never set, both tested), PQ-8 (claim contract, Group J), PQ-9. Nothing to carry forward.
- **M3 review carry-forward:** its I1 (`codex-device` had no channel) is closed by `LOGIN_ALIASES` plus a correspondence test asserting *every* `login_providers()` entry resolves to ≥1 channel — deriving the invariant rather than patching the one instance, which is the right shape. Its I2 (`hangs` untestable) is closed by the injectable `timeout_ms` and a spec. Its I3 (empty window) is recorded. Its Minor #1 is I1 above, still open.
- **For the next issue touching this module:** `stop()` now has four callers and `peers()` three. The port-release discipline, the ~150 ms `ps`+`lsof` cost, and the peer-scan latch all want to sit behind one seam with one arming point before a fifth caller appears.

## 7. Plan revision recommendations

The plan otherwise matches the code — both tables carry milestone columns, the `decide` table's rows now agree with the shipped policy including the `expired`/`healthy` and `unknown` cases, and the "what actually shipped" Revisions block is accurate. Two entries remain:

1. **Task 15 Step 2's text still describes the reverted design** (`plan.md:491`): "run with `-no-browser`, capture stdout, extract the `https://claude.ai/oauth/authorize…` line, `vim.ui.open()` it" — all four reversed in `cliproxy.lua:1064-1070`, with `cliproxy_login_spec.lua:65-67` asserting `#opened == 0`. Revisions #4 records the reversal at summary level, but the ticked step reads as if `-no-browser` shipped, contradicting the same file eight sections down. Recommended by the M3 review; still open.
2. **The fake's login-mode list is stale** (`plan.md:140`): `port_taken` was deliberately removed (the callback-port preflight is fixtured by binding in-process, as the fake's own docstring now says). Record that three modes ship and why the fourth was dropped, so the next reader doesn't restore an untested state.
3. **Record `google`'s login status.** The plan notes the mechanism ("7.2.110 dropped `-login` that 7.1.71 has") but not the consequence: on the installed release `:ParleyProxy login google` cannot run, so the gemini/aistudio family has no login path even though `providers` and completion advertise one. Either record what the current release uses, or record that the provider is unsupported on ≥7.2 and that `login_providers()` should reflect it.

---

## Re-review — 2026-08-01T15:01:14-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 197 — cliproxy auth failures must self-heal: detect, diagnose, recover |
| repo | parley.nvim |
| issue file | workshop/issues/000197-cliproxy-auth-self-healing.md |
| boundary | whole-issue close |
| milestone | — |
| window | 375b6359a48a3f98acdec41532bc406f8c1a113a..HEAD |
| command | sdlc close --issue 197 |
| reviewer | claude |
| timestamp | 2026-08-01T15:01:14-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M1 and M2 are in genuinely good shape and I verified that rather than trusting the Log: `cliproxy_auth.lua` is honestly pure (61 unit examples, zero mocks), the anti-loop property test sweeps kind × state × liveness at `attempt >= 1`, `rfc3339_sec` is pinned against absolute epochs, the staleness rung finally compares two distinct record fields (`modtime` vs `updated_at`) with both pinned by a live conformance check, the dispatcher claim contract is faithful (shared `tasker.once`, pcall'd hook, backstop, per-attempt payload snapshot), and the conformance spec really booted the installed binary and correctly reported `google` unsupported on 7.2.110 — a live check that found real drift. Independent verification: `make test-spec SPEC=providers/cliproxy-managed` → **292 examples, 0 failed, 0 errors**; `make lint` → **0/0 in 313 files**; every cliproxy spec also passes under the full parallel `make test-integration`. What blocks the close is M3's operator-facing half: `ensure_running` arms the peer latch *before* calling `warn_about_peers`, and `warn_about_peers`'s first line early-returns on that same latch — so **the rotation-race warning never fires, at all**. I reproduced it twice, once end-to-end through the real `ensure_running` against a live fake proxy with a peer present (`ensure_running completed=true warnings=0`). Done-when "the rotation-race reason is stated once, not per query" is not delivered, and `## Outcome` in the issue currently asserts that it is.

## 1. Strengths

- **`cliproxy_auth.lua` is pure in the way the principle means it** (`lua/parley/cliproxy_auth.lua`) — no clock, no IO, no `vim.*` state; 61 unit examples run with no mocks. The `attempt >= 1` property sweep (`tests/unit/cliproxy_auth_spec.lua`) expresses the whole anti-loop safety argument as a property rather than a case list.
- **The staleness rung is correct and honestly tested.** `auth_file_is_stale` (`cliproxy_auth.lua:389-393`) reads two genuinely different fields of one record and needs no `fs_stat` — it got *more* pure while getting correct — and `cliproxy_conformance_spec.lua:24-32` pins both fields against the real binary. The integration test seeds the proxy's load time with a real read and then `fs_utime`s the file, reproducing the missed-fsnotify signature rather than fabricating it.
- **The live conformance check earns its keep.** It reports `NOTE: this cliproxy build does not support: google (…no -login flag)` against the installed 7.2.110 — a real version drift surfaced by the check rather than by an operator. That is ARCH-MOCK working as designed.
- **The claim contract holds under abuse** (`dispatcher.lua:458-500`): one shared `tasker.once`, the hook `pcall`ed with a raise normalised to "never claimed", a backstop that cannot double-fire, and `start_query` threaded in as its own restart entry point with a per-attempt `vim.deepcopy(payload)` so a retry re-issues the same request.
- **The consolidations are real, each with two live callers**: `restart_managed` (both repair paths inherit the port-release wait), `credential_action` (shared by `decide` and `:ParleyProxy models`), `channels_for_login` + `LOGIN_ALIASES` (derived from `CHANNEL_LOGIN`, closing the M3 review's `codex-device` gap), and `M._repair_budget_sec` derived from the constants each step uses and asserted by `cliproxy_budget_spec`.

## 2. Critical findings

**C1 — the rotation-race warning never reaches the operator: `ensure_running` arms the latch that `warn_about_peers` checks.** `lua/parley/cliproxy.lua:586-594` + `lua/parley/cliproxy.lua:862-873`

```lua
-- ensure_running
if not M.peer_warning_shown() then
    M._arm_peer_scan()                      -- sets _peer_warning_shown = true
    pcall(function() M.warn_about_peers(M.peers()) end)
end

-- warn_about_peers
function M.warn_about_peers(peers)
    if _peer_warning_shown then return end   -- <-- always true by now
```

`_arm_peer_scan()` (`:831-833`) sets the exact flag `warn_about_peers` guards on, so the warning is unreachable from the dispatch path. Reproduced end-to-end — real `ensure_running`, real `write_rendered_config`, real health probe against a spawned fake proxy, one peer present:

```
REVIEW: ensure_running completed=true  warnings=0
```

and against the block in isolation:
```
REVIEW: warnings emitted = 0                 (via ensure_running's guard)
REVIEW: direct-call warnings = 1             (what the existing specs test)
```

Failure scenario: the operator is in exactly the state that motivated this issue — five leaked June proxies rotating the shared auth-dir's refresh token. Parley detects them on the first dispatch, discards the finding silently, and the operator is never told the mechanism or that `:ParleyProxy reap` exists. `reap` still works, but it is the only lever and nothing points at it: `:ParleyProxy` help lists it tersely ("stop other cliproxy processes racing this one's auth-dir") with no reason to suspect it applies. This breaks Done-when #4 ("the rotation-race reason is stated once, not per query" — it is stated zero times), contradicts `atlas/providers/cliproxy-managed.md:204` ("`ensure_running` warns once per session naming that mechanism"), and makes the issue's `## Outcome` claim ("now detected on the first dispatch, with a warning naming the mechanism and `:ParleyProxy reap` to clear them") false as shipped.

Both prior fixes were right about their own concern — round 4 moved the latch onto the scan so a healthy machine stops paying ~150ms per dispatch; round 5's "arm FIRST" made a raise inside `peers()` safe — but the two concerns ("the scan is done" and "the warning was said") were collapsed onto one flag, and the second fix disabled the first's payload.

Fix sketch — let `warn_about_peers` own the latch (it already sets it before its `#peers == 0` return, so both the zero-peer and raising paths still arm):

```lua
if not M.peer_warning_shown() then
    local ok, found = pcall(M.peers)
    M.warn_about_peers(ok and found or {})   -- arms on every path, warns when there is something to say
end
```
`M._arm_peer_scan` then has no caller and should go, or become the raise-path arming only.

The test that closes it is the one no spec has: drive `ensure_running` **with a non-empty peer list** and assert exactly one `logger.warning`, then drive it again and assert still one. Today's three peer specs call `warn_about_peers` directly (blind to the wiring) and the `ensure_running` spec stubs `peers` to return `{}` and only counts scans — so nothing ever pairs the real entry point with a peer that exists.

## 3. Important findings

**I1 — a raising `vim.ui.select` strands a claimed failure and permanently latches the login prompt.** `lua/parley/cliproxy.lua:1153-1178`

Round 3 of the M1 review guarded `vim.cmd` *inside* the select callback for exactly this reason; the enclosing `vim.ui.select` call is still unguarded, and it is a plugin surface — `dressing.nvim`, `telescope-ui-select`, or any user override can throw. Reproduced with a raising picker on the real `recover` path against the fake:

```
REVIEW: claimed=true settled=nil
  ./lua/parley/cliproxy.lua:1160: in function <./lua/parley/cliproxy.lua:1158>
```

Two consequences: (1) `done()` never runs, so the claim sits until the 30s backstop replaces the correct diagnosis with `cliproxyapi: recovery timed out` — precisely the outcome the budget work exists to prevent; (2) `_login_prompt_active` stays `true` for the session, so every later auth failure silently skips the prompt (it still settles via `return done()`, so no second strand — just no prompt). `recover`'s own docstring says "Every path below therefore ends in one of them"; this path doesn't. Fix: wrap the `vim.schedule` body in `pcall`, log the error, and call `done()` on the failure path — mirroring the `vim.cmd` guard one level up. Pin it with a spec that throws from `vim.ui.select`.

**I2 — the behavior the restart rung branches on has no live conformance check (ARCH-MOCK).** `tests/integration/cliproxy_conformance_spec.lua:24-32`

`REQUIRED_FIELDS` pins that `modtime` and `updated_at` *exist* on the real binary, and the fake models the semantics correctly (`fake_cliproxy:104-110`, load time = first sighting of this content). What nothing checks is the semantics itself against the real binary: that a **touch-only** write advances `modtime` and leaves `updated_at` alone. That single fact is the entire missed-fsnotify repair. If a future cliproxy re-stats `updated_at` per request, the fake keeps modelling the old behavior, every test stays green, and the rung silently dies — the exact failure mode this issue hit three times on the same comparison. ARCH-MOCK's at-review lens names this directly: "a missing live conformance check for behavior we depend on". Cheap fix: in the existing `boot()` spec, write the credential, read the record, `fs_utime` the file, re-read, and assert `modtime` moved while `updated_at` did not.

**I3 — two ticked plan steps describe mechanisms the code deliberately rejected, and the M3 review's revision recommendations were not applied.** `workshop/plans/000197-cliproxy-auth-self-healing-plan.md:482, 491` (and `:135`)

- `:482` — `- [x] Step 3 — :ParleyProxy reap SIGTERMs peers **after an identity probe** (reuse port_holds_cliproxy's discipline)`. The code deliberately does not probe: a peer is by definition not on the managed port, so identity comes from `parse_peers`' executable match (`cliproxy.lua:891-895`). The reasoning is right and documented in code; the plan still claims the rejected mechanism, and `:135` repeats it in the integration-points prose.
- `:491` — `- [x] Step 2: Own the URL — run with -no-browser, capture stdout, extract the https://claude.ai/oauth/authorize?… line, vim.ui.open() it`. All four reversed, and reversed *because* they broke every non-claude provider. `cliproxy_login_spec.lua:65-67` asserts `#opened == 0`.

The 2026-08-01 "what actually shipped" block records the `-no-browser` reversal at summary level, but the step text is what a reader greps. Both were raised as plan-revision recommendations by the M3 review and neither was applied — the "bookkeeping deferred is bookkeeping compounded" rule this issue itself added to `lessons.md`. This is the last boundary; after the close the plan is archived as the durable record.

## 4. Minor findings

- `cliproxy.lua:1190` — `@param _retry fun() # unused in M1: this milestone diagnoses, it never repairs`; the parameter is `retry` and drives the whole ladder. Flagged in six prior rounds.
- `cliproxy.lua:417-419` — `credential_health`'s docstring says the compound case is blocked "when `_management_restart_done` shows this claim already restarted the proxy". The shipped guard is `recover`'s per-claim `restarted_this_claim`, precisely because module state could not serve there. The atlas states it correctly; this comment describes the design that was found broken.
- `cliproxy.lua:1255` — "past the dispatcher's 25s backstop"; `dispatcher.lua:30` is `30000`.
- `cliproxy_auth.lua:466` — `auth_file_is_stale(health, proxy_state)` passes a second argument the one-parameter function (`:389`) no longer takes; `:436` still documents `proxy_state` as `{ running, auth_file_modtime }`.
- `cliproxy.lua:905-906` — `reap`'s in-loop comment is inverted ("a process we cannot identify as a proxy **we started** is left alone") and describes a `-config` filter that isn't there. On a function that sends SIGTERM.
- `cliproxy.lua:1010` — `await_credential`'s docstring declares `@param channel string`; the parameter is `login`.
- `cliproxy.lua:225-226` — a key that can't be persisted "just forces a proxy restart next time"; it actually yields a 401 → `management_key_mismatch`, which has **no** repair path (only the 404 does), so that machine reports "state could not be read" indefinitely.
- `run_login`: a login that exits **0** without writing a credential says nothing for the full 180s (`on_exit` settles only on non-zero).
- The rotation-race explanation is hand-copied in two places (`init.lua:463-465`, `cliproxy.lua:885-888`) — ARCH-DRY on operator-facing text, which this repo treats as API.
- `fake_cliproxy:35,162` — "the four ways #197's login could end" / "The four modes"; three remain after `port_taken` was correctly deleted.
- `credential_health_for_login` issues one full `/v0/management/auth-files` request per channel (3 curls + 3 management-key file reads for `google`) where a single response already carries every channel.
- `render_opts()` → `management_key()` does a `mkdir` + file read on **every** call, and sits on `write_rendered_config` → `ensure_running` → every dispatch.
- `stop()` (`:665`) uses a bare `pcall(uv.kill, …)` and counts every pid as killed — the same luv `nil, err` convention `reap()` was fixed for; affects only the "stopped N" notice.
- `tests/fixtures/ps_cliproxy_peers.txt` and `tests/fixtures/cliproxy_auth_files.json` are not registered in `atlas/traceability.yaml`, though other fixtures (`fake_sse_server`, `fake_git_file_list`) are.
- `cliproxy_recovery_e2e_spec.lua:186,195` — `local port = select(2, ("x"):find("x")) -- keep luacheck quiet about unused` plus `assert.is_truthy(port)` is still dead scaffolding (flagged in four rounds); `:118` sets `vim.ui.select` in `before_each` and never restores it.

## 5. Test coverage notes

Verified independently, not from the Log. `make test-spec SPEC=providers/cliproxy-managed`: `cliproxy_auth` 61, `dispatcher_query` 56, `cliproxy_lifecycle` 53, `cliproxy_config` 48, `cliproxy_auth_login` 19, `cliproxy_login` 11, `cliproxy_command` 10, `failure_notice` 6, `providers_pre_query` 6, `cliproxy_caller_teardown` 5, `cliproxy_conformance` 4 (real binary), `cliproxy_recovery_e2e` 4, `cliproxy_budget` 3, `cliproxy_dispatch` 3, `cliproxy_download` 3 — **292 / 0 / 0**. `make lint` 0 warnings / 0 errors in 313 files. One loud SKIP (`ps unavailable — peer detection not exercised`) — a genuine EPERM in my sandbox, which is the degradation `peers()` is written to survive.

Full-suite: `tools_builtin_find_spec` (unit) and `chat_progress_process_spec` / `git_markdown_source_spec` / `markdown_finder_async_spec` (integration) fail under 8-way parallelism and **all four pass individually**; none is touched by this diff (`chat_progress_process_spec` fails on a nil fake-server port). Consistent with the pre-existing flakiness the Log documents at the pre-branch commit — that note should gain `chat_progress_process_spec`, which it doesn't currently name.

Gaps, in the order I'd close them:

1. **Nothing pairs `ensure_running` with a non-empty peer list** (C1). One assertion would have failed the day this landed; three peer specs exist and all of them sidestep the wiring.
2. **`vim.ui.select` raising is untested** (I1) — `vim.cmd` raising is tested, one level deeper.
3. **No live conformance for the `modtime`/`updated_at` gap semantics** (I2).
4. **`:ParleyProxy reap`'s command branch is untested** — not the confirmation list, not the "no peers" message, not that `reap` receives the approved list rather than re-scanning (the code is right; nothing pins it).
5. **`run_login`'s exit-0-without-credential path** — the one that waits three minutes in silence.

The strongest patterns here are worth keeping: the `decide` table-test plus the `attempt >= 1` property sweep, the external-oracle epoch assertions, and the staleness integration test that seeds the load time with a real read before `fs_utime`ing the file rather than fabricating a timestamp.

## 6. Architectural notes

- **ARCH-DRY — pass with nits.** `restart_managed`, `credential_action`, `channels_for_login`, `healthier`, `lstart_sec`, `api_argv`, `split_status`, `SUBS_HELP` (now including `reap`) each have one source and ≥2 live callers. `_stray_spawned` was correctly *deleted* after the deletability check rather than kept. Remaining duplication is prose and per-channel fan-out, not logic.
- **ARCH-PURE — pass.** Reasoning lives in `cliproxy_auth.lua`, execution in `cliproxy.lua`; `recover` is gather-then-`decide`-then-`execute` with no policy in it. Moving `auth_file_is_stale` to read two record fields instead of stat'ing a file is the best structural move in the issue — it removed an IO term from the repair budget *and* fixed the defect. `warn_about_peers` correctly delegates its one comparison to the pure `lstart_sec`.
- **ARCH-PURPOSE — flag.** Shadow sweep on "who infers auth state" is clean: dispatch derives from the management API; `:ParleyProxy models` derives on the correct channel axis; `detect_auth_failure`/`check_auth_failure` and all three hand-maintained restatements of the disproved empty-list inference are gone (only historical comments remain in `lua/`). Done-when items 1, 2, 3, 5 and 6 are delivered and verified. Item 4 is half-delivered: leaked proxies are detected and reapable, but "the rotation-race reason is stated once" is stated zero times (C1) — and prevention *is* M3's purpose, not a separable extension. The issue's `## Outcome` must not ship asserting it works.
- **ARCH-MOCK — flag (I2).** The fake is a real stateful double behind production's own boundaries: a portable credential folder plus a mutable `state.json` overlay over HTTP, captured 7.1.71 error bodies with `_once` transient modes, the 404-without-key behavior, `-h`, and three login modes — all three now driven by specs after the `timeout_ms` injection seam made `hangs` reachable. Production and test share `api_argv`, `jobstart`, and the same routes. The gap is depth, not shape: the one *behavior* the restart rung branches on is modelled by the fake and checked by nobody against the real dependency.
- **Plan-gate carry-forward:** `workshop/plans/000197-cliproxy-auth-self-healing-plan-gate.md` `## Open findings` reads "(none — every finding has been disposed)" — verified on disk. I re-checked each disposition in the code: PQ-1 (404-driven, no config-drift check) ✓, PQ-2 (status gate + property test) ✓, PQ-3 (`model` from `payload.model`, `dispatcher.lua:434`) ✓, PQ-4 (single seam, both old functions gone) ✓, PQ-5 (Task 12 landed, on the channel axis) ✓, PQ-6 (login modes, now all driven) ✓, PQ-7 (`disable-control-panel` default true, `allow-remote` never set, both tested) ✓, PQ-8 (claim contract) ✓, PQ-9 ✓. Nothing to carry.
- **Core-concepts cross-check: no contradictions.** All 14 pure rows and all 19 integration rows verify against the filesystem at their stated paths — `classify_response`/`classify_auth_files`/`diagnosis`/`decide`/`credential_action`/`rfc3339_sec`/`healthier`/`lstart_sec`/`parse_peers` in `cliproxy_auth.lua`; `resolve_channel`/`channels_for_login`/`render` in `cliproxy_config.lua`; `_failure_notice` in `chat_respond.lua`; `management_key`/`auth_files`/`credential_health`/`credential_health_for_login`/`restart_managed`/`peers`/`reap`/`callback_port_blocked`/`await_credential`/`run_login`/`_usage_has_flag`/`recover` in `cliproxy.lua`; `detect_auth_failure` and `check_auth_failure` absent from `lua/`. Every PURE row's tests run without IO (`cliproxy_auth_spec` uses no mocks); every INTEGRATION row is injected or command-invoked. The milestone column makes the table verifiable at each boundary. No plan revision needed for the tables.
- **Docs gate:** `README.md:191` and the `:ParleyProxy` usage list both carry `reap`; `atlas/providers/cliproxy-managed.md` is substantially rewritten for the new surface, links from `atlas/index.md`, and no longer restates the backstop arithmetic (the drift three reviews re-opened). The one atlas sentence that is now false is `:204`, which C1 turns into a claim the code doesn't keep. One gap worth a clause: an operator on `manage = false` now needs `remote-management.secret-key` in their own config to get any diagnosis at all — the atlas says so, the README doesn't.

## 7. Plan revision recommendations

Append a `## Revisions` entry to `workshop/plans/000197-cliproxy-auth-self-healing-plan.md`:

1. **Task 14 Step 3 (`:482`) claims an identity probe that was deliberately not implemented.** Record the shipped rule: identity comes from `parse_peers`' executable-token match, because a peer is by definition not on the managed port and there is nothing to probe against. Fix the same claim in the integration-points prose at `:135`.
2. **Task 15 Step 2 (`:491`) describes the reversed design.** `-no-browser`, the claude-shaped URL extraction, and `vim.ui.open()` were all removed because they broke google/kimi/xai/antigravity. The "what actually shipped" block records the reversal in summary; the step text still reads as the contract and is ticked `[x]`.
3. **Record the peer-warning arming contract precisely** (Task 14 Step 2). "Warns once per session" conflated two concerns onto one latch — "the expensive scan has run" and "the warning has been said" — and C1 is the collision. State that the latch is armed by `warn_about_peers` on every path including zero peers and a raising scan, that `ensure_running` must not pre-arm it, and that the wiring (entry point + non-empty peer list → exactly one warning) is pinned by a test.
4. **Add `chat_progress_process_spec` to the pre-existing-flake note** in the issue `## Log` — it fails under parallel `make test-integration` on a nil fake-server port and passes alone, same class as the two already recorded.
5. **Hold `## Outcome`'s prevention paragraph until C1 is fixed** — as written it states the warning fires on the first dispatch, which the code does not do.
