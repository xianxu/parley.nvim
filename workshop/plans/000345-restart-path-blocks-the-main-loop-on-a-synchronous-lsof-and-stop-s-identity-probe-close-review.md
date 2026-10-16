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

---

## Re-review — 2026-10-16T02:20:57-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 345 — Restart path blocks the main loop on a synchronous lsof (and stop's identity probe) |
| repo | parley.nvim |
| issue file | workshop/issues/000345-restart-path-blocks-the-main-loop-on-a-synchronous-lsof-and-stop-s-identity-probe.md |
| boundary | whole-issue close |
| milestone | — |
| window | 53be0c7ba673bb3aa243f05174d3719481259086..a3777a50afddb42c05796f811641dd8516a57c9d |
| command | sdlc close --issue 345 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T02:20:57-07:00 |
| verdict | SHIP |

## Review

Reviewing the #345 diff; next I'll run the budget and lifecycle specs, then revert the BR-1 fix to confirm a test fails without it.

Lifecycle spec ran; checking full output (my runner truncated it), then reverting the BR-1 fix.

Now the mutation: drop the `remaining` limit from the post-exit read.

BR-1's fix goes red when reverted. Now running the auth-login spec, the other spec this diff touched.

```verdict
verdict: SHIP
confidence: high
```

**Verdict: SHIP.** The restart path now does its listener reads and its identity probe asynchronously. Each lsof call is capped at `LSOF_MAX_MS`, and a read that times out counts as unread rather than "no listener". The post-exit read now gets only the time left before the release deadline, so it and the fallback probe can no longer run back to back (BR-1). I checked BR-1 by reverting the fix (`end, remaining)` → `end)` at `lua/parley/cliproxy.lua:536`) and re-running the lifecycle spec. Exactly one test fails: "the release wait never runs its listener read past the deadline", which reports "the wait decided at 3789 ms". With the fix back, all specs pass: the lifecycle spec (64/0), cliproxy_budget_spec (3/0), cliproxy_auth_login_spec (21/0) and fixture_lifecycle_spec (4/0). The budget now adds up to 25 s against the 30 s backstop, exactly the 5 s headroom the spec requires. Only Minor findings remain: BR-4, which the author accepted as a known risk, and one misplaced doc comment.

1. **Strengths**
   - One lsof seam with two drivers: `lsof_argv` and `parse_listener_pids` (`cliproxy.lua:939-950`) are shared by the sync and async reads (ARCH-DRY).
   - A timeout returns `"lsof timed out"`, not an empty list (`cliproxy.lua:973-975`). A read that never answered is never taken as "port free".
   - `_restart_budget_keys` names the terms a restart spends, and the budget spec sums them and checks each key exists. This replaces a hand-written list that had already left out a term.
   - `fake_lsof` checks whether each pid is still alive and logs what it printed. The responsiveness test can therefore prove the restart took the exit-confirmed path (`listed: <pid>`, then `listed: `).
   - The stop contract tests now run against both `stop()` and `stop_async()`. The lesson about tests that wrap the old function is real: no product-side `cliproxy.stop =` wrappers remain, and the remaining sync `stop()` calls are all teardown.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - **Misplaced doc comment** (`cliproxy.lua:933-938`): the doc block for `pids_on_port` ("PIDs listening on `port`…") now sits above `lsof_argv`, because the new helpers were inserted between the comment and the function it describes. This is the 2nd finding in family `doc-annotation-placement` (BR-2 was the 1st). The rule that covers both: a new helper goes above an existing doc block, never between the block and its definition. I swept every insertion in this diff. `sigterm_all`/`kill_spawned`, `M._wait_port_released`, `_restart_budget_keys`, the `LSOF_MAX_MS` constant and the `port_release` comment are all placed correctly, so this is the only remaining instance.
   - **Stale prose in the `wait_port_released` header** (`cliproxy.lua:487-496`): it still says "M.stop() returns immediately" and "the pids stop() signalled". The caller is now `stop_async`.
   - **BR-4 is still open:** the async window during which a concurrent spawn can be reaped is unchanged. The Log records it as an accepted risk.

5. **Test coverage notes**
   - The responsiveness test asserts a maximum tick gap under 750 ms across two 1.5 s reads, plus the lsof log contents. This meets the "Done when" item.
   - The time limit is covered twice: once at the default limit and once with a 300 ms limit passed in.
   - The deadline pass-through is tested end to end, and that test fails when the fix is reverted (see above).
   - Dropping `stop_listener_read` from `_restart_budget_keys` would not fail any test, because the compound case only asserts `>`. That is acceptable: the spec still catches a key that names no real term.

