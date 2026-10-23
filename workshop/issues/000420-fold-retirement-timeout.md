---
id: 000420
status: open
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: '4026f234f46ee01516018e7a2277c7f688190084' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-22

Filed unclaimed at hub direction be6c21ea-6e38-4fe8-9e3d-3a2481a5da1a after #410's integration suite completed. Related #412 and #414 concern native timing under load; no shared root cause is proven. No code change, blanket budget increase, or automatic flake registration made.
