---
id: 000432
status: working
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-24
estimate_hours:
collaboration-mode: collaboration
card_mirror: '182b6637fd06fb2812fe6d06b54e7864685f742a' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T23:11:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flake_tests: [lua:tests/integration/session_sync_native_spec.lua#session-sync native edits bounds operator calls and full reads across 8 confirmed turns (#408)]
flow: {kind: quick, provenance: inferred, spec: "4e477201", done: "74febb49"}
---

# Native eight-turn clean release intermittently retains its lock

## Problem

One compatibility full-suite occurrence of session-sync native edits bounds operator calls and full reads across 8 confirmed turns (#408) failed at session_sync_native_spec.lua:642: clean acquisition-baseline release was not observed within the existing arrival wait. The failure is not reproduced by the bounded qualification below; its root cause remains unknown.

## Spec

Capture and reproduce the native insert/escape/clean-release ordering, preserving the operator-call/full-read budget and lock ownership. Establish whether a prior-case interaction, unconfirmed helper response or native event ordering retains the turn. Do not weaken ownership or replace the failure with a longer sleep.

## Done when

- A deterministic regression demonstrates the original release-not-observed state.
- The owning transition/fixture is corrected without weakening protection or the call/read budget.
- The exact case and complete native spec pass on both supported runtimes under repeated normal-load qualification.

## Plan

Cause (reproduced, Log 2026-10-24): a clean release whose `couch operator-release` is killed at the 500 ms budget before its effects comes back unavailable (code 124). The admission records release_failed, nothing retries it, and the lock stays until the next turn or a submit. Before #431 a stale-clock kill could end the same way; after #431 only a real overrun does, which is rare under suite load.

State design table. Actions: the automatic clean release (InsertLeave, or undo back to the baseline), the next insert, submit, and detach.

| Internal state / failure mode | Visible state | Recovery action | Possible loss |
|---|---|---|---|
| release confirmed | free band | none | none |
| release killed before effects (lock present, ours) | operator band, then free after the retry | automatic bounded retry; after that, the next insert and Esc, or submit | none; the agent waits up to the retry window |
| release killed after effects (lock gone, reply lost) | free band; the admission still holds history | the retry gets already-released, which confirms and resets the admission | none |
| release refused (foreign or changed protection) | unchanged, as today | no retry (definitive); the next turn, as today | none |
| retries exhausted (Couch really unreachable) | operator band, one WARN | the next insert and Esc, or submit | none |
| user re-enters insert, edits, or detaches during the retry window | per the new turn | the retry re-checks and drops itself | none |

- [x] Fake: promote FAKE_COUCH_OPERATOR_PRE_DELAY (seconds before effects, for the verbs in _OPS) into fake_couch_operator.py.
- [x] Regression first: the 8-turn ordering with turn 3's release delayed past 500 ms before its effects, and the lock is gone within the arrival wait; a second case with the delay after the effects, where the next turn takes a fresh acquire. Both fail on main (the negative control).
- [x] Fix (ARCH-ORDER: an unconfirmed outcome is not a failure): dispatch_admission reports whether a release_failed was unavailable (unknown) or refused. release_if_baseline schedules a bounded retry for unavailable only: helper.defer_deadline at 1, 2 and 4 s. Each try re-checks epoch and state, not inserting, content at the baseline, and the lock absent or ours, then re-dispatches the same token's release. One WARN once the tries run out. Release is idempotent per turn token, so a retry after a lost reply confirms already-released.
- [ ] Both nvims, 20 reps under capped load; the suite; close, which unregisters the flake.

## Log

### 2026-10-24 — causal reproduction (parley.nvim:1)

- Disposable clone at main 0675cc21 (with #431), operator_lock traced (verb, code, kind, whether the lock exists after). Case: the 8-turn ordering cut to 4, with turn 3 perturbed and a 3 s probe wait.
- Stall before release (loop blocked 1200 ms): the release was confirmed, the lock was gone, and every turn passed. The stale clock no longer matters after #431.
- Release delayed 1 s before its effects (new FAKE_COUCH_OPERATOR_PRE_DELAY knob on operator-release): release code=124 sig=15 kind=unavailable lock=true, and the lock was not gone after 3 s. No later operator call: release_failed is accepted and nothing retries the clean release (restart_idle only marks stale after 5 minutes). That is #432's observed state (line 642: the lock does not disappear within the 15 s arrival wait).
- TL approved the bounded retry and added a case: a retry racing a new turn's acquire. After a failed release the admission keeps its token, so the next insert's acquire reuses it, and the token alone cannot tell the turns apart. Every acquire, and every fresh (non-retry) release, bumps s.release_generation. A retry runs only while the epoch and the generation are unchanged, then still re-checks the baseline guards.
- Regressions (session_sync_native_spec): release killed before its effects at turn 3 of 4 (the lock is gone within the arrival wait); reply lost after the effects (a second release is traced and the next turn's lock has a new token); a new turn edits during the retry window (no further release, lock kept). With main's session_sync (negative control) the first two fail and the race case passes, as it must with no retry to race. Note: the race case is stopped by the generation and also by the baseline check (the new turn's edit), so it does not isolate the generation alone. In this design no ordering exists where only the generation decides: a new turn undone back to its baseline is released by the undo path anyway.
- modes/session_sync and infra/test_harness mappings green on 0.11.7 and 0.12.5. The only failures were #427's undo/redo cases, on 0.11.7.

2026-10-23: failed once in #418 integrated full-suite attempta0a1e7f89500e2baed04027a72f259ee at41f876336c7b7a464ec11f2ba984e249b3a8f993, Neovim0.11.7. File result143pass/1fail, case line642 expected true for wait until lock disappears. Preferred runtime passed on that same code; final censuses were clean. Saved official failure log .git/sdlc/test-stats/failed/a0a1e7f89500e2baed04027a72f259ee.log, SHA256 prefix7d8d5aba5bfa.

TL37eda85e/c1466bf8 capped diagnosis and explicitly directed filing/registering even if the failure does not reproduce, then one integrated-suite retry, with no further repair work inside #418. Exact isolated original case under original native setup/assertions/teardown: pure main28526aa8eefe4da49b28bac04456f56e564ecaf2 has10/10 clean passes, integrated41f876336c7b7a464ec11f2ba984e249b3a8f993 has10/10 clean passes. Ten complete native-spec repetitions on pure main also pass this exact case10/10; whole-file results8 clean files and2 files each failing a different sibling case, not this case. All censuses clean. No product/test source, deadline or load manipulation.

Thus this is one full-suite occurrence versus0/20 isolated failures and0/10 whole-spec case failures; pure-main causality is not established. Same integrated head has failure then10 unchanged isolated passes. Evidence /Volumes/TestScratch/parley-418-native-ltjs_uc3/results.json, full-results.json, run.py, run-full.py and per-run logs. Both target test and session_sync/document_registry sources are byte-identical across pinned main/integrated heads. Separate endpoint deadline flake is#430; the journal sibling is#431; other sibling failures are independent. Filed unclaimed for root-cause repair, not patched or stacked into #418.