6. **Architecture**
   - ARCH-DRY: pass. The lsof argv and parse are shared, and the kill helpers are shared by both stops.
   - ARCH-PURE: pass. `parse_listener_pids` is pure, and the IO stays in the two thin drivers.
   - ARCH-PURPOSE: pass. Every caller on the restart path (`restart_managed`, `:ParleyProxy stop`) uses the async versions. The remaining sync reads are named and justified in the Log.
   - ARCH-MOCK: pass. `fake_lsof` sits behind the existing `_set_process_tools` seam and models whether each listener is still alive. A live conformance check for lsof was already missing before this diff, and the change doesn't make that worse.
   - ARCH-CONSTRAINTS: pass. lsof is bounded, the release read is clamped to the deadline, and the budget is derived from constants and checked by the spec.
   - ARCH-SECURE: pass. The pids are parsed into numbers, and the argv is passed as an array.
   - ARCH-ORDER: flag (Minor, BR-4). The `stop_async` window against a concurrent `ensure_running` is not modeled. Two concurrent restarts were already unmodeled before this diff.
   - ARCH-FUNERAL: pass. Nothing durable is created; the test's lsof log is a `tempname()` file.

7. **Plan revisions:** none. The plan's Core-concepts table matches the code; I checked every listed entity at its stated path.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      The post-exit read is passed `remaining` (cliproxy.lua:536), stop_listener_read is in _restart_budget_keys, and the budget totals 25 s against 30 s. Reverting the pass-through fails "the release wait never runs its listener read past the deadline" (3789 ms); restored, all specs pass.
  - id: BR-4
    disposition: not-addressed
    note: |
      Still present. The Log accepts it as a known risk (an explicit restart racing a dispatch's spawn). Minor, non-blocking; it should become its own issue if kept.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: doc-annotation-placement
    title: |
      The pids_on_port doc block now sits above lsof_argv, separated from pids_on_port by the new helpers
    detail: |
      cliproxy.lua:933-938. 2nd instance in this family (after BR-2). The rule: insert a new helper above an existing doc block, never between the block and its definition. A sweep of every insertion in this diff found no other instance. Fix: move lsof_argv and parse_listener_pids above the "PIDs listening on `port`" comment. Separately, the wait_port_released header (lines 487-496) still names M.stop() where the caller is now stop_async.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"676f8dbb-ed64-49e8-9fd6-fc7a25e47a11","repository":"github.com/xianxu/parley.nvim","issue_id":"000345","recipe":"milestone-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/425de50f60fda53b","reviewed_head":"a3777a50afddb42c05796f811641dd8516a57c9d","slot":"parley.nvim:4","requested_at":"2026-10-16T09:17:17.228735Z"},"phase":"finished","pid":16716,"started_at":"2026-10-16T09:17:17.47803Z","finished_at":"2026-10-16T09:20:53.037786Z","session_id":"925103fa-19d7-490f-bb3d-029c4e1f018e","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T03:37:10-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 345 — Restart path blocks the main loop on a synchronous lsof (and stop's identity probe) |
| repo | parley.nvim |
| issue file | workshop/issues/000345-restart-path-blocks-the-main-loop-on-a-synchronous-lsof-and-stop-s-identity-probe.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0a616029f43d1a239f5a46bb3fc0b42a129dcd9a..04169ca621b7b7c6faa94adfda2bdea4eb90ced4 |
| command | sdlc close --issue 345 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T03:37:10-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reviewing the #345 diff; now running the affected specs to verify.

Affected specs pass; running one mutation check (interactive reads made sync).

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The option-B change works and is well tested. `:ParleyProxy restart` and `:ParleyProxy stop` no longer block the editor on lsof or the identity curl. The budgeted paths (the in-dispatch repair at `cliproxy.lua:1769`, `update` at `:649` and the recovery rung at `:2396`) keep #340's sync reads, which is why the budget is unchanged. The affected specs pass on the pinned head: budget 3/3, lifecycle 63/63, auth_login 21/21, fixture_lifecycle arch 4/4. I ran the claimed mutation: giving the interactive restart sync reads fails 2 lifecycle cases, as the Revisions entry says, and I restored the file afterwards.

