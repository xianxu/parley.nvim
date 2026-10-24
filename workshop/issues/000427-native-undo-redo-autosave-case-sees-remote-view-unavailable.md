---
id: 000427
status: working
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-24
estimate_hours:
collaboration-mode: collaboration
card_mirror: '53e49c53c4a973ba61abb6f0777e7cec0532ee1e' # card fields mirrored from issue-cards; edit via sdlc
flake_tests: ["lua:tests/integration/session_sync_native_spec.lua#session-sync native edits undo releases acquisition baseline, redo retakes: open autosave=true", "lua:tests/integration/session_sync_native_spec.lua#session-sync native edits undo releases acquisition baseline, redo retakes: watch autosave=true"]
started: 2026-10-24T10:09:05-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Native undo/redo autosave case sees Remote view unavailable

## Problem

`tests/integration/session_sync_native_spec.lua`, case `session-sync native edits undo releases acquisition baseline, redo retakes: open autosave=true`, failed once at :1593. The notice list held 'Remote view unavailable; reopen the file to retry' where the test expected none.

## Spec

Find what makes the remote view unavailable during the undo/redo sequence with autosave on, presumably a remote-session attach or start that races or times out. Decide whether the notice is a real failure path the case should not reach, or a fixture whose remote side is not ready. Fix the cause.

## Done when

- The source of the notice is identified with evidence (a repro or a trace).
- The case no longer depends on that timing, and a control shows the assertion still catches the notice when the remote view really fails.

## Plan

Cause (traced in a disposable clone, nvim 0.11.7): opening an unregistered session file runs remote_session.observe, which sends one `couch --session-sync lookup`. The spec's registry-less fake models a Couch from before pair#437: `--session-sync` exits 2 unless FAKE_COUCH_STATUS is set. So the lookup fails and its callback posts 'Remote view unavailable', about 37 ms after the open. The undo/redo cases assert `notifications == {}` about 14 ms after the open, so normally the notice arrives after the assertion, during teardown with the buffer unloaded, and `current()` drops it. On a loaded machine the case runs slower than the lookup, and the notice wins. Every unregistered open in the file runs this lookup; only these cases assert that no notice arrived.

- [ ] The fake gets a FAKE_COUCH_LOOKUP knob: without a registry, `--session-sync lookup` prints it, which models a current Couch with no registration for the path. Its default stays the pre-pair#437 exit 2, so the other registry-less specs keep their modeled Couch. The native spec sets FAKE_COUCH_LOOKUP to the absent reply in before_each, so its unregistered opens find no registration and post no notice.
- [ ] Regression: an unregistered open whose lookup is unavailable (the knob unset) does post the notice, and the spec's notification capture sees it. This control shows the empty-notice assertion can still catch a real failure.
- [ ] The traced red state: with the knob set, the lookup reports absent and no notice is posted. The undo/redo cases pass 20 reps per nvim under capped load, then the suite. The close unregisters both flakes, and the checktime sibling seen during #432 is covered by the same fix.

## Log

2026-10-23 (found during #414): it failed once in the recorded suite on parley 88fedfd8, attempt 7cd79e2bae17dc53b8944d14e9f0b892, which ran next to a session_sync mapping run on nvim 0.11.7. It did not recur in 3 reruns of the file on that head. #414 doesn't touch the native spec or its code path.
- 2026-10-23 (#421, parley.nvim:1): registered a sibling, 'undo releases acquisition baseline, redo retakes: watch autosave=true'. Recorded suite attempt 36c10d10c54944ae364dfb14ad896609 on bbe93c6336abaca309687b8f5f145d03cffeecc3 failed it at :1593 with the same 'Remote view unavailable; reopen the file to retry' notice; 4 targeted runs of the file on unchanged session-sync code passed 4/4.


### 2026-10-24 — Recurrence during #425 pre-close suite

Recorded attempt e4d0be42c9dc1b5f590f98b2f136b726 on3f9321f80a8aff88078f4d30f69c04637b8586ed failed only tests/integration/session_sync_native_spec.lua, case session-sync native edits undo releases acquisition baseline, redo retakes: watch autosave=true. At1593 the expected empty notification list contained Remote view unavailable; reopen the file to retry. Native file summary143/1/0, clean process census; suite exit2 after7m25s. No mechanism or failure-time load was captured. This is the same registered notice family as the original open/autosave case, not a proven shared root cause.

Immutable raw log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/e4d0be42c9dc1b5f590f98b2f136b726.log, SHA2563eb01c540943996bf01c881cdde8119c31b7da1d573b155110a46aa73271e1ac. #425 changes native no-target navigation and shared feedback pulses, not this case or its remote/session-sync path. Its prior recorded suite passed on4a0a48cf; that is not same-head pass evidence for this failure.

Both open and watch autosave=true identities are registered here. SDLC classified this pre-adoption attempt as unattributable-failure, so exact-attempt resume refused: parent is not an ordinary completed resumable suite failure; fix/advance the code and run a suite on a new head. Hub confirms this is the known typed-Plenary adoption gap (#415, blocked on ariadne#558). At hub direction7e67461e-ad65-4954-ba7e-ea45031ca2d6, #425 will test its actual later pushed close head, rather than manufacture a same-head pass or a code-only advance. Registration remains active and this issue remains unclaimed.
