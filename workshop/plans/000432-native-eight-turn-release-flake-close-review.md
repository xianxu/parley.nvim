# Boundary Review — parley.nvim#432 (whole-issue close)

| field | value |
|-------|-------|
| issue | 432 — Native eight-turn clean release intermittently retains its lock |
| repo | parley.nvim |
| issue file | workshop/issues/000432-native-eight-turn-release-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0675cc21d442bf438f7a08a7425a7567d5623101..93d4fda8b5e31994544f4ae181222b7ed9989122 |
| command | sdlc close --issue 432 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-24T07:52:01-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I've read the diff and the issue. Now I'm trying to run the new #432 cases to confirm them, and reverting the fix to check they fail without it.

Some unrelated-looking specs failed, including the fake-Couch protocol spec whose fixture this diff changes. Checking whether that's the environment or the change.

The fake-Couch failure comes from my `/tmp` → `/private/tmp` symlink, so it's environmental. Now checking the native spec results.

The lock-leave-reminder spec passes 19/0 when run alone, so the earlier failures were environmental. Now the negative control: running with base `session_sync.lua`.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The fix is correct and does what the issue asked. A clean automatic release whose `couch operator-release` is killed at its 500 ms budget is now treated as unconfirmed rather than failed. It is retried with the same idempotent turn token after 1, 2 and 4 s, and stops when the epoch or `release_generation` changes. The retry still re-checks the baseline, insert-intent and lock-ownership guards. A refused release is still never retried, and lock ownership is not weakened: `ours()` accepts a missing lock only on a retry, and a foreign lock always drops the retry.

I ran the native spec at head: it passed 150/0 on Neovim 0.11.7, including the three new #432 cases and the original 8-turn case. As a negative control I put back base `session_sync.lua` with the new tests: both retry regressions failed (148/2) and the race case passed, which is what the Log says should happen. Two parts of the retry bounding are untested: the generation bump on a fresh release, and the WARN when retries run out. That gap is what keeps this from SHIP.

1. **Strengths**
   - The fix is driven by a reproduction. The new `FAKE_COUCH_OPERATOR_PRE_DELAY` knob (`tests/fixtures/fake_couch_operator.py:83`) recreates the killed-before-effects state, and the reproduction was established before the fix.
   - There are regressions for both outcome shapes: killed before effects, and reply lost after effects (`tests/integration/session_sync_native_spec.lua:699-724`). The second also checks that the next turn gets a new token, which no existing assertion caught. I confirmed both go red without the fix.
   - `dispatch_admission` sets `unconfirmed` only for a tokened `unavailable` result (`lua/parley/session_sync.lua:478`). Refused releases and the legacy byte path stay definitive, which matches the state table.
   - `ours()` (`session_sync.lua:1112-1115`) relaxes the check to "lock absent" only when `retrying`. A fresh release still needs the exact owned bytes.
   - The `M.release_if_baseline` doc comment moved together with the public wrapper (`:1140-1144`), so no comment was stranded.

2. **Critical findings**: none.

3. **Important findings**
   - **The retry-chain bounds have no tests** (`session_sync.lua:1097-1101`, `:1129`). Two behaviors in the plan's state table can regress without any test failing:
     - (a) **Fresh-release supersession.** `if not retrying then s.release_generation = … + 1` (`:1129`) stops two retry chains running side by side. Example: an unconfirmed release, then a normal-mode `x`/`u` back to the baseline with no acquire in between, which triggers a second unconfirmed fresh release. The Log admits the race test is stopped by the baseline check and doesn't isolate the generation.
     - (b) **Exhaustion.** No test drives three failed retries and checks for exactly one WARN, the lock still held, and no fourth call.
     - The lessons entry calls the generation the key guard. If you delete either bump, or the WARN branch, the suite still passes.
     - **Fix sketch:** keep the release slow for every call. Test (b) by counting `calls("release") == 4` and one WARN after about 7.5 s. Test (a) with two fresh unconfirmed releases and no acquire between them, then check the total number of release calls.

