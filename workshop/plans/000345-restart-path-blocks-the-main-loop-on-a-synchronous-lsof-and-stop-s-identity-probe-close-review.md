# Boundary Review — parley.nvim#345 (whole-issue close)

| field | value |
|-------|-------|
| issue | 345 — Restart path blocks the main loop on a synchronous lsof (and stop's identity probe) |
| repo | parley.nvim |
| issue file | workshop/issues/000345-restart-path-blocks-the-main-loop-on-a-synchronous-lsof-and-stop-s-identity-probe.md |
| boundary | whole-issue close |
| milestone | — |
| window | f3931fb58d00b50a2ec6a7511a06a353c538fdf0..202bafa72fef2bbbb17b96a78027f37850da7fc1 |
| command | sdlc close --issue 345 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T01:46:50-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Diff read; now checking remaining `stop()` callers and the lifecycle spec, then running the tests.

Running the affected specs; the first attempt printed nothing, so I'm checking the raw output.

Setting up the test harness's isolated environment by hand (the system make is too old for `--eval`).

All green. Now the mutation check: making the async read synchronous should turn the responsiveness test red.

Mutation confirmed red and reverted. One last look at the doc comment placement around `stop()`.

Found a likely undercount in the repair budget's `port_release` term. Checking it against the budget spec.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The restart path no longer blocks the main loop. `stop_async` makes the identity probe and listener read async, and `wait_port_released` does its post-exit listener read through `pids_on_port_async`. Both share the lsof argv and parse with the sync `pids_on_port`. I ran the affected specs (lifecycle, auth-login, fixture-lifecycle, cliproxy_budget, repair_work_budget) through the harness environment and all passed. I then made `pids_on_port_async` call the sync read instead: the responsiveness test went red ("the main loop stalled 1597 ms while lsof ran") and so did the timeout test. I reverted that change and the tree is clean.

One thing should be fixed before shipping. The new `port_release` budget term adds the lsof read and the deadline probe as `max(...)`, but they run one after the other, so they should be summed. With the real sum, the "5 s headroom" check in the budget spec would fail. That is the only issue that matters here; everything else is Minor.

**1. Strengths**
- One lsof seam with two drivers: `lsof_argv` and `parse_listener_pids` (lua/parley/cliproxy.lua:928-939) are shared by the sync and async reads. The async driver handles every failure path (lsof missing, `vim.system` raising, timeout) and calls `cb` exactly once.
- A timeout is reported as "lsof timed out" and never as "no listener" (cliproxy.lua:961), so a slow read falls back to the probe. A test pins this behavior.
- The responsiveness test works the way the issue asked: it puts a 1.5 s delay on both reads and uses a 50 ms ticker. I confirmed it fails against a sync read.
- The stop contract specs run against both `stop()` and `stop_async()` (lifecycle_spec:559-609). The wrappers that observe the #340 stall window and the recovery restart were moved to `stop_async` along with the callers. The lesson recorded about stale wrappers that no longer observe anything is a good one.
- `sigterm_all` and `kill_spawned` remove the copy-pasted kill loop from `stop` (ARCH-DRY).

**2. Critical:** none.

**3. Important**
- **`port_release` budget undercounts the post-exit path** (lua/parley/cliproxy.lua:463-465, ARCH-CONSTRAINTS). Worst case:
  1. `exit_poll` sees every pid gone just before the 2 s deadline.
  2. lsof runs until its 2 s limit and reports `lerr`.
  3. `probe_poll` makes one curl call, up to 2 s.

  That is 6 s, but the term is 2 + max(2, 2) = 4. The sum of the terms should be 27 s against `recovery_timeout_ms = 30000`. That leaves 3 s, which fails the "leaves real headroom ≥ 5 s" check in tests/unit/cliproxy_budget_spec.lua. Today the total is exactly 25 s and the check passes only because of the `max`. The comment above the term ("one probe — or this read, whichever is longer") is wrong for the same reason. Three possible fixes:
  - Sum the term (`PORT_RELEASE_MS/1000 + LSOF_MAX_MS/1000 + CURL_MAX_TIME`) and recover the headroom by lowering `LSOF_MAX_MS`. At about 1 s, a timeout still degrades safely to the probe.
  - Bound the lsof wait by the release deadline that is left.
  - Re-derive the backstop.

  Also, `restart_only` in the compound-path check leaves out `stop_listener_read`.

**4. Minor**
- In cliproxy.lua:983-989, the `--- Stop the managed proxy…` doc block and its `---@return` lines now sit above `sigterm_all`. `M.stop` has lost its LuaLS docs, and the annotations attach to the wrong function. Move the block to just above `function M.stop()`.
- ARCH-MOCK: `fake_lsof` keeps no state. It returns `PARLEY_FAKE_LSOF_PIDS` even after the leftover has exited. So the responsiveness test's second read always reports a listener and takes the probe fallback, never the primary `exited` → `start_managed` path. Its assertions still hold, but they don't cover the branch #340 optimized.
- ARCH-ORDER: `stop_async` clears `_spawned` and then waits on an async probe and lsof. During that window, a concurrent `ensure_running` could spawn a fresh proxy, and the lsof read would then SIGTERM it. The window already existed during `wait_port_released`; now it is a little longer. There is no explicit model of this interleaving.
- Callbacks are sometimes sync and sometimes async: `stop_async` (no host/port) and `pids_on_port_async` (lsof missing, or `vim.system` raised) call `cb` synchronously, and on other paths after `vim.schedule`. None of the current callers is affected.
- No test covers responsiveness with a slow identity curl, only with slow lsof. The Done-when item about curl is met by reading the code, not by a test.

**5. Test coverage notes**
- Covered: async listener reads (confirmed by mutation), the lsof time limit, the stop contract under both drivers, and the #340 regressions with their wrappers moved.
- Not covered: a slow identity curl in `stop_async`, and the async `exited` fast path against a stateful lsof fake.
- `parse_listener_pids` is pure but is only tested indirectly.

**ARCH pass/flag**
| Marker | Result |
|---|---|
| ARCH-DRY | pass |
| ARCH-PURE | pass |
| ARCH-PURPOSE | pass: both of `stop()`'s reads moved, and the remaining sync reads are named and justified in the Log |
| ARCH-MOCK | Minor flag (stateless `fake_lsof`) |
| ARCH-CONSTRAINTS | **flag** (budget undercount) |
| ARCH-SECURE | pass: lsof output is parsed with `%d+`, and argv arrays are used throughout |
| ARCH-ORDER | Minor flag (stop window) |
| ARCH-FUNERAL | pass: the only new artifact is a `tempname()` log, which nvim removes |

README needs no update, because `:ParleyProxy stop` adds no new surface. The atlas was updated.

**6. Architectural notes for upcoming work**
- Restart is now a chain of four async steps (stop, probe, lsof, release) with no explicit state model. If more callers or concurrent restarts show up, a small state machine for the restart sequence would make the interleavings testable.

**7. Plan revision recommendations**
- Add a `## Revisions` entry noting that `port_release` must sum the post-exit lsof limit and the deadline probe, and how the headroom is being kept.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: repair-budget-term-derivation
    title: |
      port_release budget uses max(lsof, probe) but the post-exit lsof read and the deadline probe run sequentially
    detail: |
      In wait_port_released, pids can all exit just before the 2 s deadline. The lsof read then runs up to LSOF_MAX_MS (2 s) and probe_poll adds one curl (2 s), so the worst case is 6 s, not the budgeted 2 + max(2,2) = 4 s (cliproxy.lua:463-465). The true sum, 27 s against a 30 s backstop, fails cliproxy_budget_spec's 5 s headroom invariant, which passes today only because of the max. Fix: sum the term and restore headroom, for example by lowering LSOF_MAX_MS or by bounding lsof with the remaining release deadline. Also add stop_listener_read to restart_only.
  - id: new
    severity: Minor
    kind: defect
    family: doc-annotation-placement
    title: |
      M.stop's doc block and @return annotations now attach to sigterm_all
    detail: |
      cliproxy.lua:983-989. Move the --- block to just above function M.stop().
  - id: new
    severity: Minor
    kind: defect
    family: stateless-fake-for-stateful-dependency
    title: |
      fake_lsof keeps reporting the pid after it exits, so the responsiveness test never reaches the exited fast path
    detail: |
      The second listener read always returns the dead leftover pid, so the restart takes the probe fallback instead of start_managed. The test is valid for responsiveness but does not cover the async exited branch.
  - id: new
    severity: Minor
    kind: defect
    family: unmodeled-async-interleaving
    title: |
      stop_async's async probe and lsof window lets a concurrent ensure_running's fresh proxy be found and SIGTERMed
    detail: |
      _spawned is cleared before the async identity probe and listener read. A spawn in that window lands on the port and is reaped. The window existed already during the release wait; it is now slightly longer and is not modeled.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"ca5de75c-3819-4152-a108-620a9606e4c7","repository":"github.com/xianxu/parley.nvim","issue_id":"000345","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/353ea23f56b3b4c1","reviewed_head":"202bafa72fef2bbbb17b96a78027f37850da7fc1","slot":"parley.nvim:4","requested_at":"2026-10-16T08:43:07.9057Z"},"phase":"finished","pid":65260,"started_at":"2026-10-16T08:43:08.449313Z","finished_at":"2026-10-16T08:46:44.461702Z","session_id":"ee69bd4c-d01a-41ca-b30e-af8548055738","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T02:07:26-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 345 — Restart path blocks the main loop on a synchronous lsof (and stop's identity probe) |
