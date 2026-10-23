---
id: 000431
status: open
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'd334d63d1c7016ff3d114e38d146d3735162c1b8' # card fields mirrored from issue-cards; edit via sdlc
---

# Native release-journal test intermittently loses its setup lock

## Problem

The native session-sync test retained release journal respects current intent at after-new/before-restore (#404) intermittently cannot open status.md.lock while setting up its asserted journal/intent state. The original error is line1238, Error executing lua: io.open/assert: No such file or directory. This is a separate case from the8-turn release failure being classified for #418.

## Spec

Identify whether fixture setup races a valid clean release or production loses required protection, then correct the owning event/order. Keep the before-restore current-intent protection invariant and the normal native adapter; do not replace it with a longer fixed sleep or weaker existence assertion.

## Done when

- The original missing-lock ordering has deterministic reproduction coverage.
- The native journal/intent setup proves its required lock and the test exercises the intended production transition.
- All current-intent journal variants pass on both supported Neovim runtimes, including repeated native qualification.

## Plan

- [ ]

## Log

2026-10-23: independent discovery in TL-authorized #418 failure classification, not a #418 code change. Exact pure-main head28526aa8eefe4da49b28bac04456f56e564ecaf2, Neovim0.11.7, full targeted tests/integration/session_sync_native_spec.lua with original before_each/assertions/after_each: runs1/2/3 all144 pass; run4 has143pass/1fail in this case; run5 all144 pass again on unchanged code. All censuses clean, no source edits, artificial load or changed timeouts. The original8-turn case passed every one of these runs; do not conflate the cases.

Evidence /Volumes/TestScratch/parley-418-native-ltjs_uc3/main-full-4.log plus main-full-1.log through main-full-5.log, full-results.json and run-full.py. Main/integrated session_sync implementation and this test file are byte-identical. The failing excerpt is: session-sync native edits retained release journal respects current intent at after-new/before-restore (#404); tests/integration/session_sync_native_spec.lua:1238; embedded_nvim.exec line61; fixture Lua line8 cannot open status.md.lock. Same-head run5 is the clean pass after failure. Filed unclaimed for repair; no work on it is stacked into #418.
