# Boundary Review — parley.nvim#442 (whole-issue close)

| field | value |
|-------|-------|
| issue | 442 — Native lost-reply release case flakes under load |
| repo | parley.nvim |
| issue file | workshop/issues/000442-native-lost-reply-release-case-flakes-under-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | daa8b598ad9977926ed5aac0bb3258eb428c8000..3572f43c679938b9cd6ec6bd54f7fcd1a9bee5af |
| command | sdlc close --issue 442 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-24T19:24:57-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Checking how the admission state machine handles a release during an unconfirmed turn.

Looking up the fake Couch delay handling to confirm the new regression test's timing.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The product fix is correct. When a turn's acquire landed but its reply was lost, the turn is still in phase `unconfirmed` with a known `acquire_token`. In that state, `turn_lock` (`lua/parley/session_sync.lua:1111-1118`) only accepts the on-disk lock if its `document` and `turn` match this turn. It then passes those bytes to `release_owned`, which already accepts a proof matched by acquire token. The new regression case reproduces the bug deterministically: a 2 s reply delay against the 500 ms budget. The `insert()` helper fixes the first-turn E484 at the right layer. Three things should be fixed before shipping, and none is a correctness break of what shipped:
- **Retry gap:** in the new unconfirmed path, #432's "retry finds the lock already gone" branch can never run, and the atlas and code comment say it does.
- **One unswept site:** one mode-i site with the same admission race was left out of the sweep.
- **`## Done when` not met as written:** the issue's own `## Done when` clauses for load reps and evidence were met only under a waiver, and the issue doesn't revise them.

I did not run the integration suite here. The issue's log says the sandbox fails with spawn EPERM. The findings below come from reading the code.

**1. Strengths**
- `turn_lock` (`session_sync.lua:1111`) adds no new way to release. It only works out which bytes count as proof, and `release_owned`'s existing token check (`:328`) still guards the release. A lock with the wrong turn is rejected twice.
- `expected` is computed once, then reused by `ours()` before and after the save and by `release_owned`. No stale `admission(s).owned_lock` re-reads remain (`:1121-1143`).
- The `insert()` helper (`tests/integration/session_sync_native_spec.lua:20-22`) relies on autocmds running in the order they were defined. Its observer is registered after attachment (`:85-90`). That proves the admission finished, which "mode is i" does not (ARCH-DRY, ARCH-PURPOSE).
- The regression case (`:739-750`) checks the right preconditions: the winbar shows unavailable and the lock exists. Then it checks that the lock goes away and that no notifications fire.

**2. Critical findings:** none.

**3. Important findings**
- **The retry can't reconcile an unconfirmed turn** (`session_sync.lua:1115-1117`, `:1120-1124`). Suppose the first release for an unconfirmed turn actually ran but lost its reply, so the lock is gone. On retry, `turn_lock` reads no bytes, `operator_proof(nil)` returns nil, and `release_if_baseline` returns false before it ever reaches `retrying and bytes == nil`.
  - Effect: the admission never gets `released`. It stays `unconfirmed` and keeps the old token, the bar keeps saying "Couch unreachable", there is no refresh or idle restart, and the next `i` re-acquires with the released token.
  - The confirmed path does reconcile here.
  - Fix: carry `expected` into `retry_release`, or have `turn_lock` return the bytes it captured earlier when `retrying` is set. Then add a test with an unconfirmed acquire and a release that lands but loses its reply (`slow_next_release("after")` plus `FAKE_COUCH_OPERATOR_DELAY` on the acquire).
  - Same class, other sites: the comment at `:1120` ("a retry finds the lock ours or already gone"), the atlas line `atlas/modes/session_sync.md:131` ("released the same way"), and the plan item "through #432's bounded retry".
- **One mode-i site was left out of the sweep** (`spec:854-860`). That test runs `keys("iX")`, waits for mode i, then uses a `vim.schedule` barrier before reading the buffer, `modifiable` and the lock. The admission waits in `vim.system():wait()`, which runs the event loop. So the scheduled barrier can fire mid-admission, the same mechanism that answers the exec RPC early. Move it to an `insert_admitted` counter wait.
  - I enumerated every mode-i wait in the spec. The others are fine: `:446` and `:605` already wait for admission, and `:1217` and `:1414` run detached. At `:1435` the restore resumes without a new acquire.
