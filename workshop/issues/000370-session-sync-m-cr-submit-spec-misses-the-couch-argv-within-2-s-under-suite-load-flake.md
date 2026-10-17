---
id: 000370
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'bd0bfd022867700c16b275f794362010ee6e35f3' # card fields mirrored from issue-cards; edit via sdlc
---

# session_sync M-CR submit spec misses the couch argv within 2 s under suite load (flake)

## Problem

`tests/integration/session_sync_spec.lua` failed once in a full suite: "session-sync buffer <M-CR> saves, deletes the lock, leaves the buffer editable and sends one couch message (#315)", at line 205. `vim.wait(2000, …)` for the fake couch's argv file returned -1 (a timeout): the submit's couch call didn't record its argv within 2 s.

- First seen: 2026-10-16 23:57, during #360's full suite on head b824c4695487fed80b979bbdd177368ec40edd79. That branch changes only `tests/helpers/ready_port.lua` and four cliproxy specs, nothing on the session-sync path.
- The run passed 457 other spec files with lint clean; this was its only failure.
- Retained log: `/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/ce404b3086f731fa89502659bcac6231.log`.
- Three same-head focused runs of the spec passed 63/63 each.

## Spec

Find out why the async couch submit can take more than 2 s to reach the fake under suite load. Candidates: a fixed 2 s literal below the submit path's own budget (the #355 class), or the asynchronous submit queue from #357. Size the wait from the path's real budget, or make the arrival observable, rather than raising the literal blindly.

## Done when

- A deterministic reproduction exists, for example a delayed fake couch, that fails before the fix and passes after.
- The fix sits at the cause; the focused spec and the full suite pass.

## Plan

- [ ]

## Log

### 2026-10-16
