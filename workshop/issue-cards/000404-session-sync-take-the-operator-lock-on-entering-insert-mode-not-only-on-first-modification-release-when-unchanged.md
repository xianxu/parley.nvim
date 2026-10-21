---
id: 000404
status: done
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
actual_hours: 1.23
tracker:
    version: 1
    completion:
        token: close-aa633a38a117
        repository: github.com/xianxu/parley.nvim
        reviewed_head: f808cfd7000fe927812ce1c54a33a91b0fcd9b5e
        evidence_commit: 5dc0ef648b15a42b853448cfdc3524c356ac9380
        landed_commit: c5089a7235b8d27a593a973be077649e7d0e56a9
---

# session-sync: take the operator lock on entering insert mode, not only on first modification; release when unchanged

## Problem

parley takes the operator's session-sync lock on a registered session file or side doc only once the buffer is
modified. Between entering insert mode and the first keystroke that changes text, the TL can still write the file,
so the operator starts typing into a buffer that's about to change under them. Operator, 10-20 (ops side doc
`2026-10-20-22-remote-access.md`): entering insert mode should take the lock, even with no change yet; on the coming
iPhone view, showing the keyboard maps to the same thing.
