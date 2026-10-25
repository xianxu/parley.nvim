# Boundary Review — parley.nvim#440 (whole-issue close)

| field | value |
|-------|-------|
| issue | 440 — A predicate wait doing child RPC never times out |
| repo | parley.nvim |
| issue file | workshop/issues/000440-a-predicate-wait-doing-child-rpc-never-times-out.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6db317ab9ec7712ebaeb14c247a494df3bfde2e8..42a7409870a66fa1f888362a9c43e223a0143892 |
| command | sdlc close --issue 440 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-25T01:29:46-07:00 |
| verdict | SHIP |

## Review

Reviewing the #440 diff now. Next I'll run the regression test with and without the fix.

Running the harness specs now, to check the regression test passes with the fix and fails without it.

Green at head. Now I'll revert the helper to base and rerun.

```verdict
verdict: SHIP
confidence: high
```

The fix delivers what #440 asked for. `Child:request` used to create a timer and close it on every request. The close callback left pending meant every pass of `vim.wait` took under 1 ms and was counted as 0 ms, so a wait whose predicate made child requests never expired. Each Child now keeps one timer across its requests, at the one seam every child request goes through. I confirmed the regression test both ways. At head, `make test-spec SPEC=infra/test_harness` exits 0 and the new case passes. With `tests/helpers/embedded_nvim.lua` reverted to base, the new case fails at its fence with `'wait never timed out'` (`embedded_nvim_spec.lua:50`) instead of stalling until the deadline, and the run exits 2. The checkout was restored afterwards. Nothing blocks SHIP. The one finding is Minor: the comment and atlas claim the timer always closes, but the socket probe's borrowed Child is never joined, so its timer isn't closed.

1. **Strengths**
   - The fix sits at the one place all child requests go through (`tests/helpers/embedded_nvim.lua:50-58`), so every per-spec `wait_for` over `child:exec` is fixed without touching any of them. The plan also gives a sound reason to reject a suite-wide `vim.wait` override (product code under test would then pass a wait that hangs for users).
   - The regression test has a fence based on `hrtime` (`embedded_nvim_spec.lua:43-45`), so a regression fails loudly instead of eating the 120 s idle deadline. I verified this behaviour, not just read it.
   - The timer is closed in `join_and_cleanup` (`:28-29`) before the ownership check. Stop, a fired deadline and a failed setup all close it, including on an unowned channel, as long as something joins it.
   - The kill-on-deadline path is unchanged: `fired` is reset per request, and on a fired deadline the child is joined and the error names the method.
   - The plan says requests are serial, so no second request can rearm the timer mid-flight. That holds: nothing in `lua/` or `tests/` makes an `rpcrequest` back from the child, and `tests/arch/embedded_rpc_spec.lua` blocks raw `rpcrequest` calls, so nested requests can't happen today.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - `scripts/couch-editor-probe.lua:77`: `endpoint()` builds a borrowed Child, `setmetatable({channel=…,pid=…}, getmetatable(child))`, and calls `exec` on it. That now creates a timer stored on the borrowed table. The probe never calls `stop()` on it (by design, only the original Child may join), so the stopped timer is never closed. Before this change, every request closed its own timer. The leak is small: the timer is inactive, the probe is short-lived, and one handle leaks per `endpoint()` call. But it contradicts the atlas line "closed when the child is joined" (`atlas/infra/test_harness.md:350`) and the plan's FUNERAL claim, which only covers "a Child never stopped". Fix sketch: after `chanclose`, close `connected.timer` (for example `if connected.timer then connected.timer:close() end`), or add a `Child:release()` that closes the timer without joining. **Family:** this is the only borrower of `Child.request` in the tree; no other site builds a Child from the metatable.

5. **Test coverage notes**
   - The regression goes red without the fix and green with it, as described above.
   - The "existing callers keep their semantics" clause is covered by the infra/test_harness run, which was all green. I did not rerun modes/session_sync; the Log reports it green on 0.11.7 and 0.12.5.
   - No test runs a request after a timer was closed (a fired deadline followed by a reused child). The code lazily recreates the timer in that case, so it is safe.

6. **Architectural notes**
   - ARCH-DRY: pass. The fix lives at the shared seam. The test's local `wait_for` is a deliberate copy with a fence. The roughly 16 per-spec `wait_for` copies were already there and are out of scope.
   - ARCH-PURE: pass. This is test-harness IO glue, and no business logic is mixed in.
   - ARCH-PURPOSE: pass. Every consumer of a child request derives from `Child:request`, so the stall is fixed for all callers, not just the case that hit it. The upstream report is handed to the operator because filing it is outward-facing, and that is a separate extension, not the point of the issue.
   - ARCH-EVOLVE: N/A. No persisted format is touched.

7. **Plan revision recommendations**
   - Optionally extend the FUNERAL note to cover borrowed channel Children (the socket probe), which are never joined, or adjust the atlas sentence to match once the Minor finding is fixed.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: handle-lifetime-tied-to-join
    title: |
      Borrowed socket Child in couch-editor-probe leaks its per-child request timer
    detail: |
      scripts/couch-editor-probe.lua:77 borrows the Child metatable for a socket channel and never joins it, so the timer that Child:request now stores on that table is never closed. This contradicts atlas/infra/test_harness.md:350 ("closed when the child is joined") and the plan's FUNERAL claim. Close connected.timer after chanclose, or add a release method that closes the timer without joining. It is the only borrower of Child.request in the tree.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"acb36ee6-2d50-42c0-92e5-cab7920dc8f7","repository":"github.com/xianxu/parley.nvim","issue_id":"000440","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/523a292817b772d0","reviewed_head":"42a7409870a66fa1f888362a9c43e223a0143892","slot":"parley.nvim:1","requested_at":"2026-10-25T08:25:10.487896Z"},"phase":"finished","pid":69474,"started_at":"2026-10-25T08:25:10.635795Z","finished_at":"2026-10-25T08:29:44.740427Z","session_id":"dc631e37-4533-4e0d-adda-1901fc143962","outcome":"returned"}] -->
