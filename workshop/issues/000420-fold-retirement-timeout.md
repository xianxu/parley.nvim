---
id: 000420
status: working
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'a0c76520481242289cef71c26bc591ca08cc904a' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T09:28:51-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "e5e0b872", done: "241b8a59"}
---

# Investigate embedded fold-retirement timeout under native suite load

## Problem

A complete recorded #410 integration suite passed its preferred runtime but failed one suspended-fold retirement case on installed Neovim 0.11.7. A subsequent isolated run of the exact same case and product code passed. The precise hang cause is unproven; this is linked to the #412/#414 native timing-under-load family for investigation, not asserted to share their root cause.

## Spec

Failing file: tests/integration/document_fold_uncertainty_retirement_spec.lua, line10. Exact case: native suspended fold retirement restores the operator preference and view when detach interrupts suspended uncertainty.

Recorded full suite on d74f24b15ae4fa9d9393e4bf1b5b166335887eb1: attempt c2c4dbbdbfc2dc8a8b8a35131c503fb2; suite make exit2 after5m34s, outer command exit1. Installed0.11.7 child did not answer nvim_exec_lua within27862ms; embedded helper killed child PID5505. This was the only failed file. Preferred runtime and both session_sync_native runs passed; every process census was clean. Immutable failure log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/c2c4dbbdbfc2dc8a8b8a35131c503fb2.log, SHA256 e285308fc37374072ff54fbc702679242ce1531654f8c600095dfaa61eb20068, failure lines1718–1735. No per-case load or elapsed stage trace was captured;27862ms is the helper's load-scaled request bound, not a diagnosis.

One bounded isolated reproduction on unchanged product code and installed0.11.7: PARLEY_TEST_NVIM=/opt/homebrew/bin/nvim make test-spec SPEC=diagnostic/fold-retirement MAP_FILE=/Volumes/TestScratch/parley-410-fold-timeout.d7zvmrdd/map.yaml. The scratch map selects only the original unmodified spec. Result exit0, exact case1 success/0 failed/0 errors, clean process census. Log /Volumes/TestScratch/parley-410-fold-timeout.d7zvmrdd/repro.log SHA256165369195576e88f03dc03378508b12d342850cb7835e0dbedd75d0ce42738b4. Individual duration/load was not recorded by this targeted runner. The fixture, tests/helpers/embedded_nvim.lua and lua/parley/tool_folds.lua are unchanged from integrated main bbf1294da084d456cb82b2de78aeea2fd30e3e4a; no product/test/timeout fix between failure and pass. Later #410 commits contain only Log evidence.

#415 typed Lua adapter is not adopted here, so the recorded suite classifies this as unattributable-failure; no supported Lua resume path is claimed. TL authorizes one evidenced same-code full-suite rerun for #410, and stop/report if the case repeats. Keep this issue unclaimed; do not block on adapter adoption.

## Done when

- Identify the cause of the embedded fold-retirement timeout with evidence, including runtime and load where relevant.
- Add a deterministic regression or justified harness correction while preserving the fold/view retirement behavior assertion.
- Verify the correction on both supported test runtimes; retain fail/pass evidence.

## Plan

- [ ] Preserve the exact single-request fixture order and instrument module/setup, repair, manual folds, suspension and OptionSet detach boundaries; capture runtime, machine load, counts and JIT profile. Separate a stalled native retirement from expensive fixture setup before selecting a fix.
- [ ] Test the resulting hypothesis with a controlled reproducer and an unchanged-timeout comparison. Prefer the existing operation owner and jit_tuning policy over a new timeout or parallel lifecycle (ARCH-DRY, ARCH-ORDER).
- [ ] Send the evidence-backed fix plan to the hub before code. Preserve the original foldenable/view assertions; the correction needs a deterministic regression and both supported runtime checks.


## Log

### 2026-10-22

Filed unclaimed at hub direction be6c21ea-6e38-4fe8-9e3d-3a2481a5da1a after #410's integration suite completed. Related #412 and #414 concern native timing under load; no shared root cause is proven. No code change, blanket budget increase, or automatic flake registration made.

