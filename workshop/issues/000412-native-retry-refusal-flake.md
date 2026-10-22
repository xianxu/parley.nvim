---
id: 000412
status: working
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'a41eddb50f8e229260100258f886f32522d30388' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-22T12:53:55-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "2a278ef4", done: "738788d6"}
---

# Investigate native o-retry refusal flake on Neovim 0.11

## Problem

During #410 verification, Neovim 0.11.7 intermittently failed the existing `session-sync native edits retries refused admission with native o entry (#408 retry)` case in `tests/integration/session_sync_native_spec.lua`. The failure is in `refuse_insert_entry`, before the o-retry itself: after queuing native I and observing mode i, `assert.is_false(vim.bo.modifiable)` received true. Other retry keys and all remaining existing native cases passed. The new #410 late-autosaved baseline failure in that run is a separate, reproduced defect being fixed in #410.

The failing run used #410 code head c9dd02bb8d2b47b60b75e1f5b97209bcead7fb61: 151 pass, 2 fail, 0 errors across the native file (the second failure was the separate baseline defect). An isolated rerun of the same o-retry case on the same operator runtime, deliberately delaying the fake producer by 200 ms, passed 1/0/0. That rerun included unrelated in-progress #410 adoption/deadline corrections, so it is not claimed as exact-head fail-to-pass registry evidence. A subsequent corrected-head focused run also passed the o case with the pending-input matrix and Couch/architecture checks (80 cases total, zero failures/errors).

The initial failure captured only modifiable=true; it did not capture admission outcome, notifications, per-case duration or instantaneous machine load. Do not infer held refusal versus the approved 500 ms unavailable fallback from this observation. #410 adds notification/mode diagnostics to that assertion without changing its oracle. The tests share the workstation with other slots; elapsed suite times and current load are appended below, explicitly distinct from missing failure-time measurements.

## Spec

Identify whether native mode becomes observable before admission settles, or the fake producer legitimately exceeds its 500 ms budget under contention. Use explicit admission/process evidence and a reproducible controlled schedule. Preserve native I/o recovery coverage and the real refusal policy; do not weaken assertions or silently accept a retry pass.

## Done when

- Controlled reproduction distinguishes early observation from actual unavailable/refused/confirmed admission, with timing and load recorded.
- Test waits on the appropriate completed event and still fails when refusal protection is removed, or a demonstrated product defect is fixed with native regression coverage.
- The operator runtime and preferred runtime both pass; another load-sensitive failure records full diagnostics.
- Register the exact Lua identity once ariadne#556 provides a typed Lua flake registry/resume path. No Go test identity is fabricated.

## Plan

- [x] Pin the observed distinction with controlled native cases: completed explicit operator-lock refusal blocks editing; completed timeout/unavailable remains editable with the existing visible warning. Record outcome, elapsed time, mode, notifications, runtime and load; never infer refusal from mode alone (ARCH-ORDER).
- [x] In refuse_insert_entry only, give the external stateful fake the existing arrival.MS test budget; retain the production 500ms constant and real-deadline tests, including #410's pending-lookup cases. The override lives only in each disposable child. Observe completion after the attached InsertEnter handler returns, then assert the completed refusal and modifiable=false with diagnostics. Retain every native I/i/a/o/A/O retry assertion and queued-input oracle (ARCH-DRY, ARCH-PURPOSE).
- [ ] Prove the refusal oracle goes RED if refusal protection is removed. Run the relevant native retry/policy matrix on Neovim0.11.7 and preferred0.12.5, then the existing native/Couch/architecture tests serially with make -k. Update the harness guidance/lesson for separating product latency tests from behavioral fixtures; preserve diagnostic evidence for any further load failure.
- [x] Check the available registry contract: current flake register accepts Go package.TestName identities only. Lua registration remains conditional on ariadne#556; no Go identity is fabricated.

After targeted verification, push and run the recorded suite, close and land under normal gates.

No product state, deadline, parser or durable format changes are planned. Existing production admission model and fake_couch operator protocol remain the owners. The alternatives are waiting longer for modifiable=false (cannot turn a completed unavailable outcome into refusal) or widening the product deadline (changes operator policy); neither fixes this test's mixed contract. No hot-path cost changes. Existing child teardown and temporary-root cleanup own all probe state; no new durable artifact family. No new trust boundary or credentials.