- **`## Done when` is unmet as written.**
  - It says "20 reps per nvim under the same capped load". What was delivered is 10 reps per nvim (20 runs per case), under fleet load and with no added stress.
  - It says "both failures explained with evidence". The second failure is explained by a deterministic probe that reproduces the symptom, but it was never observed under the original load.
  - The TL approved both, but only the plan and log record that. Add a `## Revisions` entry that restates these two clauses.

**4. Minor findings**
- `turn_lock` repeats the `proof.ID == s.identity.ID and proof.Turn == acquire_token` predicate from `release_owned:328`. It's acceptable as an early filter, but a small `owns_turn(s, proof)` helper would keep one source of truth (ARCH-DRY).
- The atlas sentence was added mid-paragraph on one long line, which hurts readability.

**5. Test coverage**
- Covered: a clean unconfirmed turn that landed is released, and the token-reuse retry on a dirty turn is kept (#408 case at `:665`).
- Not covered:
  - The retry after an unconfirmed release lands but loses its reply (finding 1).
  - An unconfirmed turn facing a lock with a different turn token. `release_owned` catches this today, but no test proves `turn_lock`'s own guard.

**6. Architecture**
- **ARCH-DRY: pass**, with the minor predicate duplication above.
- **ARCH-PURE: pass.** `turn_lock` is a thin shell read over the pure admission snapshot, and the state machine is untouched.
- **ARCH-PURPOSE: flag.** This covers the unswept sibling site and the incomplete retry path, both enumerated above.
- **ARCH-EVOLVE: pass.** No persisted format changed; the lock body and its fields are untouched.

**7. Plan revisions**
- Add a `## Revisions` entry. It should restate the load-rep clause as delivered under the waiver (10 reps per nvim at fleet load 38–56, no added stress, TL 2026-10-24). It should also restate the second-failure evidence as "mechanism reproduced by a deterministic probe; not observed under load".
- Once fixed, change the plan item from "through #432's bounded retry" to say that a retry also handles a release that landed but lost its reply.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: unconfirmed-turn-release-retry
    title: |
      A retry cannot reconcile an unconfirmed turn's release that landed but lost its reply
    detail: |
      In session_sync.lua at 1111-1124, turn_lock reads the on-disk lock. When a release for an unconfirmed acquire landed but lost its reply, the lock is gone. operator_proof(nil) then returns nil, and release_if_baseline returns false before its `retrying and bytes == nil` branch, so that branch can never run for this turn kind.
      The admission therefore stays `unconfirmed` and keeps the old token. The winbar keeps saying "Couch unreachable", there is no refresh or idle restart, and the next i re-acquires with the released token. A confirmed turn does reconcile in the same situation.
      Fix: carry the expected bytes into retry_release, or reuse the bytes captured on the first attempt when `retrying` is set. Add a test: an unconfirmed acquire with DELAY=2, then slow_next_release("after").
      Same class, other sites: the comment at 1120, atlas/modes/session_sync.md:131 ("released the same way"), and the plan item "through the bounded retry".
  - id: new
    severity: Important
    kind: defect
    family: mode-i-is-not-admission
    title: |
      One native-spec site still uses mode i plus a vim.schedule barrier as proof that admission finished
    detail: |
      In tests/integration/session_sync_native_spec.lua at 854-860, the test runs keys("iX"), waits for mode i, then uses a vim.schedule barrier before reading the buffer line, modifiable and the lock. The admission waits in vim.system():wait(), which runs the event loop, so the scheduled barrier can fire mid-admission. This is the same mechanism the new insert() comment describes.
      Fix: wait on the insert_admitted counter, as insert() does.
      Enumerated all mode-i waits: 446 and 605 already wait for admission, 1217 and 1414 run detached, and at 1435 the restore needs no acquire. Only 855 remains.
  - id: new
    severity: Important
    kind: defect
    family: done-when-clause-unmet
    title: |
      Two Done-when clauses were met only under a TL waiver, and the issue does not revise them
    detail: |
      Done-when requires 20 reps per nvim under the same capped load. Delivered: 10 reps per nvim (20 runs per case) at fleet load, with no spinners and no dd loop.
      Done-when requires both failures to be explained with evidence. The second failure was explained only by a deterministic probe that reproduces the symptom; it was never observed under the original load.
      The TL approved both, but only in the Log. Add a Revisions entry or edit Done-when so the close record matches what was delivered.
  - id: new
    severity: Minor
    kind: defect
    family: ownership-predicate-single-source
    title: |
      turn_lock repeats release_owned's identity and turn-token ownership check
    detail: |
      The check `proof.ID == s.identity.ID and proof.Turn == acquire_token` appears at session_sync.lua:1117 and at 328 (negated). A shared owns_turn(s, proof) helper would keep one source of truth (ARCH-DRY).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"79c33dd9-198d-46b3-b45c-ac4f214b3886","repository":"github.com/xianxu/parley.nvim","issue_id":"000442","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/0ee573c2b1bc26f8","reviewed_head":"3572f43c679938b9cd6ec6bd54f7fcd1a9bee5af","slot":"parley.nvim:1","requested_at":"2026-10-25T02:22:51.710607Z"},"phase":"finished","pid":27869,"started_at":"2026-10-25T02:22:51.835938Z","finished_at":"2026-10-25T02:24:55.903533Z","session_id":"72621a11-9e05-4e8d-a45a-9e47108b43f6","outcome":"returned"}] -->

