---
id: 000404
status: open
created: 2026-10-20
updated: 2026-10-21
estimate_hours:
github_issue:
started: 2026-10-21T01:17:07-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# session-sync: take the operator lock on entering insert mode, not only on first modification; release when unchanged

## Problem

parley takes the operator's session-sync lock on a registered session file or side doc only once the buffer is
modified. Between entering insert mode and the first keystroke that changes text, the TL can still write the file,
so the operator starts typing into a buffer that's about to change under them. Operator, 10-20 (ops side doc
`2026-10-20-22-remote-access.md`): entering insert mode should take the lock, even with no change yet; on the coming
iPhone view, showing the keyboard maps to the same thing.