One Important finding stops this from being a plain SHIP. Parts of the issue file still describe option A, which the code no longer implements: the Plan checkboxes, the Core-concepts `stop` row, and the Log's list of remaining sync reads. The rest is Minor: two prior Minors are still open, and one new error message is dropped.

1. **Strengths**
   - `READS` at `cliproxy.lua:549-558` routes every restart read through one table, and the lookup happens at call time. The difference between sync and interactive restarts is easy to read, and specs that wrap `M.stop` still observe the budgeted path.
   - The ARCH-DRY split works: `lsof_argv` and `parse_listener_pids` are shared by both drivers, and `sigterm_all` and `kill_spawned` are shared by `stop` and `stop_async`.
   - An lsof timeout reports `"lsof timed out"`, not an empty listener list (`cliproxy.lua:995-997`). Both `stop()` and `stop_async()` now return `read_err`, and the restart turns it into a truthful "was not stopped" message (`:577-582`). Both points are pinned by tests.
   - `fake_lsof` only lists pids that are still alive. The responsiveness test checks both reads (`"listed: <pid>"` then `"listed: "`), so it really covers the exit-confirmed path.
   - `_restart_budget_keys` gives the restart budget one source, and `cliproxy_budget_spec` checks that every key is a real budget term.

2. **Critical:** none.

3. **Important**
   - **The issue file still describes option A** (`workshop/issues/000345-…md`). Four places disagree with the code:
     - The Core-concepts `stop` row says "Kept for spec teardown". In fact `READS.sync.stop` calls `M.stop()` on all three budgeted product paths.
     - The Plan item "`restart_managed` uses `stop_async`, and `wait_port_released`'s post-exit check uses `pids_on_port_async`" is ticked `[x]`. It is only true when `{ interactive = true }` is passed.
     - The Log says "The sync `stop()`: spec teardown only; no product caller remains". That is false.
     - The Log also says "The restart path now has no main-loop lsof or curl". Done-when #1 asks for every remaining sync read to be named and justified. The sync identity curl (`port_holds_cliproxy`, up to 2 s) and the sync lsof in `M.stop()` on the budgeted paths are justified only in the Revisions entry, not in that list.
     - Fix: rewrite those Plan items and the `stop` row for option B, and add the budgeted-path sync reads to the "Remaining sync reads" list. The rule is that whenever a Revisions entry changes the design, every Plan, Core-concepts and Log claim that names the replaced mechanism gets swept in the same commit.

4. **Minor**
   - **`:ParleyProxy stop` drops `read_err`** (`init.lua:384`). When the probe finds a cliproxy but lsof times out or fails, the user sees "stopped 0 parley-spawned proxy(ies)" and is never told that a proxy is still running. The restart path reports this case; the stop command should too, for example with a WARN that names `read_err`.
   - **BR-5 (still open):** see the dispositions below.
   - **BR-4 (still open):** see the dispositions below.

5. **Test coverage**
   - Covered:
     - Responsiveness, with a 50 ms ticker and a gap limit below half the delay.
     - The hang guard.
     - An lsof timeout leading to the "not stopped" message.
     - The `stop` contract run over both drivers.
     - #340's regressions on the sync path, with their wrappers kept on `M.stop` (correct under option B).
   - Missing: nothing tests that `register_proxy_command`'s `restart` passes `{ interactive = true }`. Removing that argument would bring the freeze back on the user command without failing a test. Consider a command-level spec that wraps `restart_managed` and asserts on `restart_opts`.

6. **Architecture**
   - **ARCH-DRY:** pass.
   - **ARCH-PURE:** pass. `parse_listener_pids` is pure, and the IO sits in two thin drivers.
   - **ARCH-PURPOSE:** pass in the code; the sweep that matters is enumerating every caller of the restart. The interactive and budgeted callers are each named, but the plan text has not been swept (the Important finding above).
   - **ARCH-MOCK:** pass. `fake_lsof` is stateful because it checks whether each pid is alive, and it sits behind the `_set_process_tools` seam that production uses too. There is no live conformance check against the real lsof's output format, which was already true before this change.
   - **ARCH-CONSTRAINTS:** pass. The interactive path has a 10 s guard and no budget, and the budgeted paths are unchanged and were measured 8 of 8 green under load.
   - **ARCH-SECURE:** pass, apart from the dropped `read_err` (Minor above). lsof output is parsed with a `%d+` pattern, and a timeout is never read as "no listener".
   - **ARCH-ORDER:** flag, via BR-4. The interleaving between `stop_async` and `ensure_running` is not modelled. It is accepted in the Log and limited to the interactive commands.
   - **ARCH-FUNERAL:** pass. The only new artifact is `PARLEY_FAKE_LSOF_LOG`, a test `tempname`. Nothing durable is created.