| repo | parley.nvim |
| issue file | workshop/issues/000345-restart-path-blocks-the-main-loop-on-a-synchronous-lsof-and-stop-s-identity-probe.md |
| boundary | whole-issue close |
| milestone | — |
| window | f3931fb58d00b50a2ec6a7511a06a353c538fdf0..8787140f9b1204cfc3a255f2a5f9102c2f6097c4 |
| command | sdlc close --issue 345 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T02:07:26-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Prior findings checked against the diff so far; now reading the budget spec and lifecycle tests.

Running the budget spec and the new lsof tests to confirm they pass at head.

Running the mapped cliproxy spec suite through the harness.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The restart path no longer blocks the main loop. `M.stop_async` (`lua/parley/cliproxy.lua:1029`) runs its identity probe and listener read asynchronously. The post-exit listener read in `wait_port_released` is also async, and it gets only the time left before the release deadline (`cliproxy.lua:523-532`). `:ParleyProxy stop` uses the async path too (`init.lua:384`). All 15 spec files mapped to `providers/cliproxy-managed` pass at head through `make test-spec SPEC=providers/cliproxy-managed`, including `cliproxy_budget_spec` and the 63 lifecycle cases. BR-2 and BR-3 are fixed. Two things keep BR-1 open:
- The `restart_only` sum in `tests/unit/cliproxy_budget_spec.lua:31-34` still leaves out the new `stop_listener_read` term, which the prior finding asked for by name.
- No test fails if `exit_poll` stops passing `remaining` to the read. Only the seam's own timeout parameter is pinned.

