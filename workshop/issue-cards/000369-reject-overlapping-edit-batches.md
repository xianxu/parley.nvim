---
id: 000369
status: open
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-16T21:03:50-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Reject overlapping edit batches

## Problem

Found while implementing #362's local chat protection. The shared pure
parley.skill_edits.compute_edits accepts overlapping old_string spans,
positions every edit against the original content, then applies them in
reverse order without rejecting overlap. A shorter nested replacement shifts
later bytes into an earlier replacement's original range, damaging text outside
the intended span while returning ok=true.

Concrete input: content is alpha followed by newline, # Chat, newline, secret.
Edits are alpha -> x and pha -> empty. Current result is xChat followed by
newline and secret: the heading prefix and boundary newline were consumed.
#362's local invocation-owned validator rejects overlaps, but other callers of
the shared edit engine remain exposed. Do not depend on model instructions.
