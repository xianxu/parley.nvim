# Boundary Review — parley.nvim#341 (whole-issue close)

| field | value |
|-------|-------|
| issue | 341 — Generation machine rejects some output and receipt events without an outcome, possibly hanging the generation |
| repo | parley.nvim |
| issue file | workshop/issues/000341-generation-machine-rejects-some-output-and-receipt-events-without-an-outcome-possibly-hanging-the-generation.md |
| boundary | whole-issue close |
| milestone | — |
| window | 223364394fba895f872f362e7e8fb4d7de4546b4..9f9ef53e22c1459bada56338194af260814fb187 |
| command | sdlc close --issue 341 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-15T19:27:08-07:00 |
| verdict | SHIP |

## Review

Diff read; now checking the runner's `cb.failed` handling so I can see whether the new adapter failure can overwrite an overflow/revoke reason.

Running the focused specs, then revert-checking each fix.

Specs pass and each machine/provider fix goes red when reverted; now checking for other request adapters that could refuse output the same way.

```verdict
verdict: SHIP
confidence: high
```

The change does what #341 asks. The machine no longer leaves an inflight write stuck when its receipt is inconsistent: it now ends the generation as `uncertain`. The provider adapter now reports `provider_failed` before it stops a transport whose output it refused. A write whose blob has gone missing now settles as `uncertain` instead of returning without a receipt. I ran the focused specs at head and all pass: generation unit 70/0, sequences 33/0, response_provider 11/0, stream_integrity 1/0. I then put back the base version of each fixed file, one at a time, in this disposable checkout. Reverting `response_provider.lua` turns the new #341 provider test red. Reverting `generation.lua` turns three machine tests red: the new one and the two whose expectations were updated. Reverting `generation_runner.lua` breaks nothing, which matches the Log's statement that the missing-blob branch can't be reached. Nothing blocks SHIP. The findings below are Minor only.

Done-when: current. Both clauses still describe what the diff builds. The seq gap is covered by the provider spec plus the runner sequence test. The short `applied` receipt is covered by the machine unit tests. Output after completion and the missing blob are each shown unreachable, with the reason recorded in `## Log`. The Revision moved the fix from the machine to the adapter but did not change what "done" means.

