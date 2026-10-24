# Boundary Review — parley.nvim#421 (whole-issue close)

| field | value |
|-------|-------|
| issue | 421 — flake: lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership keeps inspection bounded when all 256 marked directory owners differ from this editor, lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership retains a directory whose inode changes after inspection begins |
| repo | parley.nvim |
| issue file | workshop/issues/000421-flake-remote-runtime-spec-256-owner-inspection.md |
| boundary | whole-issue close |
| milestone | — |
| window | cd5fc8bfd2f4f6cef5b22cc94ce912e48fa8c5a1..71c8a0b3afb8eaebbe60fa1752197f5dcc965dcd |
| command | sdlc close --issue 421 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-23T20:31:39-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I've read the diff and the issue. Now I'm checking whether any other hrtime-deadline timers bypass the new helper, then I'll run the specs.

Running the specs through make, since the env script needs its harness.

Mapping is green (278 pass). Now reverting the two product fixes to confirm the new tests go red.

Negative controls confirmed and the checkout is restored. Last check: how #430's registration relates to this close.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The fix works and is proven causally. `remote_runtime.lua:113` and `remote_process.lua:144` now arm their hrtime deadlines through `helper.start_deadline`, which refreshes libuv's cached loop clock before starting the timer. I reverted both product files in the disposable checkout and ran the `modes/remote_session` mapping. Exactly three cases failed: the new arch lint and the two blocked-loop regressions. With the fix restored the mapping passes 278/0/0 on nvim 0.11.7, with a clean process census. The test rewrites remove the fixed-delay races: held fsync and deadline callbacks are released only after the deadline under test has really passed, and the fake editor now writes its polled files atomically. One thing blocks a clean SHIP. The scope grew through two Revisions (the #430 fold and the product root-cause fix), but `## Done when` still has only one clause. It says nothing about closing #430 or unregistering its two flake cases. #430 is still `status: open` and its `flake_tests` are still registered.

Done-when: stale — the #430 fold (TL-approved Revision 1: "close #430 with #421 and unregister its cases") is not stated in `## Done when`. Its only clause covers #421's own registered pair.

1. **Strengths**
   - The regressions fail without the fix. Reverting `remote_runtime.lua` or `remote_process.lua` turns its blocked-loop case red (`remote_runtime_spec.lua:420`, `remote_process_spec.lua:118`), and the lint (`tests/arch/deadline_timer_spec.lua`) fails too. Nothing else fails. This matches the R1/R2 claims in the Log.
   - I checked the Revision's claim that remote_process is "the only other hrtime-deadline timer". Every hrtime-derived deadline in `lua/` now arms through `helper.start_deadline`: remote_runtime, remote_process and document_registry. `remote_session.exit` uses `vim.wait`, not a timer.
   - The deadline tests are causal rather than timed. `await_startup_deadline` / `release()` (`remote_runtime_spec.lua:310-342`) and `expire_after_publication` (`editor_endpoint_registry_spec.lua:154`) gate on the phase being tested, not on wall-clock margins.
   - `atomic_write` (`fake_couch_editor.py:182`) uses a per-PID temp file, so the four concurrent `occupy_slots` children no longer collide.
   - The `start_deadline` override is restored in `after_each` (`editor_endpoint_registry_spec.lua:78`), so a failed assertion cannot leak the stub into later cases.

2. **Critical findings:** none.

3. **Important findings**
   - **`## Done when` does not cover the #430 fold** (issue file, `## Done when`). Add a clause such as "#430 closes with #421 and its two `editor_endpoint_registry_spec` cases are unregistered", so the close gate actually checks it. Family instances in this window: the #430 fold is the only Revision with no Done-when clause. Revision 2 (the product fix) is covered by "root cause is fixed".

