# Boundary Review — parley.nvim#293 (milestone M1)

| field | value |
|-------|-------|
| issue | 293 — writer_folds tool test flakes: tool round continuation sometimes misses the 5s wait |
| repo | parley.nvim |
| issue file | workshop/issues/000293-writer-folds-tool-test-flake.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | fbade52193d887f1fc9cb91597b34cb3532ddf69..a1af32027b332dd2a4adfae83ec2894aa810887b |
| command | sdlc milestone-close --issue 293 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-27T20:18:03-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M1 does what the plan says: it adds guards and does not fix the cause. The progress-aware wait (`tests/helpers/await.lua:45-56`) is small and correct, and it has its own unit spec. The deterministic work-budget spec is committed `pending` with its baselines recorded. I switched both pending cases to `it` in a scratch copy and ran it. Both fail at exactly the Log's baselines (`summary_values_copied 483057 > 96000`, `queried 256 rows to draw 9`), so they are real red guards for M2 and M3. The PROBE instrumentation is gone and the atlas was updated. On the pinned HEAD: `await_helper_spec` passes 3/3, `writer_folds_spec` passes 5/5, and `repair_work_budget_spec` has 0 run (both pending).

Two cheap problems keep this from SHIP:
1. The new `wait_for` applies a 1-second stall window to every wait in `writer_folds_spec`, including waits that do no repair. For those waits the old 5-second tolerance silently becomes 1 second, a new flake risk under `make test`.
2. The helper's own unit spec depends on wall-clock timing with 100 ms margins.

## 1. Strengths
- The wait counts only productive repair steps (`event.result.status=='more'`, `writer_folds_spec.lua:74-78`). This matches the document's own notify path (`document/init.lua:435,456`), and idle pump polls don't count as progress.
- The budget spec uses counters instead of wall time and drains synchronously with `D.drain`, so no redraw adds noise. The index work is measured on its own and cannot flake.
- Following PQ-1, the index case budgets only `summary_values_copied`, the counter M2's combine change moves. The highlighter case measures rows queried through a real window and a real closed fold, with a pcall-guarded spy that restores `D.query` before asserting.
- `until_progress` reports why it failed (`stalled` or `ceiling`), and the unit spec covers all three outcomes.

## 2. Critical
None.

## 3. Important
- **`tests/integration/writer_folds_spec.lua:61-64`: the 1 s stall also governs waits that do no repair.** `wait_for` is also used for `#calls>0` (line 101), `status=='terminal'` (line 110) and `F.flush(buf)=='idle'` (line 111). Those waits may see no productive repair step at all, so under load their budget drops from 5 s to 1 s. Fix: use a stall window of at least the old 5000 ms. A stall only delays failure reporting, because the predicate is still polled every 1 ms. Alternatively, keep a plain `vim.wait(5000)` for waits that aren't gated on repair.
- **`tests/unit/await_helper_spec.lua:16-39`: the helper's spec is a wall-clock oracle (ARCH-ORDER).** Progress comes from a real 10 ms timer checked against a 100 ms stall window, plus `< 1000 ms` and ceiling assertions. On a loaded runner, a descheduled process can come back and read `progress()` before the coalesced `schedule_wrap` callback runs. The "settles" case then reports `stalled`, a flake in the spec for a flake fix. Fix: inject a clock and wait into `until_progress` (optional arguments that default to `uv.now`/`vim.wait`) and drive the cases deterministically. The cheaper option is to widen the margins well past scheduler jitter (e.g. 1000 ms stall for the settle case).

## 4. Minor
- `repair_work_budget_spec.lua:81`: `drawn + 21` restates `HIGHLIGHT_VIEWPORT_MARGIN (20) + 1` (ARCH-DRY). Expose the constant or name it locally.
- `atlas/infra/test_harness.md`: "a stuck run reports instead of being killed silently" only holds per wait. The file has several waits, each with its own 40 s ceiling, so their sum can still pass plenary's 50 s limit.
- `until_progress` compares progress with `~=`, so a table-valued progress always looks like it moved. The doc says "a value"; consider saying "a scalar".
- `repair_work_budget_spec.lua:7`: `tmp_dir` (made per run with `os.time()`) is never removed (ARCH-FUNERAL). Other integration specs do the same.