1. **Strengths**
   - `lua/parley/generation.lua:345`: an ignorable receipt (any write that isn't inflight) is now told apart from one naming the inflight write, which must settle it. This is exactly the "keep `reject` for genuinely ignorable events" split the Spec asks for, and the comment names which events stay ignorable.
   - `lua/parley/response_provider.lua:96`: the fix sits where the request's fate is actually known. Putting it in the machine would have broken the pinned contract that resolution may come before completion; the Revisions entry explains this. I checked for regressions. `failed()` does nothing when `r.cancelled` is set, so a topic stop still ends `cancelled`. The runner's `cb.failed` skips `issue()` while the machine is stopping, so an overflow or revoke keeps its original reason.
   - Credits are conservative: bytes count only when the attempted count is in bounds. The 11-of-10 case credits nothing, and `generation_spec.lua:538-541` checks this.
   - The new refusal reason `provider request failed: output refused` resolves through the existing `"provider request failed: "` entry in `refusal.lua:167`, so no new wording was needed.

2. **Critical findings**: none.

3. **Important findings**: none.

4. **Minor findings**
   - **ARCH-DRY** (`generation.lua:353-360`): the inner `bounded`/committed check repeats most of the clauses of the outer guard (`attempted>=1`, `attempted<=pending.bytes`, `integer(committed)`, `committed<0`, `committed>attempted`). Two local predicates, `bounds_ok` and `status_ok`, would state each rule once. This is the only instance in the window.
   - **Test coverage** (`generation_runner.lua:421-431`): the new missing-blob branch, for both `write` and `manual_append`, is not run by any test. Reverting it leaves every test green. The Log records it as unreachable by construction, so this is acceptable defensive code, but the `effect.done` path for `manual_append` is untested.
   - **Test seam** (`generation_sequences_spec.lua:76-89`): the runner test plays the adapter's part by hand (`cb.failed`, then `cb.resolved`). The ordering is pinned separately in `response_provider_spec`, but no single test runs the real adapter against the runner's seq-gap refusal.

5. **Test coverage notes**: the machine and provider fixes are both shown to go red when reverted. Two existing tests now pin the new contract instead of the old reject-and-stall one: "impossible receipts" and "smaller applied editor slice". Both now assert the `uncertain` outcome and the credited bytes. The missing-blob branch has no test (see the Minor finding above).

6. **Architectural notes**
   - ARCH-DRY: flagged as Minor, the duplicated receipt-validity clauses.
   - ARCH-PURE: pass. The receipt rule stays in the pure machine. The adapter and runner changes are thin IO glue that send events through `dispatch`.
   - ARCH-PURPOSE: pass. I checked every other request consumer for the same class (a request that resolves without completing). `response_topic.lua` refuses output only while stopping or finished, and then the adapter's `r.cancelled` guard makes `failed()` do nothing, so it is unaffected. `response_provider` is the only production `request` adapter. Each of the four paths in the issue is either fixed or recorded as unreachable.

7. **Plan revision recommendations**: none. The Core concepts table matches the code at all three stated paths, and the existing Revisions entry already records the move from machine to adapter.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: duplicated-validity-predicate
    title: |
      Receipt validity clauses are stated twice in generation.lua write_result
    detail: |
      generation.lua:353-360 re-checks attempted>=1, attempted<=pending.bytes, integer(committed), committed<0 and committed>attempted inside the branch the outer guard already entered (ARCH-DRY). Two local predicates (bounds_ok, status_ok) would state each rule once. Only instance in the window.
  - id: new
    severity: Minor
    kind: defect
    family: defensive-branch-untested
    title: |
      Missing-blob uncertain branch in generation_runner write() has no test
    detail: |
      generation_runner.lua:421-431, both the write dispatch and the manual_append effect.done path. Reverting generation_runner.lua leaves every test green. The Log says it is unreachable by construction, so this is acceptable, but no test runs the branch.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"e7b841d1-62cb-49fb-b3a0-f74d88a12c50","repository":"github.com/xianxu/parley.nvim","issue_id":"000341","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/97e549d7acb989f8","reviewed_head":"9f9ef53e22c1459bada56338194af260814fb187","slot":"parley.nvim:3","requested_at":"2026-10-16T02:25:02.512223Z"},"phase":"finished","pid":78175,"started_at":"2026-10-16T02:25:02.653988Z","finished_at":"2026-10-16T02:27:01.189532Z","session_id":"1c4b734c-8a03-4912-a162-0c1220fb65db","outcome":"returned"}] -->

---

## Re-review — 2026-10-15T19:30:06-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 341 — Generation machine rejects some output and receipt events without an outcome, possibly hanging the generation |
| repo | parley.nvim |
| issue file | workshop/issues/000341-generation-machine-rejects-some-output-and-receipt-events-without-an-outcome-possibly-hanging-the-generation.md |
| boundary | whole-issue close |
| milestone | — |
| window | 223364394fba895f872f362e7e8fb4d7de4546b4..2d0efab84cd098fc657a4327886d28cc59f8368e |
| command | sdlc close --issue 341 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-15T19:30:06-07:00 |
| verdict | SHIP |

## Review

I'm checking the diff. Next I'll run the focused specs and revert the fixes one at a time to confirm each test fails without its fix.

