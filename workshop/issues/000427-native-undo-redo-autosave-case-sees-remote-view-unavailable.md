---
id: 000427
status: open
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'e1f415152b52fb5a0677dfff6bf4a90721c2b8ed' # card fields mirrored from issue-cards; edit via sdlc
flake_tests: ["lua:tests/integration/session_sync_native_spec.lua#session-sync native edits undo releases acquisition baseline, redo retakes: open autosave=true", "lua:tests/integration/session_sync_native_spec.lua#session-sync native edits undo releases acquisition baseline, redo retakes: watch autosave=true"]
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

- [ ]

## Log

2026-10-23 (found during #414): it failed once in the recorded suite on parley 88fedfd8, attempt 7cd79e2bae17dc53b8944d14e9f0b892, which ran next to a session_sync mapping run on nvim 0.11.7. It did not recur in 3 reruns of the file on that head. #414 doesn't touch the native spec or its code path.
- 2026-10-23 (#421, parley.nvim:1): registered a sibling, 'undo releases acquisition baseline, redo retakes: watch autosave=true'. Recorded suite attempt 36c10d10c54944ae364dfb14ad896609 on bbe93c6336abaca309687b8f5f145d03cffeecc3 failed it at :1593 with the same 'Remote view unavailable; reopen the file to retry' notice; 4 targeted runs of the file on unchanged session-sync code passed 4/4.