## Log

- Implementation is test/docs only. The refusal helper now uses arrival.MS solely in its disposable child, observes the attached InsertEnter handler's completion, then asserts explicit refused/operator-lock plus nonmodifiable with elapsed time, mode, notice, bar, runtime and load diagnostics. Two deterministic raw-transport outcome controls drive the actual classifier/admission/native event path; existing stateful-process retry scenarios and all six native keys remain intact. No production file changed.
- Mutation RED /tmp/parley412-mutation-red.log: temporarily disabling only the production modifiable=false gate makes both the controlled refusal test and native o retry fail (0pass/2fail/0error, make exit2); original production bytes restored in finally and verified no diff. Refusal diagnostics identify actual refused/operator-lock at138.28ms with budget15000 and modifiable=true, so the enlarged fixture budget does not hide missing protection.
- Operator focused retry/policy run /tmp/parley412-focus-operator.log passes16/0/0. Preferred targeted /tmp/parley412-target-preferred.log passes native144, Couch19, arrival2 and owner2, all zero failures/errors. The command's exit2 is a temporary-map typo naming tests/unit/documentation_spec.lua (actual owner tests/integration/documentation_spec.lua), not a failing loaded test; corrected the map for subsequent verification. /tmp/parley412-lint.log passes823 files,0warnings/errors; diff-check clean. Full operator matrix and corrected documentation check pending.

- 2026-10-22: claimed after verifying the card unowned; start-plan completed on its own main-based branch. Catch-up regenerated only the unrelated workflow SIGPIPE correction; inspected and restored it before the successful start-plan retry. #411 independently verified merged at52b38427dc49b61d86b1d5385529258df8927afe, tracker done and matching archive.
- Controlled temporary probe /tmp/parley412-probe_spec.lua uses the existing fake's real executable seam with a pre-reply delay, captures the actual couch.operator_lock result and elapsed time, and reproduces both completed outcomes. /tmp/parley412-probe-operator-v2.log (Neovim0.11.7): delay0.2s returned refused/operator-lock at356.18ms, modifiable=false; delay2s returned unavailable at501.54ms, modifiable=true. /tmp/parley412-probe-preferred.log (Neovim0.12.5): corresponding367.32ms/refused/false and501.27ms/unavailable/true. Both2/0/0, clean child teardown. Mode observations already had a completed outcome in these probes; no early-mode observation established. Sampled machine load at12:58 local46.38/48.25/44.23; this is not failure-time load for the historical run.
- Root cause of the reproducible failure class: a behavioral refusal fixture relies on an external Python producer replying within the production500ms UI budget. When it does not, the approved unavailable policy intentionally leaves modifiable=true, invalidating the fixture's assumption. The original failure captured no outcome, so its exact historical cause remains unknown; these probes prove a sufficient mechanism, not retrospective certainty. An initial external-release-gate probe was stopped after it stalled; it supplies no behavior evidence. Corrected probes above use bounded real child delays.
- #410 author coordination: its only helper overlap is added mode/notification diagnostics. Its new pending-lookup cases exercise the actual shared500ms budget and must retain it. Restrict test-only budget control to refuse_insert_entry callers; #410 product optional deadline parameter is not required for this fix. Plan goes to hub before code.

Filed unclaimed at TL direction (Couch 97e1636a-a721-4076-a494-410d5296969b). TL explicitly said not to block #410 on this separate case. Until ariadne#556 lands, a recorded suite failure on this exact case allows one evidenced rerun under that instruction. No other unknown failure is covered by that exception.

Local evidence: `/tmp/parley-410-native-operator.log`, `/tmp/parley-410-refusal-red.log` (despite its diagnostic filename, outcome PASS), `/tmp/parley-410-corrections-operator.log`. Durable numeric results above remain understandable if temporary logs expire.

Log creation/modification times: native operator run 2026-10-22 12:06:50–12:07:50 -0700 (60 seconds for the complete file); isolated delayed-producer case 12:12:10–12:12:12 (2 seconds). These are whole-command/file observations, not per-case duration. Current load sampled at 12:13 -0700 was 20.35 / 33.58 / 39.16 (1/5/15-minute averages); load at the failure itself was not sampled.
