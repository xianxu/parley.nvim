---
id: 000431
status: open
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '34e60d673a9ad51e25886197299ff6e60d337b6a' # card fields mirrored from issue-cards; edit via sdlc
flake_tests: [lua:tests/integration/session_sync_native_spec.lua#session-sync native edits retained release journal respects current intent at after-new/before-restore (#404)]
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

### 2026-10-23 — separate pre-detach setup observation, association unproven

During #322's recorded full suite on b9135976daa17a4a2986cb1fd1b8e02fd4708e9d, compatibility Neovim0.11.7 fails a different exact case: session-sync native edits detaches without unlocking and preserves user option overrides. The failure is line983 locked()->payload line30: expected complete status.md.lock payload, observed nil, before detach executes. Native file143pass/1fail; all remaining suite tests finished with clean censuses. The same suite also hits the independently registered #430 startup case. Official suite attempt2f462d85c36ec3d495801235b68a6e90 remains unattributable-failure,5m35s, log SHA256 prefixbad51e771dcc in .git/sdlc/test-stats/failed/2f462d85c36ec3d495801235b68a6e90.log.

TLd28a162c authorized exactly10 isolated executions of this original native case on basec50641e7c54bc648d0e3e2b5c3e7ab398343c25f and10 on the tested branch, no whole-spec repeat. Results: base10pass/0fail/0error, branch10pass/0fail/0error;0/20 failures. Each run proves one exact original case, original setup/teardown once, before/after process census and terminal clean. Both detached source trees remained clean at pinned heads. Source test and session_sync implementation are byte-identical across the heads. These samples do not establish base intermittency, a cause, or the same cause as the original release-journal observation. Retain them as an explicitly unproven association in this repair issue, not a production diagnosis.

Evidence /Volumes/TestScratch/parley-322-detach.wFHlYs/{HARNESS.md,summary.json,results.json,commands.json,metadata.json,run.py} and20 rawlogs. Copied36 evidence files outside RAM scratch to .git/sdlc/diagnostics/322-detach-classification. Original full failure remains separate from targeted passes. TL84474907 explicitly authorizes registration of the exact new case as an unreproduced exception (same policy as #432), followed by one full #322 retry; do not infer classification from an incidental later pass. No product or test-source correction is made under #322. This issue stays unclaimed for its owning repair work.