Neither is a correctness bug at head, so this is FIX-THEN-SHIP, not REWORK.

**1. Strengths**
- `cliproxy.lua:930-943`: the sync and async readers share one argv (`lsof_argv`) and one parser (`parse_listener_pids`). `sigterm_all` and `kill_spawned` remove the copy-pasted kill loop between `stop` and `stop_async`.
- `cliproxy.lua:968-970`: an lsof timeout (code 124) is reported as the error `"lsof timed out"`, never as "no listener", so a timeout never looks like a released port.
- `tests/fixtures/fake_lsof` now models state: it lists only pids that are still alive. The responsiveness test asserts both reads (`{"listed: <pid>", "listed: "}`), so it now covers the exited fast path, and it bounds the main-loop gap at under half the read time.
- The `stop`/`stop_async` contract specs are parameterised over both drivers (lifecycle spec around line 579).
- The fix for the wrappers that stopped testing anything (stall window, `stops == 0`) is carried over to `stop_async`, and the lesson is recorded in `workshop/lessons.md`.

**2. Critical findings:** none.

**3. Important findings:** none new. BR-1 is re-raised through its disposition below.

**4. Minor findings:** none new. BR-4 stays open as an accepted risk.

**5. Test coverage notes**
- BR-1's call-site half (`remaining` passed into `pids_on_port_async` at `cliproxy.lua:531`) is checked only by reading the code. A test needs a proxy that exits close to the deadline, plus a fake lsof slower than the time left. The implementer notes that the exit-delay knob is being retired by #343. If no test is practical, record that explicitly as an accepted gap rather than a fix.
- The budget unit spec can't tell whether `restart_only` is complete, because the compound assertion uses `>`. A missing term only makes that check easier to pass.