---

## Re-review — 2026-10-24T22:16:46-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 442 — Native lost-reply release case flakes under load |
| repo | parley.nvim |
| issue file | workshop/issues/000442-native-lost-reply-release-case-flakes-under-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | daa8b598ad9977926ed5aac0bb3258eb428c8000..a0d2a98c09d47756fb512319445420042be4ecdd |
| command | sdlc close --issue 442 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-24T22:16:46-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Prior findings look addressed in the diff; now checking the BR-1 regression goes red without the fix.

Running the session_sync specs with the BR-1 fix reverted to confirm the regression test goes red.

BR-1 regression goes red with the fix reverted (fails at spec:762). Restored; re-running green to confirm.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

All four prior findings are fixed, and I checked BR-1 by running it. I reverted only `retried or` in `release_if_baseline` (`lua/parley/session_sync.lua:1135`). The new case "retries an unconfirmed turn's release whose reply was lost…" then failed at `tests/integration/session_sync_native_spec.lua:762` ("the unconfirmed turn's release was not retried"). With the fix restored, `make test-spec SPEC=modes/session_sync` passed (rc=0). One problem is left. The BR-2 sweep, which moved the remaining mode-i sites onto `insert()`, missed one more site in the same family. It is a cheap test-only fix and does not block.

Done-when: current. The `## Revisions` entry records the scope add (the unconfirmed-turn release and its retry) and the TL-approved evidence changes for both clauses. The Log also shows the original "20 reps per nvim with spinners" clause was met at d1a60d14. The only gap is that there was no dd loop. The flake registration is still in the frontmatter, which is expected: it comes off at close.

1. **Strengths**
   - `turn_lock` (`session_sync.lua:1116-1124`) keeps the unconfirmed-acquire path narrow. It only applies when `phase == "unconfirmed"` with an `acquire_token`, and it matches on document and turn together, so a foreign or replaced lock is never adopted.
   - A retry passes `expected` to `retry_release` and then into `release_if_baseline` (`:1101`, `:1109`, `:1151`). Every retry therefore releases the exact bytes the first try released, and the `retrying and bytes == nil` reconciliation can now be reached for both kinds of turn.
   - `of_turn` (`:324`) is now the only ownership check, used by both `release_owned` and `turn_lock`.
   - The `insert()` helper (spec:17-22, observer at :85-90) waits on the first real signal that admission is done, after the production InsertEnter. Its comment says exactly why mode i is not enough.
   - Giving the acquire a long budget in `slow_next_release` (spec:403-409) fixes a stall, not just a flake: if the acquire is killed at its budget, there is no lock, so the slowed release never runs and the wait hangs.

2. **Critical findings:** none.

3. **Important findings**
   - **`tests/integration/session_sync_native_spec.lua:337-341`** (family `mode-i-is-not-admission`, 2nd finding). After a refused retry, the confirmed final entry runs `keys("i")` and then a `vim.schedule` barrier. It then reads `modifiable` and the mode, which are admission effects. BR-2 already showed that this barrier can fire while the admission is still waiting, so `final_entry.modifiable` can read false under load.
     - **Rule:** in an attached, registered case, every `keys("i…")` followed by an admission-effect assertion must either go through `insert()` or wait for text typed after the `i` to arrive (queued input only applies once admission is done). Mode i or a schedule barrier is never proof that admission finished.
     - **Enumeration of every raw `keys("i…")` in the file:**
       - Already compliant, because they wait for typed-text arrival: 164, 230, 276, 316, 549, 670, 777, 824, 864.
       - 607 waits on `local_i`. 181, 1231, 1428 and 1449 run detached; 886 is unregistered.
       - 168 (`i<Esc>` plus a barrier) only asserts a lock that already existed, so it holds either way. Converting it is still harmless.
       - 337 is the only violation.
     - **Fix:** replace 337-338 with `insert()`. Optionally, add a static check under tests/arch that flags `keys("i` followed by a `vim.schedule` barrier, so the class cannot come back.