## 5. Test coverage notes
- Both budget cases are pending, so the M1 range asserts no index or highlighter behaviour yet. That is by design, and I confirmed red above. M2 and M3 must turn them into `it`.
- None of this proves the Done-when 50/50 target; that is deferred to final verification, which is fine at M1.

## 6. Architectural notes
- ARCH-DRY: minor (the margin constant).
- ARCH-PURE: passes. `until_progress` takes its predicate and progress as functions; its only effects are the clock and `vim.wait`, which are also the hook for making its spec deterministic.
- ARCH-PURPOSE: passes. M1 is openly the guards milestone; the root-cause fix is M2/M3 and not deferred as follow-up.
- ARCH-MOCK: N/A. There is no external dependency; the `D.query` spy is a counter around the real function, not a stand-in.
- ARCH-CONSTRAINTS: passes. The budgets are counters with recorded baselines.
- ARCH-SECURE: N/A (test-only code with no untrusted input or secrets).
- ARCH-ORDER: flagged (the helper spec's timing oracle).
- ARCH-FUNERAL: minor (the leftover tmp dir). The subscription is removed in `after_each`, and the timer is stopped and closed.
- For M3: the drawn-rows case covers a fold at the end of the buffer only. PQ-3 also plans a fold in the middle and a toggle case.

## 7. Plan revision recommendations
- Task 1 Step 3 says "expect FAIL", but the spec was committed `pending` (Step 5 allows this). Add a Revisions note that red was confirmed by running the cases unpended, with the numbers.

```findings
findings:
  - id: new
    severity: Important
    family: wait-budget-tightened-for-ungated-waits
    title: |
      writer_folds wait_for applies a 1s repair-stall window to waits not gated on repair
    detail: |
      The waits for calls>0, response terminal and flush idle may see no productive repair step, so their effective timeout drops from 5s to 1s under make test load. Use stall_ms of at least 5000, or keep a plain vim.wait for waits not gated on repair.
  - id: new
    severity: Important
    family: wall-clock-test-oracle
    title: |
      await_helper_spec depends on real-timer and wall-clock margins of 100ms (ARCH-ORDER)
    detail: |
      A descheduled process can read progress before the coalesced scheduled tick runs, so the settle case reports stalled. Inject the clock and wait into until_progress, or widen the margins well past scheduler jitter.
  - id: new
    severity: Minor
    family: restated-constant
    title: |
      repair_work_budget_spec hard-codes 21 for HIGHLIGHT_VIEWPORT_MARGIN + 1 (ARCH-DRY)
  - id: new
    severity: Minor
    family: doc-overclaims-guarantee
    title: |
      atlas says the 40s ceiling prevents silent kills, but it only holds per wait, not per file
  - id: new
    severity: Minor
    family: test-residue-cleanup
    title: |
      repair_work_budget_spec creates a tmp_dir per run and never removes it (ARCH-FUNERAL)
```

---

## Re-review — 2026-09-27T20:20:11-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 293 — writer_folds tool test flakes: tool round continuation sometimes misses the 5s wait |
| repo | parley.nvim |
| issue file | workshop/issues/000293-writer-folds-tool-test-flake.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | fbade52193d887f1fc9cb91597b34cb3532ddf69..d19dcba53ca6bc3b3e86857795f286960f379ff6 |
| command | sdlc milestone-close --issue 293 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-27T20:20:11-07:00 |
| verdict | SHIP |

## Review

I've checked all five open findings against the code and run the affected specs. The dispositions follow.

```verdict
verdict: SHIP
confidence: high
```

All five prior findings are fixed at HEAD `d19dcba`. `writer_folds_spec` now waits with a 5000 ms stall window, the same as the old fixed budget. `until_progress` takes an injectable clock and wait (`env`), so its unit spec runs on a fake clock and its asserted times are exact. The margin constant is now exposed as `highlighter._VIEWPORT_MARGIN` and the spec uses it. The atlas now says the 40 s ceiling bounds one wait, not the whole file. The budget spec deletes its tmp dir on `VimLeavePre`.

I ran the specs on HEAD: `await_helper_spec` passes 4/4, `writer_folds_spec` passes 5/5, and `repair_work_budget_spec` has 2 pending cases, as designed. That run left no new `parley-test-repair-budget-*` directory. The four leftover directories in `$TMPDIR/claude` are timestamped 20:15–20:17, before the fix commit at 20:19. I found no new problems.

1. **Strengths**
   - `tests/helpers/await.lua:51-63`: the `env` seam defaults to libuv `now` and `vim.wait`. The production path and the test path go through the same function, so the spec checks real logic rather than a mock (ARCH-ORDER, ARCH-MOCK).
   - `tests/unit/await_helper_spec.lua:48-53`: a new case pins the contract behind the BR-1 fix: a wait that sees no progress gets exactly the stall window (5000 ms on the fake clock).
   - `writer_folds_spec.lua:57-66`: the comment explains why the stall window is 5 s, so a later edit is unlikely to tighten it again by accident.
   - `highlighter.lua:998`: the test seam points at the single source of the constant instead of restating it (ARCH-DRY).

2. **Critical:** none.
3. **Important:** none.
4. **Minor:** none new. The shared `$TMPDIR/claude/parley-test-*-os.time()` naming, found in 23 other specs, predates this work. The harness's per-run `TMPDIR` sweep covers those specs, so I'm not raising it.
5. **Test coverage:** `until_progress` has four deterministic cases covering settle, stall, ceiling and no progress. Nothing tests the specific 5000 value in `writer_folds_spec`. It is a test-configuration choice, and the helper contract it relies on is tested. The budget cases stay pending as guards for M2 and M3; the prior round showed they fail at the recorded baselines.
6. **Architecture:**
   - ARCH-DRY: passes.
   - ARCH-PURE: passes.
   - ARCH-PURPOSE: passes. M1 is the guards milestone, and M2/M3 carry the root-cause fix.
   - ARCH-MOCK: passes (N/A in substance). There is no external dependency, and the fake clock sits behind the production seam.
   - ARCH-CONSTRAINTS: passes.
   - ARCH-SECURE: N/A. This is test-only code with no untrusted input or secrets.
   - ARCH-ORDER: passes. The helper spec no longer depends on scheduler timing.
   - ARCH-FUNERAL: passes. The subscription is removed in `after_each`, and the tmp dir is deleted at exit (checked by my run).
   - For M3: add the mid-buffer fold and toggle cases that PQ-3 planned.
7. **Plan revisions:** none beyond what `d19dcba` already added.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      writer_folds_spec.lua wait_for now passes stall_ms=5000 (old fixed budget); helper case "no progress at all gets exactly the stall window" pins the contract.
  - id: BR-2
    disposition: addressed
    note: |
      until_progress takes env{now,wait}; await_helper_spec drives it with a fake clock and asserts exact times (350, 300, 5000); 4/4 pass.
  - id: BR-3
    disposition: addressed
    note: |
      highlighter.lua exports _VIEWPORT_MARGIN = HIGHLIGHT_VIEWPORT_MARGIN; spec uses drawn + highlighter._VIEWPORT_MARGIN + 1.
  - id: BR-4
    disposition: addressed
    note: |
      atlas/infra/test_harness.md now states the ceiling bounds one wait, not the file, and several slow waits can still reach 50s.
  - id: BR-5
    disposition: addressed
    note: |
      VimLeavePre deletes tmp_dir; a run on HEAD left no new parley-test-repair-budget dir (the remaining ones predate the fix commit).
```
