# Boundary Review — parley.nvim#340 (whole-issue close)

| field | value |
|-------|-------|
| issue | 340 — Credential-health persistent-404 test times out in the required suite |
| repo | parley.nvim |
| issue file | workshop/issues/000340-cliproxy-credential-health-timeout.md |
| boundary | whole-issue close |
| milestone | — |
| window | 30a94402e6a3978a2ce58fbf795dc3eee9389d2d..0c2547f885692b5335c041c7f82c76114c3e3372 |
| command | sdlc close --issue 340 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T00:25:34-07:00 |
| verdict | SHIP |

## Review

Diff and surrounding code read; now running the focused lifecycle spec and a quick revert check.

Running the lifecycle spec file directly through the make env.

Green. Now the mutation: revert the direct-spawn and pid-wait in a scratch copy and confirm the regression goes red.

```verdict
verdict: SHIP
confidence: high
```

**Summary.** The change fixes what actually broke instead of raising a deadline. `restart_managed` now waits for the processes that `stop()` signalled to exit, checking each with `kill(pid, 0)`, rather than probing the port. Once they have exited it spawns through the extracted `start_managed`, which skips `ensure_running`'s reuse probe. That reuse probe was the second ~2 s stall. The regression test reproduces the cause that was measured: any health probe made between `stop()` and the next `spawn()` answers "down" only after 5 s. I ran the focused lifecycle spec on the pinned head: 56 passed, 0 failed. I then ran a mutation in this disposable checkout, making `restart_managed` ignore the returned pids so only the old probe path is used. That turned 3 credential_health cases red, then I restored the file. Nothing blocks shipping. I'm noting two Minor items and one evidence gap (the full required suite has no recorded green run).

1. **Strengths**
   - `lua/parley/cliproxy.lua:494-510`: when the wait ends with a process still alive, it still runs one port probe. So a proxy still answering after the wait is still reported as an error (#237 BR-8), and `cliproxy_update_spec` still covers that path.
   - `lua/parley/cliproxy.lua:797-826`: `start_managed` is pulled out of `ensure_running` without changing its behaviour, so there is one spawn path (ARCH-DRY).
   - `M.stop()` stays compatible with its callers: the count is still the first return value, and the pids are added as a second.
   - `tests/integration/cliproxy_lifecycle_spec.lua:782-814`: the stall window is controlled precisely. It opens on `stop()` and closes on `spawn()` or when a new listener comes up. The new `window_probes == 0` assertion pins the property itself, not just a timing.
   - The ESRCH/EPERM distinction in `exit_poll` is correct: a process that exists but isn't ours counts as alive.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - **Comment claim is too strong.** `cliproxy.lua:535` says "The old process is gone, so the port is free". That only holds for the pids `stop()` signalled. If `stop()`'s lsof sweep found nothing (lsof missing or unreadable, or the identity probe timed out) but `_spawned` was non-empty, a peer cliproxy on the port is never probed. A replacement is then spawned, fails to bind, and `poll_until_healthy` may adopt the peer. Before this change that case got the "still answers" error. The impact is small, because reusing a healthy peer matches `ensure_running`'s normal behaviour. The atlas wording at `atlas/providers/cliproxy-managed.md:112-116` is accurate. Instances of this family in the window: `cliproxy.lua:470-476` (doc comment) and `cliproxy.lua:533-536`.
   - **Small duplication (ARCH-DRY).** `write_rendered_config()` plus the `"cliproxy: " .. host` error branch now appear twice, at `cliproxy.lua:537-540` and `cliproxy.lua:869-872`. `start_managed` could render the config itself, so both callers pass only the callbacks.

5. **Test coverage notes**
   - The regression goes red without the fix; I verified this with the mutation above.
   - Both credential_health Done-when states are asserted: the restart that succeeds returns healthy, and the failed restart returns unknown while the second keyless proxy survives.
   - Not covered: the branch where no pids were identified (`#pids == 0`, falling back to probing) and the EPERM branch.
   - The Done-when clause "the required suite pass[es]" has no evidence in the issue log for this head. The log lists only focused specs. I did not run the full suite. The suite gate should confirm it.

6. **Architectural notes**
   - **ARCH-DRY: pass,** apart from the Minor duplication above. The spawn path is now shared.
   - **ARCH-PURE: pass.** The change is IO glue (process signals, timers). There is no business logic to extract, and the tests are properly integration tests using a real fake process.
   - **ARCH-PURPOSE: pass.** The fix removes both stalls named in the plan, the release wait and the reuse probe, rather than only the one the failure pointed at. The REPAIR BUDGET table remains a correct upper bound, because the probe path at the deadline is unchanged.

7. **Plan revision recommendations:** none. The plan matches the code.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: release-inferred-from-partial-pid-set
    title: |
      "Old process gone, so the port is free" holds only for signalled pids; a peer on the port is no longer probed
    detail: |
      restart_managed (lua/parley/cliproxy.lua:533-541) skips every port probe once the pids returned by stop() exit. When stop()'s lsof sweep found nothing (lsof missing or unreadable, or the identity probe timed out) but _spawned was non-empty, a peer cliproxy still on the port is never checked. A doomed replacement is spawned, and poll_until_healthy may adopt the peer, where before this change the "still answers" error was raised. Instances: the comments at cliproxy.lua:470-476 and 533-536. Fix: take the direct path only when stop() reports that the port's listeners were enumerated, or soften the comment.
  - id: new
    severity: Minor
    kind: defect
    family: duplicated-render-then-spawn-preamble
    title: |
      write_rendered_config plus its error branch is duplicated between restart_managed and ensure_running
    detail: |
      cliproxy.lua:537-540 repeats cliproxy.lua:869-872 (ARCH-DRY). start_managed could call write_rendered_config itself, so both callers pass only the callbacks.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"ecaa27d9-5766-4e3b-bd21-4694b33934d8","repository":"github.com/xianxu/parley.nvim","issue_id":"000340","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/4bf9c3850f1a8162","reviewed_head":"0c2547f885692b5335c041c7f82c76114c3e3372","slot":"parley.nvim:4","requested_at":"2026-10-16T07:22:47.085008Z"},"phase":"finished","pid":15154,"started_at":"2026-10-16T07:22:47.635553Z","finished_at":"2026-10-16T07:25:31.570166Z","session_id":"3e9eb47b-31ee-45cf-b6f1-fe3201cb748a","outcome":"returned"}] -->
