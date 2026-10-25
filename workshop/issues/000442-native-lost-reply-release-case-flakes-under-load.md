---
id: 000442
status: working
deps: []
github_issue:
created: 2026-10-24
updated: 2026-10-24
estimate_hours:
card_mirror: '00dd99dba20659ce43a046e320417cbcd8e6c853' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-24T11:57:59-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flake_tests: [lua:tests/integration/session_sync_native_spec.lua#session-sync native edits retries a clean release whose reply was lost and the next turn is new (#432)]
flow: {kind: quick, provenance: inferred, spec: "16c72df1", done: "ad6b782e"}
---

# Native lost-reply release case flakes under load

## Problem

The #432 case 'retries a clean release whose reply was lost, so the next turn is new (#432)' in tests/integration/session_sync_native_spec.lua failed 2 of 40 reps under capped load. The load was 3 CPU spinners plus an fsync dd loop, on top of the fleet, in a disposable clone of the #427 branch at 300c65f2, on 2026-10-24.

- nvim 0.11.7, rep 19: E484 'Can't open file .../status.md.lock' in turn_of_lock (:697), called at :716. The case reads the lock right after `wait_for(mode=='i')`, but mode i does not mean the admission has finished: the acquire had not written the lock yet. This is a test bug: wait for the lock (exists()) before reading its turn.
- nvim 0.12.5, rep 1: the final `vim.wait(arrival.MS, not exists())` at :724 timed out (-1). The second turn's lock was still there 15 s after its Esc. Not diagnosed: the earlier wait counts the retry when it starts (its trace line), not when it completes. The second turn's i may therefore have raced the retry's completion. Needs a trace.

## Spec

Fix the first-turn read so it waits for the admitted lock. Trace the second failure under the same load and fix its cause. If it is a product race between a release retry and a new turn's acquire, that is a #432 defect, not just a test defect.

## Done when

- Both failures are explained with evidence.
- The case passes 20 reps per nvim under the same capped load.
- The flake registration comes off at close.

## Revisions

- 2026-10-24, TL-approved scope and evidence changes (close review BR-3):
  - Scope adds the product fix: a clean turn whose acquire is unconfirmed releases by its turn token, and a retry of that release reconciles a lost reply.
  - Done-when's "both failures are explained with evidence" is met for the second failure by a deterministic probe, which is the primary evidence (TL). The probe reproduces the symptom by forcing the mechanism. That failure was not observed again under the original load.
  - Done-when's "20 reps per nvim under the same capped load" became 10 reps per nvim under fleet load alone, with no added stress (TL alternative: load was 38 to 56, over the cap of about 20 for added stress).

## Plan

- [x] Shared insert() helper: entry waits for an InsertEnter observer that runs after the production admission, swept over the 13 mode-i sites in the native spec (TL approved).
- [x] Product fix (TL-approved scope add): release_if_baseline releases a clean unconfirmed turn by the lock bearing its turn token, through #432's bounded retry.
- [x] Regression case from the deterministic probe: red on the base session_sync.lua, green with the fix.
- [x] Atlas: modes/session_sync.md names the unconfirmed-acquire release.
- [x] Targeted runs (infra/test_harness, modes/session_sync) on 0.11.7 and 0.12.5.
- [x] Load reps of the #442 cases: 10 per nvim, since the load was over 20 (noted in the Log).

## Log

### 2026-10-24

Registered as a flake during #427's pre-close attribution (evidence, as registered): #427 load reps on 300c65f2 failed this case on nvim 0.11.7 rep 19 (E484 at turn_of_lock :697, called at :716) and on 0.12.5 rep 1 (lock not gone at :724). Load was 3 CPU spinners plus an fsync dd loop, on top of the fleet.

First-turn cause (read from the spec): `wait_for(mode=='i')` is not admission completion. The InsertEnter acquire waits on a subprocess, and the harness's exec RPC is answered during that wait, with the mode already i. The spec already knows this: `observe_insert_admission` is documented as "rather than treating mode i as admission completion". The same shape repeats at every site that reads admission effects (lock, winbar, modifiable) straight after a mode-i wait, so the fix is a shared helper, not one site (ARCH-PURPOSE, ARCH-DRY).

Second failure, traced in a disposable clone, with this case alone and a wrapper logging every operator_lock call. Under fleet load alone (load about 20, no added stress), 10 reps per nvim all ended with the lock gone. Operator calls took 35 to 140 ms, against a 500 ms budget, so this path needs the capped load to hit. A deterministic probe reproduces the symptom. The second turn's acquire reply was delayed past its budget with FAKE_COUCH_OPERATOR_DELAY=1: the effect lands and the reply is lost. Then Esc on a clean buffer. Result: the lock is still there 8 s later, with no notice, and the bar reads 'not locked: Couch unreachable; edits may conflict' while the lock exists. release_if_baseline needs a confirmed owned_lock, so a clean turn whose acquire is unconfirmed never releases; only the next i reconciles it. Asked the TL whether the fix belongs to #442.

TL approved (2026-10-24) the helper sweep and the scope add: on Esc, a clean turn with an unconfirmed acquire releases by its turn token, with #432's bounded retry, and the probe-built regression as the primary evidence. Capped-load reps are allowed while the 1-minute load is under about 20, one at a time, with no dd loop alongside a running suite.

Fix: a new turn_lock(buf, s) gives the turn's lock bytes. That is the confirmed proof, or, for an unconfirmed acquire, the lock whose document and turn match this turn. release_owned already accepts a proof by acquire token. If an unconfirmed acquire never landed, there is nothing to release, and the next i retries the same turn (#408). An unconfirmed turn with an edit keeps its lock, as the baseline check requires; the #408 lost-acknowledgment case asserts this.

Control: the new case 'releases a clean turn whose acquire landed but lost its reply (#442)' fails on the base session_sync.lua at 'the clean unconfirmed turn kept its lock' and passes with the fix (0.12.5, disposable clone at 885cf610).

Targeted runs outside the sandbox: infra/test_harness and modes/session_sync passed on 0.11.7 and 0.12.5. One 0.12.5 harness run failed '#220 orphan census serializes real targeted runs and retains orphan cleanup (#409)': its Python unittest hit the 30 s wait (exit 124) at load about 40. #442 touches no harness code, and the rerun passed. A first attempt inside the sandbox failed on spawn EPERM and missing ps; it is not evidence.

Load reps: the 1-minute load was 38 to 56 throughout, well over the TL's cap of about 20 for added stress. So, per the TL, these were 10 reps per nvim, with no spinners and no dd loop, instead of 20 under capped load. The two #442 cases (the lost-reply case and the new regression) passed 20 of 20 on 0.11.7 and 20 of 20 on 0.12.5, two cases per rep. The fleet load alone exceeded the #427 capped load, which was about 30 to 37 with stress.

Close review round 1 (FIX-THEN-SHIP), addressed:
- BR-1: a retry of an unconfirmed turn's release could not reconcile a lost reply. turn_lock re-read the lock, which the landed release had removed, so the retry returned before sending. The retry now carries the bytes its first try released (retry_release, then release_if_baseline's retried argument). New case: 'retries an unconfirmed turn's release whose reply was lost and the next turn is new (#442)'.
- BR-2: one more site, plus the same class in the spaced-quote spelling: insert mode, then a vim.schedule barrier, taken as proof of admission. The barrier can run during the admission's wait. The reviewer named one site (normal-mode edit and insert). An enumeration of every mode-i wait found six more in the spaced spelling, at the insert-turn, foreign-replacement, refused-entry, foreign-before-escape, late-attach and rename cases. All seven now use insert(typed). Detached and unregistered sites, which assert absence, are left as they are.
- BR-3: the Revisions section above records the scope add and the Done-when changes.
- BR-4 (Minor): of_turn(s, proof) is now the single ownership check, used by release_owned and turn_lock (ARCH-DRY).
