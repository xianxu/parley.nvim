---
id: 000430
status: wontfix
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '40b1e60e19424949e5e2efa6dd53a96800d8025a' # card fields mirrored from issue-cards; edit via sdlc
flake_tests: 
started: 2026-10-23T18:08:23-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Endpoint deadline test races Python startup and registry publication

## Problem

The #405 endpoint absolute-deadline native test assumes the fake Python process has started and published within 200 ms. An admitted request may legitimately time out before main() writes its PID or before it publishes; the reply gate only holds acknowledgment after publication. This produces false test failures while testing retained possibly-published state.

## Spec

Make the admitted/post-publication deadline-join proof independent of startup scheduling. Preserve separate coverage for deadline expiry before spawn/publication and for confirmed joined child death after publication. Keep the actual transport and stateful fake; do not hide the race with a longer fixed startup deadline.

## Done when

- The native case deterministically establishes the phase it asserts, including controlled slow startup/publication and delayed acknowledgment.
- Its deadline cancellation still proves joined native child death and preserves a possibly published binding.
- Both supported runtimes pass the targeted case repeatedly under normal load and the normal suite.

## Plan

- [ ]

## Log


- 2026-10-23: abandoned (wontfix): fixed in parley.nvim#421 (PR 346, merge 0620eaed)
2026-10-23: discovered during #418 integration, which changes only collaboration root-scalar parsing. Failed integrated suite attempt a0a1e7f89500e2baed04027a72f259ee on 41f876336c7b7a464ec11f2ba984e249b3a8f993: compatibility Neovim0.11.7, editor endpoint registry process boundary joins an admitted absolute deadline while retaining a possibly published binding, line199 E484 missing registry.json.editor-pid. Preferred runtime passed this file on the same code. The rest of that full suite completed; it also has a separately unclassified session-sync native failure, so this issue does not explain the whole red suite.

TL-authorized exact-case qualification on detached worktrees, original before_each/assertions/after_each, no source edits, artificial load or changed deadlines: pure main28526aa8eefe4da49b28bac04456f56e564ecaf2 has7 clean passes/3 failures (runs4,5,9 missing PID at line199); integrated41f876336c7b7a464ec11f2ba984e249b3a8f993 has9 clean passes/1 failure (run9: PID exists but lookup absent at line202). Both have0 teardown errors; every run selects exactly1 original case and has a clean final native census. Test/fixture/transport sources are unchanged across these heads.

Evidence retained locally in /Volumes/TestScratch/parley418-endpoint.HkbCmx: results.json, summary.json, HARNESS.txt, main-04.log, main-05.log, main-09.log and integrated-09.log. Integrated full failure log is .git/sdlc/test-stats/failed/a0a1e7f89500e2baed04027a72f259ee.log (SHA256 prefix7d8d5aba5bfa). Main targeted runs3/4/5/6 and integrated runs8/9/10 provide unchanged-head pass/fail/pass evidence. Legacy untyped full-suite extraction reports this Lua failure as unattributable-failure; registration does not authorize claiming that red run passed.
2026-10-23 (#421, parley.nvim:1, TL-approved): #430 now covers two cases. Registered the second: 'keeps the absolute-deadline observer until its native exit delivery joins'. Recorded suite attempt b85f2f86e9abd088beae56407b8ebb57 on 026def5de50522ccdeffff0a04e38309fddc7767 (nvim 0.12.5): its body passed, but the after_each drain at editor_endpoint_registry_spec.lua:70 (pending==0 within arrival.MS) timed out and was reported as a describe-level error. In 6 targeted runs of the file on the same tests and lua, this case passed 6/6 and the original #430 case failed 1/6 (line 199, missing PID). The #421 diff touches only remote_runtime_spec. Log: .git/sdlc/test-stats/failed/b85f2f86e9abd088beae56407b8ebb57.log. Root cause not established.
- 2026-10-23: fixed in #421 (TL-approved fold). Both absolute-deadline cases now hold the deadline timer through the helper.start_deadline seam and fire it only after the fake has published and holds its acknowledgment (a new PATH.held marker) and the deadline has really passed. fake_couch_editor.py writes editor-pid, editor-argv and .held atomically. Controls: S (the fake sleeps 0.5 s before its PID write) reproduces both registered shapes on the old spec, while the new spec passes 12/12; J (expiry without join) fails both cases. 20/20 under capped load. Both cases unregistered. Hours are measured under #421.