4. **Minor findings:** none new.

5. **Test coverage notes**
   - The two #442 regressions cover both halves of the product change: the first release and the retry after a lost reply. I confirmed the retry case goes red when the BR-1 fix is reverted.
   - The Log records that the first-release case goes red on the base code at 885cf610. I did not rerun that one.
   - The "unconfirmed acquire never landed" path (`turn_lock` returns nil, and the next i retries the same turn) is covered by the existing #408 case at spec:667-680.

6. **Architectural notes**
   - **ARCH-DRY: pass.** `of_turn` is the single ownership check. `insert()` replaces the duplicated wait-for-mode-i blocks.
   - **ARCH-PURE: pass.** The diff only touches the IO-side release code, and the new logic is a few small predicates.
   - **ARCH-PURPOSE: flag**, covered by the Important finding: one instance of the issue's own class is still in the spec. The product purpose (an unconfirmed clean turn releases, and its retry reconciles) is fully delivered, and the atlas (`atlas/modes/session_sync.md:131`) matches the code.
   - **ARCH-EVOLVE: pass.** No persisted format changes; the lock bytes are read and released unchanged.

7. **Plan revision recommendations:** none needed for the plan. When the 337 site is fixed, update the BR-2 Log line ("All seven now use insert(typed)") to name it.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      retry_release carries expected bytes; reverting `retried or` turns the new case red at spec:762, restored it is green (make test-spec SPEC=modes/session_sync rc=0).
  - id: BR-2
    disposition: addressed
    note: |
      spec:874 now uses insert("X") plus a typed-text wait; one sibling outside the named site remains, raised as a new family finding.
  - id: BR-3
    disposition: addressed
    note: |
      The Revisions section records the scope add and both Done-when evidence changes; the Log also shows the capped-load clause met at d1a60d14.
  - id: BR-4
    disposition: addressed
    note: |
      of_turn(s, proof) at session_sync.lua:324 is used by both release_owned and turn_lock.
