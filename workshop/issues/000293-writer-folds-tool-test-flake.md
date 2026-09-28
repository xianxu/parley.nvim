---
id: 000293
status: open
deps: []
github_issue:
created: 2026-09-27
updated: 2026-09-27
estimate_hours:
card_mirror: '584e88471ceeb0175e9b3a885f63039eb1e0eefb' # card fields mirrored from issue-cards; edit via sdlc
---

# writer_folds tool test flakes: tool round continuation sometimes misses the 5s wait

## Problem

`tests/integration/writer_folds_spec.lua` (added in #290), case "folds a tool call and a
result over 4 KiB closed as they are written, with no reconcile work", intermittently
fails at its `wait_for(function() return #calls==2 end)` after `first.complete(...)`:
`did not settle` (5 s `vim.wait`). Measured 2/25 failures run alone on `origin/main`
(pre-#291, so not caused by it) and 1/13 on the #291 branch. The other cases in the file,
including the two-round prose-before-call case, did not fail in those runs.

The case drives a real `read_file` of a 300-line file (a 303-row result block, written
whole since #290) through `chat_respond` with the fixture transport, then waits for the
continuation request. Unknown whether the continuation is only slow (repair of the new
rows, the real tool's async IO under load) or sometimes never issued (a race in the round).

## Spec

- Find the root cause before touching the wait: record where the round is when the wait
  expires (runner/machine phase, whether the result block was written, pending document
  repair, whether the continuation was dispatched late or never).
- If it is a real race (continuation never issued), fix it in the runner/round and add a
  test that reproduces the ordering deterministically.
- If it is only slow, make the test wait on the state it needs (not a longer blind
  timeout), and say which cost made it slow.

## Done when

- The root cause is written in the Log with evidence from a captured failing run.
- `writer_folds_spec` passes 50/50 consecutive runs alone, and within `make test`.

## Plan

- [ ] Instrument and capture a failing run
- [ ] Fix at the root cause; deterministic test if it is a race
- [ ] 50-run loop

## Log

### 2026-09-27
- 2026-09-27: filed during #291 close (operator request).
