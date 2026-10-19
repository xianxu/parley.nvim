---
id: 000399
status: done
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
github_issue:
started: 2026-10-19T07:21:18-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.76
tracker:
    version: 1
    completion:
        token: close-6aaa7e37ab6d
        repository: github.com/xianxu/parley.nvim
        reviewed_head: b1185fee8f6a52188254a6920db9a36871fe4ffe
        evidence_commit: f24974a280612bbd2b505bef29984bc2fc1c8a8d
        landed_commit: 15e036d78c8f2550d175e31f4ee16778da80d47f
---

# fd leak: embedded session-file nvim leaks a unix socket per session-sync reload/lease, hits the 256 limit overnight

## Problem

On 2026-10-19 the operator's embedded nvim for the TL session file (pid 40815, `nvim --embed teams/devinfra/tl-status-xian-xu.md`, started 10-18 20:02) hit the macOS per-process fd limit (256) and became unrecoverable. Every BufEnter then failed with `E903: Process failed to start: too many open files: "/usr/bin/git"` (lualine git_diff), inside session_sync.reload (session_sync.lua:321-323, with_buffer_read:189). lsof at the time: 262 descriptors, of which 237 unix sockets, 231 of them with peer `->(none)` (the other end closed, ours never closed). On macOS, libuv/vim.system stdio pipes are socketpairs, so this is the signature of child-process pipes left open after the child exits. Overnight the hub wrote the session file and side docs hundreds of times (session-sync), so the leak is roughly one handle per external write or reload. Evidence: lsof and ps captured at /var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim-fd-leak.c719BR/.

Prime suspect (unconfirmed): `lua/parley/document_lease.lua:24` runs `vim.system(command, {stdin=..., text=true}):wait(2500)` on each lease operation. Check what happens to its pipes on timeout or when the process outlives the wait, and every other vim.system/jobstart/uv.spawn in the session-sync, reload and attention paths.