Running the focused specs now (my first try failed because `timeout` isn't installed on this machine).

```verdict
verdict: SHIP
confidence: high
```

Every fix is real and has a test that fails without it. I checked this by reverting each file in the disposable checkout. With `response_provider.lua` reverted, `response_provider_spec` fails 1 of 11. With `generation.lua` reverted, `generation_spec` fails 3 of 70. At head, all three focused specs pass: unit 70/0, sequences 33/0, provider 11/0. The fix for refused output sits in the adapter, which is the side that knows it refused. The machine's existing rule that a request may resolve before it completes is left alone, and the plan's Revisions entry records that move. The class is fully covered: every reason the machine can reject an output (`operation`, `output` for a seq or blob mismatch, `extend`) makes `cb.output` return non-true, and that one adapter path now reports `provider_failed`. If the machine is already stopping, its `provider_failed` handler rejects with `attempt` (`generation.lua:384`), so the earlier outcome, such as `overflow`, still stands. A receipt naming the inflight write now always settles it, and every other receipt is ignored, which matches the Spec's "say which ones those are". Nothing blocks SHIP.

Done-when: current — the move from the machine to the adapter changed where the fix lives, not what the clauses require. The seq gap and the short `applied` receipt each have a test that reaches a terminal or stopping outcome (`generation_sequences_spec.lua:76`, `generation_spec.lua:83`). Output after completion and a missing blob are both shown unreachable, with the reasons recorded in the Plan and Log. That satisfies the clause's "or is shown to be unreachable" branch.

1. **Strengths**
   - `generation.lua:345`: the early return puts the ignorable/settling split on one line, so the "any other write" rule is stated once.
   - `generation.lua:353-360`: `counted` is computed once and drives both the downgrade to uncertain and the credit (`committed=0` when the counts are invalid). Only bytes the receipt can vouch for are credited, and the remainder lands in `discarded_bytes` (the test checks 3 committed and 7 discarded).
   - `response_provider.lua:96`: `failed` runs before `r.active=false`, and `failed` is idempotent and skips cancelled requests (`response_provider.lua:33`). A cancelled request can't report a false provider failure.
   - Two old tests that pinned the reject-and-stall contract were changed to the new contract rather than deleted (`generation_spec.lua:186-190`, `:538-541`).

2. **Critical** — none.
3. **Important** — none.
4. **Minor** — none new.
5. **Test coverage**
   - Revert checks are listed in the summary.
   - The runner sequence test fires `cb.failed` by hand, so on its own it doesn't prove the adapter's behaviour. It shows the machine and runner reach `provider_failed` once the adapter reports; the adapter's ordering is pinned by `response_provider_spec`. That split is fine.
   - No test covers an unknown status with valid counts; it goes through the same `uncertain` branch. Not raised.
6. **Architecture**
   - **ARCH-DRY: pass.** BR-1 is resolved and no new duplicate is introduced. The status set appears only once, at `generation.lua:355`.
   - **ARCH-PURE: pass.** The settlement rule lives in the pure machine. The runner and adapter changes are thin glue that send an event.
   - **ARCH-PURPOSE: pass.** The adapter fix covers every reason the machine can reject an output, not just the seq gap the issue named.
7. **Plan revisions** — none needed; the existing Revisions entry matches the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      2d0efab8 computes validity once as `counted` (generation.lua:353-354) and uses it for both the uncertain decision and the credit. Behavior-neutral refactor; reverting generation.lua fails 3 generation_spec tests, so the rule stays pinned.
  - id: BR-2
    disposition: withdrawn
    note: |
      The unreachability argument holds: stop() releases only s.queue items (generation.lua:87-90) and the inflight item is never in the queue, so its blob is freed only after its receipt. Adding a runner seam just to test that branch is worse than the gap; the decision is recorded in the Log.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"b90aaeab-d5a1-4aaa-aed5-09baf32e81d8","repository":"github.com/xianxu/parley.nvim","issue_id":"000341","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/ee7c57602710afdf","reviewed_head":"2d0efab84cd098fc657a4327886d28cc59f8368e","slot":"parley.nvim:3","requested_at":"2026-10-16T02:28:13.7645Z"},"phase":"finished","pid":99486,"started_at":"2026-10-16T02:28:13.867288Z","finished_at":"2026-10-16T02:30:06.323815Z","session_id":"458c1097-2660-4b7e-ae87-e1d2bd8a2ab8","outcome":"returned"}] -->
