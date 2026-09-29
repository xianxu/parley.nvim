---
id: 000282
status: working
created: 2026-09-26
updated: 2026-09-28
estimate_hours:
github_issue:
started: 2026-09-28T21:14:10-07:00
---

# Make each answer one undo history entry

## Problem

Streaming an assistant answer currently records many incremental buffer edits.
Undo can therefore remove individual chunks instead of reverting the answer as
one user-visible action.
