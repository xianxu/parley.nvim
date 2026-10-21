---
id: 000404
status: open
deps: []
github_issue:
created: 2026-10-20
updated: 2026-10-20
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'f2926cf68e29152bba591b55c5b37a9da02744a0' # card fields mirrored from issue-cards; edit via sdlc
---

# session-sync: take the operator lock on entering insert mode, not only on first modification; release when unchanged

## Problem

parley takes the operator's session-sync lock on a registered session file or side doc only once the buffer is
modified. Between entering insert mode and the first keystroke that changes text, the TL can still write the file,
so the operator starts typing into a buffer that's about to change under them. Operator, 10-20 (ops side doc
`2026-10-20-22-remote-access.md`): entering insert mode should take the lock, even with no change yet; on the coming
iPhone view, showing the keyboard maps to the same thing.

## Spec

- On InsertEnter in a registered session file or side doc, take the operator lock (as today's first-modification
  path does).
- Release it when: the operator submits (Alt+Return); or they leave insert mode with the buffer unchanged since the
  lock was taken; or the buffer is unchanged and idle for 2 minutes after leaving insert mode (so a forgotten
  insert-then-escape never blocks the TL for long). A modified buffer keeps the lock until submit, as today.
- The lock indicator in the statusline shows it the moment insert mode starts.

## Done when

- Tests pin: insert takes the lock without a change; escape with no change releases it; idle unchanged releases
  after the timeout; a modified buffer keeps it until submit.

## Plan

- [ ]

## Log

### 2026-10-20
