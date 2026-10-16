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

---

## Re-review — 2026-10-16T00:44:11-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 340 — Credential-health persistent-404 test times out in the required suite |
| repo | parley.nvim |
| issue file | workshop/issues/000340-cliproxy-credential-health-timeout.md |
| boundary | whole-issue close |
| milestone | — |
| window | 30a94402e6a3978a2ce58fbf795dc3eee9389d2d..426c2054ab1cf82030d0e9fceb8f910afa3e2b2a |
| command | sdlc close --issue 340 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T00:44:11-07:00 |
| verdict | SHIP |

## Review

Checking the BR-1/BR-2 fixes against the code; next I'll run the lifecycle spec and a revert check.

Test harness needs its isolated environment; switching to `make test-spec`.

I'll run the lifecycle spec with the harness's isolated env vars.

57/57 green. Now reverting the BR-1 lsof re-check to confirm its regression test goes red.

BR-1 regression goes red without the fix. Running the update and command specs, which share the restart path.

```verdict
verdict: SHIP
confidence: high
```

**Verdict: SHIP, high confidence.** Both findings from the previous round are fixed, and I checked each against the code and by running the tests. The issue's Done-when is met. A restart now waits for the processes `stop()` signalled to exit (`uv.kill(pid, 0)`), not for a port probe that only resolved through curl's `--max-time`. `restart_managed` then calls the extracted `start_managed` without a second reuse probe. The probe at the deadline is unchanged, so the #237 "still answers" error still fires. For BR-1, an exit-confirmed release now also reads the port's listeners with `lsof`. A listener left on the port, or a failed read, falls back to the probe. When I reverted that check, the new regression test failed. For BR-2, the render-error message now comes from one helper, `render_or_fail`. In the isolated harness env these all passed: lifecycle 57/57, update 40/40, command 19/19, budget 3/3, dispatch 3/3. Nothing blocks SHIP. There is one Minor note.

1. **Strengths**
   - `lua/parley/cliproxy.lua:513-530`: the wait checks whether the processes still exist, which the code controls, instead of inferring it from the port. `EPERM` counts as alive, so a process that exists but isn't ours is not mistaken for gone. The fallbacks are written down: no pids, a listener left over, an `lsof` error, or the deadline passing all go back to the probe.
   - `start_managed` (`cliproxy.lua:814`) is the only spawn path. `ensure_running` and the exit-confirmed restart both use it (ARCH-DRY).
   - The regression in `tests/integration/cliproxy_lifecycle_spec.lua:808-839` reproduces the measured stall. Any probe made between stop and spawn answers "down" only after 5 s. The test then asserts that zero such probes happened, rather than just giving the case a longer timeout.
   - The BR-1 test (`cliproxy_lifecycle_spec.lua:381`) sets up exactly the case that was flagged: a peer on the port, `lsof` unavailable, and our own pid on another port. It also confirms our old proxy was killed (ESRCH).

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `cliproxy.lua:519`: the `pids_on_port` re-read runs synchronously on the main loop (`vim.system():wait()`). The implementer's own measurement shows the harness max rising from 917 ms to 1557 ms under load. Each restart pays this once, alongside the synchronous `lsof` and curl calls `stop()` already makes, so it is acceptable (ARCH-CONSTRAINTS).

5. **Test coverage**
   - Both previous-round fixes have regression tests:
     - Reverting the BR-1 check (`if not lerr and #listeners == 0` changed to `if true`) turns "a restart whose killed pids exit still reports a peer left on the port" red. Restoring it makes the spec green again.
     - The implementer's log reports that a probe-only release and removing the direct spawn each fail cases. I did not repeat those two experiments.
   - BR-2 is a refactor that doesn't change behaviour; the existing render and spawn paths stay green.

6. **Architecture**
   - **ARCH-DRY: pass.** The spawn branch and render-error message each have one source now.
   - **ARCH-PURE: pass.** No new business logic is mixed into IO beyond the existing shell.
   - **ARCH-PURPOSE: pass.** Both stalls are removed, the wait probe and the reuse probe; the probe at the deadline still decides when the wait runs out.
   - **ARCH-MOCK: pass.** Tests run against the stateful Python fake through the existing `health_probe`, `spawn` and `_set_process_tools` seams.
   - **ARCH-CONSTRAINTS: pass, with the Minor note above.** The wall-clock `PORT_RELEASE_MS` deadline is kept, so the REPAIR BUDGET upper bound still holds.
   - **ARCH-SECURE: pass.** pids come from our own table and from `lsof` output parsed as numbers. No credentials are newly exposed.
   - **ARCH-ORDER: pass.** The wait doesn't treat an unconfirmed outcome as success: the process exiting plus an empty listener read confirms release; anything else falls back to the probe.
     - A peer could bind the port between the `lsof` read and the spawn. That window is no different from the existing `ensure_running` path. `poll_until_healthy` reports a crashed spawn as an error.
   - **ARCH-FUNERAL: pass.** The change creates no durable artifacts. The spawned processes are tracked in `_spawned` as before.

7. **Plan revisions:** none. The plan's checklist, the close-round log and the atlas text (`atlas/providers/cliproxy-managed.md:112-117`) match the code. README needs no change because nothing user-facing was added.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      wait_port_released now re-reads lsof after exit and falls back to the probe on a leftover listener or failed read (cliproxy.lua:518-523); reverting it turns the new peer-on-port test red, restored green 57/57.
  - id: BR-2
    disposition: addressed
    note: |
      render_or_fail (cliproxy.lua:363) is the single render-error site; ensure_running and start_managed(nil) both use it, and the duplicated block is gone.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: sync-io-on-main-loop-poll
    title: |
      exit_poll's lsof re-read is a synchronous vim.system():wait() on the main loop
    detail: |
      cliproxy.lua:519 blocks the editor for one lsof per restart; the implementer measured the harness max rising from 917 ms to 1557 ms under load. Acceptable as a one-time cost per restart (stop already does sync lsof and curl), but an async read would keep the UI path unblocked (ARCH-CONSTRAINTS).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d7a18c0c-99f1-4269-b3e3-1a6e766b3241","repository":"github.com/xianxu/parley.nvim","issue_id":"000340","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/2ad5326ee870a3ce","reviewed_head":"426c2054ab1cf82030d0e9fceb8f910afa3e2b2a","slot":"parley.nvim:4","requested_at":"2026-10-16T07:40:53.938657Z"},"phase":"finished","pid":65078,"started_at":"2026-10-16T07:40:54.209396Z","finished_at":"2026-10-16T07:44:06.219615Z","session_id":"87dae4d9-27c4-479b-ab7f-0b4257874d5d","outcome":"returned"}] -->