4. **Minor findings**
   - The atlas says retries happen "at 1, 2 and 4 s" (`atlas/modes/session_sync.md:128`). Each delay actually starts when the previous attempt fails, so retries come at about 1, 3 and 7 s or later. "after 1, 2 and 4 s backoff" would be accurate.
   - Done-when clause 3 says "complete native spec pass under repeated qualification". It holds only if you exclude the separately registered #427 undo/redo cases, which failed in 15 of 20 reps on 0.11.7 and 8 of 20 on 0.12.5 in the Log. State that exclusion explicitly in the close.
   - The retry timer guard (`:1103`) doesn't check `nvim_buf_is_loaded`, unlike the other deferred callers (`:828`, `:797`, `:922`). It's harmless: an unloaded buffer's hash won't match the baseline. Add the check if you want them consistent.

5. **Test coverage notes**
   - Negative control verified: with base `session_sync.lua`, both #432 retry cases fail and the race case passes.
   - The race case, as the Log itself says, passes with or without the generation guard.
   - In my parallel `make test-spec` run, `lock_leave_reminder` and `fake_couch_operator` failed. These are environmental: the `/tmp` → `/private/tmp` path mismatch, and parallel load. Run alone, `lock_leave_reminder` passes 19/0 at head.

6. **Architectural notes**
   - **ARCH-DRY: pass.** The retry guard reuses the existing epoch-capture idiom and `helper.defer_deadline`. No duplicated blocks.
   - **ARCH-PURE: pass, with a note.** Retry scheduling and `release_generation` live in the IO shell (`state[buf]`), not in the pure `operator_admission` owner. That's acceptable for timer glue. If retry policy grows, for example reconciling other budgeted verbs as the lesson suggests, move the decision ("unconfirmed → retry at attempt n?") into a pure function.
   - **ARCH-PURPOSE: pass.** It fixes the cause (an unconfirmed release that is never reconciled), not a longer wait, and covers both outcome shapes.
   - **ARCH-EVOLVE: pass.** No persisted format changes. The fake gains an additive env knob.

7. **Plan revision recommendations**
   - Add a Revisions/Log note: the generation guard and exhaustion WARN are covered by tests once the Important finding is fixed, or are explicitly accepted as untested.
   - Note that Done-when clause 3 is satisfied apart from the #427-registered cases.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: retry-bound-untested
    title: |
      Release-retry chain bounds (fresh-release generation bump, exhaustion WARN) have no regression test
    detail: |
      lua/parley/session_sync.lua:1129 bumps release_generation on a fresh release so an older chain cannot keep running beside a new one, and :1097-1101 emits one WARN after 3 tries. Removing either leaves the suite green. The race test is also stopped by the baseline check, as the Log admits. Every instance in this window: (a) the fresh-release bump at :1129; (b) the exhaustion branch at :1097; (c) the acquire bump at :442, which is only covered together with the baseline guard. Add a persistent-slow-release case that asserts exactly 4 release calls and one WARN, and a case with two fresh unconfirmed releases and no acquire between them that asserts no doubled retries.
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-precision
    title: |
      Atlas says retries happen "at 1, 2 and 4 s" but the delays are per-attempt backoff (about 1, 3, 7 s+)
    detail: |
      atlas/modes/session_sync.md:128 vs RELEASE_RETRY_MS in session_sync.lua:1093. Each delay starts when the previous attempt fails. Only this one instance in the window.
  - id: new
    severity: Minor
    kind: defect
    family: done-when-qualification-scope
    title: |
      Done-when clause 3 (complete native spec passes under repeated qualification) holds only if the registered 427 cases are excluded
    detail: |
      The Log shows 15 of 20 reps on 0.11.7 and 8 of 20 on 0.12.5 failing, all in the 427 undo/redo cases. Record that exclusion explicitly at close.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"25afca10-02e5-4490-b605-98e5b277fb34","repository":"github.com/xianxu/parley.nvim","issue_id":"000432","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/9daf8c919fb1c499","reviewed_head":"93d4fda8b5e31994544f4ae181222b7ed9989122","slot":"parley.nvim:1","requested_at":"2026-10-24T14:39:10.303065Z"},"phase":"finished","pid":40442,"started_at":"2026-10-24T14:39:10.394845Z","finished_at":"2026-10-24T14:50:54.513764Z","session_id":"4059122b-a3f4-4d1e-91c1-f41412b48f75","outcome":"returned"}] -->
