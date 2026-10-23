---
id: 000424
status: open
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '98f233afee120a4fc872ce7daa0c2afbd944f7cf' # card fields mirrored from issue-cards; edit via sdlc
flake_tests: [lua:tests/integration/document_fold_uncertainty_retirement_spec.lua#native suspended fold retirement restores the operator preference and view when detach interrupts suspended uncertainty]
---

# fold retirement timeout: root cause from captured evidence

## Problem

The native suspended fold-retirement timeout recorded during #410 remains unexplained. #420 lands bounded evidence capture in both retirement fixtures; its controlled fan-out did not reproduce the failure and does not claim a root-cause fix.

## Spec

Use evidence from the next real recurrence, rather than blind replay or a timeout increase. Keep this issue unclaimed until such evidence arrives.

Exact flake registration identity (this follow-up owns the open registration):
lua:tests/integration/document_fold_uncertainty_retirement_spec.lua#native suspended fold retirement restores the operator preference and view when detach interrupts suspended uncertainty

On recurrence, preserve the recorded attempt, revision, raw log and its hash. Read the FOLD_RETIREMENT evidence added by #420: last captured stage, runtime/JIT version, load, wall/CPU time, repair/native work counts and VM profile. The original foldenable/view behavior assertions and request budget remain authoritative. Distinguish advancing setup, native OptionSet retirement, compiler allocation and process scheduling using captured evidence before choosing a correction. Retain this registration until the demonstrated mechanism is fixed; closing #420 as diagnostics must not retire the known flake.

Historical evidence: failed recorded #410 suite on d74f24b15ae4fa9d9393e4bf1b5b166335887eb1, attempt c2c4dbbdbfc2dc8a8b8a35131c503fb2. The installed Neovim0.11.7 child did not answer nvim_exec_lua within27862ms. Raw log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/c2c4dbbdbfc2dc8a8b8a35131c503fb2.log, SHA256 e285308fc37374072ff54fbc702679242ce1531654f8c600095dfaa61eb20068. The timeout is not a diagnosis; original stage/load were not recorded.

An isolated run of the original unmodified spec and unchanged product code subsequently passed1/0/0: /Volumes/TestScratch/parley-410-fold-timeout.d7zvmrdd/repro.log, SHA256165369195576e88f03dc03378508b12d342850cb7835e0dbedd75d0ce42738b4. It was outside the recorded test-stats store; no typed exact-head pass record is manufactured. #420 retained source comparisons and later diagnostic evidence: one nine-file/eight-worker cohort on each runtime passed63/0/0, and final diagnostics/guard checks17/0/0 each. Its Log preserves numeric results if scratch logs expire. No cause is inferred from those passes.

## Done when

- A recurrence's captured evidence identifies a concrete mechanism; record both what is established and what remains unknown.
- A deterministic regression/negative control exercises that mechanism while preserving native retirement preference/view assertions.
- Fix the owning code or fixture, verify both supported runtimes and the required recorded gate, and only then retire the open flake registration.

## Plan

- [ ]

## Log

Filed unclaimed at hub direction ff4e7f1b-f39a-4575-8ccf-0f9ef5f8b6a6. Root-cause investigation is intentionally separate from #420's completed evidence-capture deliverable. No new rerun or guessed guard is authorized by this filing.


Registration evidence: sdlc flake register accepted the exact Lua case above on #424 with explicit external evidence. Recorded failure attempt c2c4dbbdbfc2dc8a8b8a35131c503fb2 on d74f24b15ae4fa9d9393e4bf1b5b166335887eb1 timed out after27862ms on installed0.11.7; immutable failure log and hash are in Spec. The original unchanged fixture/product subsequently passed1/0/0 outside test-stats (repro.log and hash in Spec). This is historical fail/pass evidence, not a typed exact-head recorded pass. Registration remains active; the card is unclaimed.