7. **Plan revisions needed**
   - Change the Core-concepts `stop` row to: "The sync stop: used by the budgeted restart paths (in-dispatch repair, recovery rung, update) and by spec teardown; returns `read_err`."
   - Change the Plan item to: "`restart_managed(…, { interactive = true })` uses `stop_async` + `pids_on_port_async`; the default keeps sync `stop()` + `pids_on_port`."
   - In the Log's "Remaining sync reads", replace the "spec teardown only" bullet with the budgeted-path sync identity curl and lsof, with the reason (lsof is over 2 s under load, and a cap pushes those paths onto the stalling probe).

```findings
dispose:
  - id: BR-4
    disposition: not-addressed
    note: |
      No code change. The Log accepts the window and option B now confines it to the interactive commands, but it is still not modelled. Stays Minor.
  - id: BR-5
    disposition: not-addressed
    note: |
      At head, cliproxy.lua:951-967 still puts lsof_argv/parse_listener_pids between the "PIDs listening on `port`" doc block and pids_on_port, and the wait_port_released header (line 487) still says "M.stop() returns immediately".
findings:
  - id: new
    severity: Important
    kind: defect
    family: plan-stale-after-revision
    title: |
      The issue's Plan, Core-concepts stop row and Log still describe option A after the option-B revision
    detail: |
      The Core-concepts `stop` row says "Kept for spec teardown" and the Log says "no product caller remains", yet READS.sync.stop (cliproxy.lua:551) calls M.stop() from credential_health (:1769), recovery (:2396) and update (:649). The ticked Plan item says restart_managed uses stop_async. Done-when #1's list of remaining sync reads leaves out the budgeted paths' sync identity curl and lsof. Sweep every Plan, Core-concepts and Log claim naming the replaced mechanism.
  - id: new
    severity: Minor
    kind: defect
    family: read-error-dropped-by-caller
    title: |
      :ParleyProxy stop ignores stop_async's read_err and reports "stopped 0"
    detail: |
      init.lua:384 only takes `n`. When the probe found a cliproxy but lsof timed out or failed, the proxy keeps running and the user is not told, while the restart path reports the same case. Notify a WARN that names read_err.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"2aa09c87-03de-4e7c-be03-8aab438f1937","repository":"github.com/xianxu/parley.nvim","issue_id":"000345","recipe":"milestone-review","round":4,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/0365519ebe104a7a","reviewed_head":"04169ca621b7b7c6faa94adfda2bdea4eb90ced4","slot":"parley.nvim:4","requested_at":"2026-10-16T10:34:31.205247Z"},"phase":"finished","pid":89081,"started_at":"2026-10-16T10:34:31.342914Z","finished_at":"2026-10-16T10:37:09.078519Z","session_id":"f2d84c91-b57b-4b3b-97da-babecfe8098d","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T03:54:04-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 345 — Restart path blocks the main loop on a synchronous lsof (and stop's identity probe) |
| repo | parley.nvim |
| issue file | workshop/issues/000345-restart-path-blocks-the-main-loop-on-a-synchronous-lsof-and-stop-s-identity-probe.md |
| boundary | whole-issue close |
| milestone | — |
| window | 8c81d753ada87aabd2b691f54a600bb813d02c55..383e8a4aab82ca42ece2df4cd98c3aa9e365aebd |
| command | sdlc close --issue 345 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T03:54:04-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I've read the window's diff. Next I'll run the command spec and do a quick mutation check on the BR-7 fix.

The spec passes, and it goes red when the BR-7 WARN is removed. Next I'll check that removing the `{ interactive = true }` argument also fails the test.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

This round's code fixes are correct and tested. The **BR-7** fix (`init.lua:384-391`) makes `:ParleyProxy stop` WARN and name `read_err` when a cliproxy on the port could not be listed. The **BR-5** fix moves `pids_on_port`'s doc block back onto it (`cliproxy.lua:966-970`), and the `wait_port_released` header now names both stops. I ran the command spec in the harness on the pinned head and it passes. I then ran two mutations: changing `if read_err` to `if false` fails the new WARN case, and replacing `{ interactive = true }` with `nil` fails the restart command case. That closes the coverage gap round 4 noted. I restored the tree afterwards (`git status` clean).

One thing keeps this from a plain SHIP. **BR-6** is only partly fixed. The new Revisions entry says every stale claim was swept, but the Log's headline sentence that round 4 quoted is still there and unmarked: "The restart path now has no main-loop lsof or curl" (issue line 105). Under option B the budgeted restarts do read lsof and curl synchronously on the main loop. The fix is a one-line "Superseded" note. The Revisions change records fixes only, so the scope has not changed.

1. **Strengths**
   - The WARN wording in `init.lua:388-390` matches the restart path's "was NOT stopped" message, and it reports the count alongside the reason.
   - The stop command spec covers both the INFO and the WARN branch, using the stub-and-restore pattern the file already uses (`cliproxy_command_spec.lua:200-220`).
   - The restart command test now pins `{ interactive = true }`, and removing it fails the test (checked by mutation).
   - The rule in `lessons.md` covers the whole `doc-annotation-placement` class (all four instances), not just this one site.
   - The "Superseded by option B" notes are dated and added alongside the old text, so the history survives (issue lines 82, 84, 87, 93, 108, 110, 111).

2. **Critical:** none.

3. **Important**
   - **BR-6 (not addressed):** the issue file still says "The restart path now has no main-loop lsof or curl" (line 105). That is false for the in-dispatch repair, the recovery rung and update. Fix: append "*(Superseded by option B, see ## Revisions: only the interactive commands are off the main loop; the budgeted paths keep sync reads.)*". Optionally also annotate line 80's `cb(count, pids)`, which is now `(count, pids, read_err)`.

4. **Minor**
   - **BR-4:** still not modelled and still accepted in the Log (Minor, no change this round).
   - The rewrapped `wait_port_released` header line (`cliproxy.lua:487`) runs past the surrounding comment width. This is a style nit only and is not raised as a finding.

5. **Test coverage:** The two new command cases and the new `restart_opts` assertion each fail under the matching mutation. No gaps remain in this window.

6. **Architecture**
   - **ARCH-DRY:** pass.
   - **ARCH-PURE:** pass. The WARN lives in the thin command layer and only formats what `stop_async` returns.
   - **ARCH-PURPOSE:** the code fixes cover their whole class (`read_err` is now honoured by every caller of `stop_async`: the restart and the stop command). The BR-6 prose sweep is incomplete, as above.

7. **Plan revisions:** annotate Log line 105 as superseded. Nothing else is needed.

```findings
dispose:
  - id: BR-4
    disposition: not-addressed
    note: |
      No code change in this window. The race is still accepted in the Log and limited to the interactive commands, but it is not modelled. Stays Minor.
  - id: BR-5
    disposition: addressed
    note: |
      At head, cliproxy.lua:966-970 puts the "PIDs listening on `port`" doc block directly above pids_on_port, with lsof_argv and parse_listener_pids above it. The wait_port_released header (487-488) names both M.stop() and M.stop_async(). The lessons.md rule covers the class.
  - id: BR-6
    disposition: not-addressed
    note: |
      Partly fixed: the stop row, the Plan items, two Log bullets and the Done-when list are corrected. But Log line 105, "The restart path now has no main-loop lsof or curl", which round 4 quoted, is still unmarked and false for the budgeted paths. The Revisions claim that every stale claim was swept is therefore inaccurate. Fix: one Superseded note.
  - id: BR-7
    disposition: addressed
    note: |
      init.lua:384-391 WARNs and names read_err. The new spec case fails when the branch is disabled (if read_err changed to if false), verified in the harness and then restored.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d5bcbd80-11c9-4530-9ed4-42def1e16b8f","repository":"github.com/xianxu/parley.nvim","issue_id":"000345","recipe":"fix-review","round":5,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/0eb114a3d86121d2","reviewed_head":"383e8a4aab82ca42ece2df4cd98c3aa9e365aebd","slot":"parley.nvim:4","requested_at":"2026-10-16T10:52:47.259756Z"},"phase":"finished","pid":32088,"started_at":"2026-10-16T10:52:47.419756Z","finished_at":"2026-10-16T10:54:03.623907Z","session_id":"1639a0fa-2252-43dd-bf4f-09d3db300f44","outcome":"returned"}] -->
