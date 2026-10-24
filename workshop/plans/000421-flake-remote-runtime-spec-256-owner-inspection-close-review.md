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

---

## Re-review — 2026-10-23T20:42:25-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 421 — flake: lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership keeps inspection bounded when all 256 marked directory owners differ from this editor, lua:tests/integration/remote_runtime_spec.lua#private editor RPC runtime ownership retains a directory whose inode changes after inspection begins |
| repo | parley.nvim |
| issue file | workshop/issues/000421-flake-remote-runtime-spec-256-owner-inspection.md |
| boundary | whole-issue close |
| milestone | — |
| window | cd5fc8bfd2f4f6cef5b22cc94ce912e48fa8c5a1..5cdcfa828869c68e4fc4aec0094f9f8a9ba0dd39 |
| command | sdlc close --issue 421 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-23T20:42:25-07:00 |
| verdict | SHIP |

## Review

Checking whether #430's status and flake registrations live in the tracker JSON instead of the frontmatter.

Verifying the spec's seam restore and running the affected specs.

Test runner produced no output; checking why.

All 278 mapped cases pass. Now running revert controls for the claimed fixes (lint coverage and blocked-loop regression).

```verdict
verdict: SHIP
confidence: high
```

All three round-1 findings are fixed and I confirmed each one. The Done-when list now has a clause for each revision. The lint also flags `vim.defer_fn` and `timer_start` deadlines, plus a remaining time computed by hand and passed to `start_deadline`. All three absolute-deadline sites now share one helper, `helper.start_absolute_deadline`. I ran the remote_session mapping through the harness (`make test-spec SPEC=modes/remote_session`) and got 278 passes, 0 failures and 0 errors. I then tried two reverts in this disposable checkout and restored the files afterwards; `git status` is clean. First, I added a `vim.defer_fn(fn, deadline_ms)` and a `start_deadline(t, math.ceil(d), …)` to `oauth.lua`, and both lint rules failed. Second, I put `remote_runtime.lua` back on a raw `timer:start` with the remaining time computed by hand. Its blocked-loop case went red (44 pass, 1 fail) and so did the lint. One thing I could not check: `000430`'s frontmatter still says `status: open` and lists both cases in `flake_tests`. Those fields are copied from the issue-cards store, which this checkout doesn't contain. That is the one note below, and it does not block.

1. **Strengths**
   - `lua/parley/helper.lua:25-34`: `start_absolute_deadline` calls `_H.start_deadline` through the table, so the `hold_deadline` stub in `editor_endpoint_registry_spec.lua:36` still catches calls to it. It is one place for the "at least 1 ms" remaining-time calculation, which used to be written out at three sites.
   - `tests/helpers/loop_clock.lua`: one shared busy-wait, and the two blocked-loop regression tests use it (`remote_process_spec.lua:118`, `remote_runtime_spec.lua:420`). The second revert above shows they catch a timer started from the stale clock.
   - `tests/arch/deadline_timer_spec.lua:9-17`: the header now states exactly what the lint checks and what it misses (a deadline stored in a differently named variable, a call through an alias, a remaining time computed on an earlier line). That matches the patterns in `STARTS`.
   - The deadline tests are causal now. A held fsync or held deadline is released only after the deadline under test has really passed (`remote_runtime_spec.lua:479-486`, `editor_endpoint_registry_spec.lua:41-45`). No fixed injected delay competes with real IO.
   - `fake_couch_editor.py:182-187`: the fake writes through a temp file per process plus `os.replace`, which removes the race where a spec could read the polled file while it was still empty.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - The issue Log says #430's two cases are unregistered and its status is set to working. At this head, `workshop/issues/000430-endpoint-deadline-startup-flake.md:3,11` still shows `status: open` and both entries in `flake_tests`. Its `card_mirror` hash is the same as at the base commit. The real card store (issue-cards / tracker) isn't in this checkout, so I can't tell whether the mirror is just stale or the tracker was never updated. The close gate will check this anyway through the new Done-when clause. Every instance of this kind in the window: only the #430 card.
   - `atlas/modes/remote_session.md:88` says both timers start through `helper.start_deadline`. They now go through `start_absolute_deadline`, which calls `start_deadline`, so the sentence is still true. It just doesn't name the newer entry point.

5. **Test coverage notes:** The blocked-loop regressions cover `remote_runtime` and `remote_process`. The `document_registry` absolute-deadline path has no blocked-loop test of its own. Its behaviour didn't change, though: it already went through `start_deadline`, and the round-1 fix only switched it to the new helper. The endpoint specs cover it through the held seam. The lint has two rules and both fail when the bad pattern is added (first revert above).

6. **Architectural notes**
   - **ARCH-DRY: pass.** One helper computes the remaining time for an absolute deadline, and one test helper does the busy-wait. I found no duplicated blocks in the window. `chat_pending.lua:42` is a raw start, but it is a UI scheduler and out of scope as the lint header states.
   - **ARCH-PURE: pass.** The changes are thin IO glue (starting timers). The helpers are small and replaceable, and the tests stub the `start_deadline` seam instead of mocking business logic.
   - **ARCH-PURPOSE: pass.** The root cause is fixed in the product rather than hidden by a longer timeout. A grep of `lua/` for `:start(` and `start_deadline` call sites found no other hrtime deadline timer started raw. The class is enforced by the lint, with its blind spots stated.
   - **ARCH-EVOLVE: pass, not applicable.** No persisted formats change. The fake's `.held` marker is test-only.

7. **Plan revision recommendations:** none. Done-when now covers both revisions, and the Plan matches the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Done when now has the Revision 1 (#430 fold) and Revision 2 clauses (issue file, Done when section); whether the tracker card was updated is noted separately because the in-repo mirror is stale.
  - id: BR-2
    disposition: addressed
    note: |
      STARTS now includes vim.defer_fn and timer_start; a revert control that added vim.defer_fn(fn, deadline_ms) to oauth.lua failed the lint.
  - id: BR-3
    disposition: addressed
    note: |
      helper.start_absolute_deadline is used at remote_runtime:113, remote_process:144 and document_registry:130; the busy-wait is now tests/helpers/loop_clock.block; reverting remote_runtime to a raw timer:start failed its blocked-loop case and the lint.
findings:
  - id: new
    severity: Minor
    kind: unverifiable
    family: log-claims-match-tracker-state
    title: |
      The #430 card mirror still shows status open with both flake_tests registered, but the Log says they were unregistered
    detail: |
      I read the head copy of workshop/issues/000430-endpoint-deadline-startup-flake.md (frontmatter lines 3 and 11). The card_mirror hash is unchanged since the base commit, and the issue-cards/tracker store is not in this checkout (issue-tracker.json points only at the migrate root 41de715a). Evidence that would settle it: the tracker card for #430 showing flake_tests removed and its status, or a refreshed mirror. Only instance in this window.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"f9b00369-9a8f-477b-86a9-e6d340218cbf","repository":"github.com/xianxu/parley.nvim","issue_id":"000421","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/3f930041cb365acd","reviewed_head":"5cdcfa828869c68e4fc4aec0094f9f8a9ba0dd39","slot":"parley.nvim:1","requested_at":"2026-10-24T03:37:42.384858Z"},"phase":"finished","pid":44378,"started_at":"2026-10-24T03:37:42.474786Z","finished_at":"2026-10-24T03:42:23.81854Z","session_id":"2c59b402-cf49-4de0-9689-be642dc39aac","outcome":"returned"}] -->
