---
id: 000432
status: open
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'c6eaaa01c1342fed31f5007a885d90357a64d195' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

2026-10-23: failed once in #418 integrated full-suite attempta0a1e7f89500e2baed04027a72f259ee at41f876336c7b7a464ec11f2ba984e249b3a8f993, Neovim0.11.7. File result143pass/1fail, case line642 expected true for wait until lock disappears. Preferred runtime passed on that same code; final censuses were clean. Saved official failure log .git/sdlc/test-stats/failed/a0a1e7f89500e2baed04027a72f259ee.log, SHA256 prefix7d8d5aba5bfa.

TL37eda85e/c1466bf8 capped diagnosis and explicitly directed filing/registering even if the failure does not reproduce, then one integrated-suite retry, with no further repair work inside #418. Exact isolated original case under original native setup/assertions/teardown: pure main28526aa8eefe4da49b28bac04456f56e564ecaf2 has10/10 clean passes, integrated41f876336c7b7a464ec11f2ba984e249b3a8f993 has10/10 clean passes. Ten complete native-spec repetitions on pure main also pass this exact case10/10; whole-file results8 clean files and2 files each failing a different sibling case, not this case. All censuses clean. No product/test source, deadline or load manipulation.

Thus this is one full-suite occurrence versus0/20 isolated failures and0/10 whole-spec case failures; pure-main causality is not established. Same integrated head has failure then10 unchanged isolated passes. Evidence /Volumes/TestScratch/parley-418-native-ltjs_uc3/results.json, full-results.json, run.py, run-full.py and per-run logs. Both target test and session_sync/document_registry sources are byte-identical across pinned main/integrated heads. Separate endpoint deadline flake is#430; the journal sibling is#431; other sibling failures are independent. Filed unclaimed for root-cause repair, not patched or stacked into #418.
