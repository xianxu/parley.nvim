---
id: 000330
status: open
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: 'c2a5626519b5ac343ecba94d6f66fd2a9a20f5cd' # card fields mirrored from issue-cards; edit via sdlc
---

# session-sync: undo back to the lock's baseline releases the operator lock, even under auto-save

## Problem

After parley.nvim#324, any first edit takes the operator's lock, and an undo releases it only when the buffer
becomes *unmodified*, i.e. equal to the file on disk. The operator runs an immediate normal-mode auto-save, so a `dd`
is written to disk at once; after `u` the buffer differs from disk and the lock stays. The operator (2026-10-14): "`u`
should release the lock if that `u` moves the file to a state of no change."

## Spec

- "No change" means **equal to the content when the operator's lock was taken** (the baseline), not equal to disk.
- On acquiring the operator lock, record the baseline: a hash of the buffer content at that moment (the content the
  agent last wrote or saw).
- After every buffer change, including undo, redo and auto-save, if the buffer content hash equals the baseline,
  **silently release** the operator lock. Auto-save then writes the baseline back, so the disk matches what the agent
  last saw.
- Redo or a new edit away from the baseline takes the lock again (as #324 does).
- #324's rule holds: a pending agent write, deletion or overwrite is reconciled before any release.
- Explicit saves (`:w`) keep their turn semantics as in #324; only content equality with the baseline releases.

## Done when

- With the operator's real immediate auto-save installed before attachment (as in #324's tests): `dd` takes the lock;
  `u` back to the baseline releases it silently, and an agent write then succeeds; `Ctrl-r` takes it again.
- Multi-step edits then undo all the way back release; a partial undo doesn't.
- A pending agent write during the edit is reconciled before release.
- Headless tests with real input order cover each case.

## Plan

- [ ]

## Log

### 2026-10-14