4. **Minor findings**
   - The lint's comment lists what it cannot see (`deadline_timer_spec.lua:9-12`), and the list is incomplete. The lint only matches `:start(`, so a raw `vim.defer_fn(fn, deadline_ms)` or `vim.fn.timer_start(deadline_ms, ...)` passes silently. Both have the same stale-clock bug; `helper.defer_deadline` exists for the first. No such call exists today. Either add those patterns or list them as blind spots.
   - ARCH-DRY: `math.max(1, math.ceil(deadline - now()))` followed by `start_deadline` now appears three times: `remote_runtime.lua:113`, `remote_process.lua:144` and `document_registry.lua:174`. A `helper.start_absolute_deadline(timer, deadline_ms, cb)` would remove the copies and let the lint key on one name.
   - ARCH-DRY: the 1.2 s busy-wait that blocks the loop is copied in `remote_process_spec.lua:203-204` and `remote_runtime_spec.lua:275-276`. It could be a test helper.
   - The `## Spec` body still says "Design (test-only; product deadlines unchanged)" and "the stall's cause is not established". Revision 2 explicitly supersedes this, so it is acceptable, but a one-line pointer in the Spec would help a reader.

5. **Test coverage notes:** Both product sites have a blocked-loop regression, plus a lint; all three go red without the fix (verified). #430's cases cover both the published-and-held phase and the native-join phase. The fixed-deadline join case keeps its old `defer_fn` gate, which is fine because its deadline is held by the stub. I did not repeat the 20-rep under-load runs; that part rests on the Log.

6. **Architectural notes**
   - ARCH-DRY: flag (Minor, above).
   - ARCH-PURE: pass. The diff is timer glue at the IO edge, plus tests and fixtures.
   - ARCH-PURPOSE: pass. Every hrtime-deadline timer now goes through the helper and the lint enforces it. The lint's heuristic gaps are the Minor finding above.
   - ARCH-EVOLVE: pass. No persisted format changes; `PATH.held` is a test-fixture marker.

7. **Plan revision recommendations**
   - Add the #430 closure and unregistration to `## Done when`, matching Revision 1.

```findings
findings:
  - id: new
    severity: Important
    family: done-when-tracks-revisions
    title: |
      Done when omits the TL-approved #430 fold (close #430, unregister its two cases)
    detail: |
      Revision 1 folds #430 into #421 and says close #430 with #421 and unregister its cases, but Done when only covers this issue's own registered pair. #430 is still status open with flake_tests registered. Add a Done-when clause so the close gate checks it. This is the only Revision without a Done-when clause in this window.
  - id: new
    severity: Minor
    family: lint-scope-claims-complete
    title: |
      deadline_timer_spec's blind-spot list omits vim.defer_fn and vim.fn.timer_start deadlines
    detail: |
      The lint matches only ':start(' so a raw vim.defer_fn(fn, deadline_ms) or timer_start deadline (same stale-clock bug; helper.defer_deadline exists) passes silently. The comment at deadline_timer_spec.lua:9-12 claims to list what it cannot see but omits these. Either extend the patterns or list them.
  - id: new
    severity: Minor
    family: absolute-deadline-arming-helper
    title: |
      ARCH-DRY: remaining-ms computation plus start_deadline repeated at three sites
    detail: |
      remote_runtime.lua:113, remote_process.lua:144 and document_registry.lua:174 each compute math.max(1, math.ceil(deadline - now)) and call start_deadline. A helper.start_absolute_deadline(timer, deadline_ms, cb) would consolidate them. Separately, the 1.2 s loop-blocking busy-wait is duplicated in remote_process_spec.lua:203 and remote_runtime_spec.lua:275.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"70c4199e-de4f-4e81-8118-ba62da723ce1","repository":"github.com/xianxu/parley.nvim","issue_id":"000421","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/14125556c1561589","reviewed_head":"71c8a0b3afb8eaebbe60fa1752197f5dcc965dcd","slot":"parley.nvim:1","requested_at":"2026-10-24T03:26:52.989185Z"},"phase":"finished","pid":77409,"started_at":"2026-10-24T03:26:53.162809Z","finished_at":"2026-10-24T03:31:39.016955Z","session_id":"554b29a8-aebd-486a-9591-121de802d614","outcome":"returned"}] -->