findings:
  - id: new
    severity: Important
    kind: defect
    family: mode-i-is-not-admission
    title: |
      Refused-retry final entry still uses keys("i") plus a vim.schedule barrier as admission proof (spec:337-341)
    detail: |
      This is the 2nd finding in family mode-i-is-not-admission. Rule: in an attached, registered case, every keys("i...") followed by an admission-effect assertion either goes through insert() or waits for text typed after the i to arrive; mode i or a schedule barrier is never admission proof. Enumeration of raw keys("i") sites: 164, 230, 276, 316, 549, 670, 777, 824 and 864 wait for typed text; 607 waits on local_i; 181, 1231, 1428 and 1449 are detached; 886 is unregistered; 168 asserts only a pre-existing lock (benign); 337 is the only violation, where it reads modifiable mid-admission. Fix: use insert() at 337, and optionally add a tests/arch grep guard against keys("i followed by a vim.schedule barrier.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"322ebfa9-f117-412d-bced-92de24863701","repository":"github.com/xianxu/parley.nvim","issue_id":"000442","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/39ea353c9b03d153","reviewed_head":"a0d2a98c09d47756fb512319445420042be4ecdd","slot":"parley.nvim:1","requested_at":"2026-10-25T05:00:21.75489Z"},"phase":"finished","pid":84550,"started_at":"2026-10-25T05:00:21.843515Z","finished_at":"2026-10-25T05:16:44.220032Z","session_id":"2d9c13b4-7490-4ea0-913a-e4e35f2f5df4","outcome":"returned"}] -->

---

## Re-review — 2026-10-24T23:17:20-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 442 — Native lost-reply release case flakes under load |
| repo | parley.nvim |
| issue file | workshop/issues/000442-native-lost-reply-release-case-flakes-under-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | daa8b598ad9977926ed5aac0bb3258eb428c8000..5a566e541bb361b042503268dc5d0a7e5001186b |
| command | sdlc close --issue 442 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-24T23:17:20-07:00 |
| verdict | SHIP |

## Review

Verifying the BR-5 fix now — running the new arch guard and checking it goes red without the fix.

The guard catches both pre-fix sites (168, 337) and passes at head. Now checking the issue's Done-when against the revised Spec.

```verdict
verdict: SHIP
confidence: high
```

**Verdict: SHIP.** BR-5 is fixed, and the fix covers the whole family rather than one site. In `tests/integration/session_sync_native_spec.lua`, the refused-retry final entry (:336) and the #404 re-entry (:168) both go through `insert()` now. `insert()` waits for `insert_admitted` to increase. That counter comes from an InsertEnter observer, registered after attachment so it runs after the production admission (:85-90). It does not trust mode `i`. The new `tests/arch/insert_admission_spec.lua` refuses the `keys("i…")` + `vim.schedule` shape across the whole spec. I checked it outside plenary, with an `nvim -l` script that copies its logic. On the BR-5 parent spec (a0d2a98c) it flags exactly lines 168 and 337. At head it finds no violations across 16 entries, above the floor of 10. The product change in `session_sync.lua` (`of_turn`, `turn_lock`, the retry carrying `retried`) was disposed in earlier rounds; I re-read it and found no regression. One small gap remains, and it doesn't block: the Log doesn't record a run of the integration spec after the BR-5 test edits.

Done-when: current — the Revisions section records the TL-approved scope add (the unconfirmed-turn release) and the reworded evidence clauses. The Log shows both reps clauses met as written: 20/20 per nvim with 3 CPU spinners (no dd loop), and also the 10-rep alternative. The flake deregistration happens at close by definition.

1. **Strengths**
   - `tests/arch/insert_admission_spec.lua:23` — the floor of 10 entries stops the guard passing vacuously if its pattern stops matching.
   - `tests/integration/session_sync_native_spec.lua:19-22` — `insert()` checks that the counter increased, not just that mode is `i`. That makes it real admission proof.
   - `lua/parley/session_sync.lua:324` — `of_turn` is the single ownership predicate, used by both `release_owned` and `turn_lock` (ARCH-DRY).
   - `lua/parley/session_sync.lua:1126-1136` — the retry releases the bytes its first try released, not a re-read. That fixes the lost-reply reconciliation.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - The Log records the arch-guard control after 5a566e54, but no run of `session_sync_native_spec` (or `modes/session_sync`) after the switch to `insert()` at :168 and :336. I couldn't run it here: `scripts/test-env.sh` refuses to run outside make, because `PARLEY_TEST_ENV_ROOT` is unset. Family in this window: only these two edited sites.

5. **Test coverage notes**
   - The guard only catches a `vim.schedule` barrier within 2 lines. It wouldn't catch `keys("i")` + `wait_for(mode=='i')` followed by an admission assertion, which is the other half of the family rule. I enumerated those sites at head: 1228, 1425 and 1446 are in detached cases, and 883 is unregistered. None asserts an admission effect, so the gap doesn't hurt anything today.

6. **Architectural notes**
   - ARCH-DRY: pass. `of_turn` is the one ownership check, and `insert()` is the one entry helper.
   - ARCH-PURE: pass. The new IO is a single `lock_bytes` read in `turn_lock`, in line with the existing glue.
   - ARCH-PURPOSE: pass. BR-5 was answered with a rule-level guard that covers the class, not just the named site.
   - ARCH-EVOLVE: pass. No persisted format changed; lock proof parsing is unchanged.

7. **Plan revision recommendations:** none.

```findings
dispose:
  - id: BR-5
    disposition: addressed
    note: |
      Both :168 and :336 now use insert(). The arch guard copied into nvim -l flags exactly 168 and 337 on a0d2a98c and finds nothing at head (16 entries).
findings:
  - id: new
    severity: Minor
    kind: defect
    family: post-fix-run-evidence
    title: |
      No recorded integration run of session_sync_native_spec after the BR-5 edits to :168 and :336
    detail: |
      The Log records only the arch-guard control after 5a566e54. Run make SPEC=modes/session_sync on 0.11.7 and 0.12.5 and log it. The only instances in this window are the two insert() swaps at :168 and :336.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"2659fbc2-92c5-492f-bf5f-6e8823fbe4bb","repository":"github.com/xianxu/parley.nvim","issue_id":"000442","recipe":"small-diff-review","round":3,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/3d4741d5fe7545cf","reviewed_head":"5a566e541bb361b042503268dc5d0a7e5001186b","slot":"parley.nvim:1","requested_at":"2026-10-25T06:15:56.18398Z"},"phase":"finished","pid":16597,"started_at":"2026-10-25T06:15:56.288279Z","finished_at":"2026-10-25T06:17:19.299254Z","session_id":"50f2248d-2888-4178-bb8c-812e0ffa6425","outcome":"returned"}] -->
