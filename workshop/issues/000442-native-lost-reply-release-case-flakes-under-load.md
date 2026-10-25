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

## Plan

- [x] Shared insert() helper: entry waits for an InsertEnter observer that runs after the production admission, swept over the 13 mode-i sites in the native spec (TL approved).
- [x] Product fix (TL-approved scope add): release_if_baseline releases a clean unconfirmed turn by the lock bearing its turn token, through #432's bounded retry.
- [x] Regression case from the deterministic probe: red on the base session_sync.lua, green with the fix.
- [x] Atlas: modes/session_sync.md names the unconfirmed-acquire release.
- [ ] Targeted runs (infra/test_harness, modes/session_sync) on 0.11.7 and 0.12.5.
- [ ] Capped-load reps of the #442 cases, 20 per nvim while load is under about 20 (otherwise 10, noted here).

## Log

### 2026-10-24

Registered as a flake during #427's pre-close attribution (evidence, as registered): #427 load reps on 300c65f2 failed this case on nvim 0.11.7 rep 19 (E484 at turn_of_lock :697, called at :716) and on 0.12.5 rep 1 (lock not gone at :724). Load was 3 CPU spinners plus an fsync dd loop, on top of the fleet.

First-turn cause (read from the spec): `wait_for(mode=='i')` is not admission completion. The InsertEnter acquire waits on a subprocess, and the harness's exec RPC is answered during that wait, with the mode already i. The spec already knows this: `observe_insert_admission` is documented as "rather than treating mode i as admission completion". The same shape repeats at every site that reads admission effects (lock, winbar, modifiable) straight after a mode-i wait, so the fix is a shared helper, not one site (ARCH-PURPOSE, ARCH-DRY).

Second failure, traced in a disposable clone, with this case alone and a wrapper logging every operator_lock call. Under fleet load alone (load about 20, no added stress), 10 reps per nvim all ended with the lock gone. Operator calls took 35 to 140 ms, against a 500 ms budget, so this path needs the capped load to hit. A deterministic probe reproduces the symptom. The second turn's acquire reply was delayed past its budget with FAKE_COUCH_OPERATOR_DELAY=1: the effect lands and the reply is lost. Then Esc on a clean buffer. Result: the lock is still there 8 s later, with no notice, and the bar reads 'not locked: Couch unreachable; edits may conflict' while the lock exists. release_if_baseline needs a confirmed owned_lock, so a clean turn whose acquire is unconfirmed never releases; only the next i reconciles it. Asked the TL whether the fix belongs to #442.

TL approved (2026-10-24) the helper sweep and the scope add: on Esc, a clean turn with an unconfirmed acquire releases by its turn token, with #432's bounded retry, and the probe-built regression as the primary evidence. Capped-load reps are allowed while the 1-minute load is under about 20, one at a time, with no dd loop alongside a running suite.

Fix: a new turn_lock(buf, s) gives the turn's lock bytes. That is the confirmed proof, or, for an unconfirmed acquire, the lock whose document and turn match this turn. release_owned already accepts a proof by acquire token. If an unconfirmed acquire never landed, there is nothing to release, and the next i retries the same turn (#408). An unconfirmed turn with an edit keeps its lock, as the baseline check requires; the #408 lost-acknowledgment case asserts this.

Control: the new case 'releases a clean turn whose acquire landed but lost its reply (#442)' fails on the base session_sync.lua at 'the clean unconfirmed turn kept its lock' and passes with the fix (0.12.5, disposable clone at 885cf610).