**6. Architecture**

| Principle | Result |
|---|---|
| ARCH-DRY | **Pass.** One argv and parse; shared `sigterm_all` and `kill_spawned`. |
| ARCH-PURE | **Pass for this scope.** `parse_listener_pids` is pure. The IO stays at the lsof seam (`_set_process_tools`). |
| ARCH-PURPOSE | **Flag (inside BR-1).** `restart_only` is a hand-written list of the restart's budget terms and has drifted from the derived `_repair_budget_sec`. Build it from named keys shared with production, or add the term. |
| ARCH-MOCK | **Pass.** `fake_lsof` sits behind the same seam as production, now tracks liveness, and is registered in the fixture-lifecycle corpus. |
| ARCH-CONSTRAINTS | **Pass.** The read is capped (`LSOF_MAX_MS`, plus the time left), it is now included in the budget, and main-loop responsiveness is measured. |
| ARCH-SECURE | **Pass.** argv array, no string interpolation into a shell; an lsof failure counts as unread, not as a fabricated "empty". |
| ARCH-ORDER | **Flag (BR-4, accepted).** `_spawned` is cleared before the async window, and a concurrent spawn in that window is not modeled. |
| ARCH-FUNERAL | **Pass.** No durable artifacts. The test log file is a tempname. |

**7. Plan revision recommendations**
- Add a `## Revisions` entry saying the `exit_poll → remaining` wiring has no restart-level regression test, and why (it waits on #343's exit-delay retirement).
- Record that `restart_only` in the budget spec now includes `stop_listener_read`, or why it shouldn't.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      The stacking is fixed in code (cliproxy.lua:523-532 passes the time left, port_release is deadline + one probe again), and the seam test pins the timeout parameter. Two things remain. First, restart_only in tests/unit/cliproxy_budget_spec.lua:31-34 still omits stop_listener_read, which the finding asked for explicitly; it should be derived from shared key names, not hand-listed (repair-budget-term-derivation). Second, no test fails if exit_poll stops passing remaining. Add the term, then either add a near-deadline restart test or record the untested wiring as an accepted gap in the plan.
  - id: BR-2
    disposition: addressed
    note: |
      cliproxy.lua:1009-1016: the M.stop doc block and @return lines sit directly above function M.stop; the helpers moved above the block.
  - id: BR-3
    disposition: addressed
    note: |
      fake_lsof filters to live pids, and the responsiveness test asserts the reads list the leftover and then nothing, so the exited fast path is covered; passes at head.
  - id: BR-4
    disposition: not-addressed
    note: |
      Accepted, not fixed (issue log). Minor and non-blocking: a dispatch's ensure_running racing an explicit restart can still be reaped in stop_async's async window.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"566a4c6c-d8cf-4d03-8585-f4e06ebbcba4","repository":"github.com/xianxu/parley.nvim","issue_id":"000345","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/d36c0dfe34d038d1","reviewed_head":"8787140f9b1204cfc3a255f2a5f9102c2f6097c4","slot":"parley.nvim:4","requested_at":"2026-10-16T09:03:42.418734Z"},"phase":"finished","pid":26188,"started_at":"2026-10-16T09:03:42.712443Z","finished_at":"2026-10-16T09:07:24.876979Z","session_id":"f7753cf0-0181-4254-9c77-3535742cb93f","outcome":"returned"}] -->