## Revisions

### 2026-10-23 — Dispatched investigation

The hub lifted the shutdown freeze and explicitly assigned #420 to parley.nvim:2, superseding the filing-time instruction to keep it unclaimed. Investigation does not assume the #412/#414 cause and will not raise the request deadline. Start-plan completed on its own main-based branch; catch-up now defers the seeded workflow update rather than dirtying the checkout.

### Investigation checkpoint

- Original immutable failure excerpt confirms the only location is the single nvim_exec_lua at spec line10; no inner stage trace exists. Current installed runtime is Neovim0.11.7/LuaJIT2.1.1741730670; preferred0.12.5/LuaJIT2.1.1788856981. Machine load sampled09:29 local47.22/36.81/30.33, not original-failure load.
- Read-only peer trace finds native deletion bounded128 operations and guarded detach ownership. Initial D.drain permits200000 synchronous steps; anonymous fixture loops are outside the module-level jit_tuning protections. Both are hypotheses until stage/profile evidence distinguishes them. Next: bounded temporary probe with stage witnesses inside the same RPC; no product/test changes yet.

### 2026-10-23 — Evidence and next investigation plan

The timeout is not yet reproduced; no product or test correction is justified by these passing probes. The unchanged target fixture and product document/tool-fold/native/JIT modules are byte-identical to the failed d74f24b15ae4fa9d9393e4bf1b5b166335887eb1 revision. The embedded helper has since gained fixture ownership/cleanup, so current probes do not establish behavior of the old helper's complete environment.

Temporary stage probe: /Volumes/TestScratch/parley420-probe.t96o2lo2. It preserves the original one-RPC ordering and all fold/view assertions. Installed0.11.7 completed in658.79ms (initial drain639.02ms); fixture-chunk interpreter protection comparison723.09ms (drain645.54ms), so that comparison shows no allocator stall. Preferred0.12.5 completed1278.93ms. These1/0/0 runs are diagnostics, not exact-head historical flake evidence or a fix. No deadline changed.

Six fresh installed0.11.7 children: /Volumes/TestScratch/parley420-jit.kjte5ml5/run.log; all6/0/0, clean process census. Fixture elapsed718.12–818.56ms, all six had0 trace flushes (5–7 aborts,5–6 completed traces). Every stage witness reached suspension, OptionSet detach enter/exit and retirement; initial document drain dominates. Sampled machine load09:33 was98.38/71.50/47.53. High current load alone did not reproduce the timeout; original failure-time load remains unknown. A near-identical reconstruction-retirement fixture and bounded native walk provide controls, not proof of a root cause.

Proposed next plan to hub, before code:

1. Add bounded stage/cost witnesses to the target and companion single-RPC native retirement fixtures, preserving callback order and the original foldenable/view assertions. On a failed request, report the last completed stage, current runtime/JIT, elapsed time, repair/native operation counts and machine load. Keep evidence readable before teardown removes child-owned fixtures. Do not split the RPC, run synthetic machine-wide load or increase any deadline.
2. Run a bounded diagnostic replay through the normal native fan-out on the operator runtime and compare with preferred runtime. Distinguish (a) advancing/overgrown setup, (b) native OptionSet retirement stall, (c) compiler allocation thrash, and (d) process scheduling/starvation using actual captured evidence. Do not apply interpreter protection or a budget change just because it is plausible.
3. Only after a mechanism is established, write its deterministic reproducer/negative control and fix the owning code or fixture. Preserve both native retirement assertions and both runtime checks. If the instrumented replay still does not reproduce, keep #420 open and send the evidence to the hub for a decision; no guessed fix or SHIP claim.

No correction has been selected; stage diagnostics are the proposed investigation work, not completion of the root-cause contract. ARCH-DRY: retain embedded_nvim and existing fold/document owners. ARCH-ORDER: avoid event-loop turns between stages and retain OptionSet reentrancy. No operator state, storage format or production hot path change is proposed. Diagnostics are bounded per test case and removed after evidence is reported; no new durable production artifact family.
