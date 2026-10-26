---
id: 000403
status: done
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
github_issue:
started: 2026-10-19T22:31:29-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.14
tracker:
    version: 1
    completion:
        token: close-2bd7c3f0ce5d
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 1326aebbad6b609a856dbd2d127229365024c549
        evidence_commit: f1e9732ff0da48da2278fd17c617002bd6e0a8db
        landed_commit: ccbc2dd511309841707d687e4aff417516b63681
kind: bug
---

# review diagnostics: CursorMoved error 'Invalid col: out of range' (fixed column 2 on short lines; stale lnum after a rewrite)

## Problem

The operator hit this while scrolling the TL session file (10-19 22:30, screenshot in ops
`teams/devinfra/assets/tl-status-xian-xu/2026-10-19.22-30-14.398.jpg`), as a blocking "Press ENTER" error on every
cursor move:

```
Error detected while processing CursorMoved Autocommands for "*":
Error executing lua callback: .../parley/skills/review/diag_display.lua:260: Invalid 'col': out of range
  nvim_buf_set_extmark ← render (diag_display.lua:260) ← refresh_tracked (:269) ← CursorMoved callback (:313)
```

`render` places each line's virtual-lines extmark at a fixed `DISPLAY_COL = 2`
(`nvim_buf_set_extmark(buf, display_ns_id, lnum, DISPLAY_COL, …)`). That column is out of range on any line shorter
than 2 characters (an empty line), and the `lnum` can also be stale: the session file is rewritten by the TL
(session-sync writes) while diagnostics from before the rewrite are still cached, so a diagnostic can point past the
end of the buffer or at a now-short line.
