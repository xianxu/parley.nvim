---
id: 000324
status: open
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: 'b063a1640933ccaea54fb582d9865d73b5cc8ca9' # card fields mirrored from issue-cards; edit via sdlc
---

# session-sync: a normal-mode edit (dd) doesn't take the operator's lock; only insert-mode edits seem to

## Problem

2026-10-14, the operator on ops' TL status file: deleting a line with `dd` in normal mode didn't take the operator's turn (no `<file>.lock`), so the agent could still write; edits after entering insert mode do take it. The code intends both: `lua/parley/session_sync.lua` ~488–516 takes the lock on `BufModifiedSet` / `TextChanged` / `TextChangedI` when `s.turn == "free"`, the buffer is modified, the disk turn reads free, and the buffer is a session-sync file. So one of those conditions fails for a normal-mode first edit, e.g. `s.turn` stale after an agent write reloaded the buffer, `TextChanged` not firing until the cursor moves, or `BufModifiedSet` already spent because the buffer was modified earlier.

## Spec

Find which condition fails on a first normal-mode change (`dd`, `x`, `p`, `u`) and fix it so any first edit, in any mode, takes the operator's lock before an agent write can land. Add a headless test per edit kind, including right after an agent write reloaded the buffer.

## Done when

- `dd` (and `x`, `p`, `u`, `.`) as the first edit creates the lock with holder operator; an agent `couch --session-sync write` then refuses (exit 3).

## Plan

- [ ]

## Log

### 2026-10-14
