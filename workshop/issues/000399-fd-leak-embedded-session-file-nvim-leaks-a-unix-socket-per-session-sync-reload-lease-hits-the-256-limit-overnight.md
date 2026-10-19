---
id: 000399
status: open
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'cd754e28b80bce83d75ae47a1e82cd78b98a8601' # card fields mirrored from issue-cards; edit via sdlc
---

# fd leak: embedded session-file nvim leaks a unix socket per session-sync reload/lease, hits the 256 limit overnight

## Problem

On 2026-10-19 the operator's embedded nvim for the TL session file (pid 40815, `nvim --embed teams/devinfra/tl-status-xian-xu.md`, started 10-18 20:02) hit the macOS per-process fd limit (256) and became unrecoverable. Every BufEnter then failed with `E903: Process failed to start: too many open files: "/usr/bin/git"` (lualine git_diff), inside session_sync.reload (session_sync.lua:321-323, with_buffer_read:189). lsof at the time: 262 descriptors, of which 237 unix sockets, 231 of them with peer `->(none)` (the other end closed, ours never closed). On macOS, libuv/vim.system stdio pipes are socketpairs, so this is the signature of child-process pipes left open after the child exits. Overnight the hub wrote the session file and side docs hundreds of times (session-sync), so the leak is roughly one handle per external write or reload. Evidence: lsof and ps captured at /var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/nvim-fd-leak.c719BR/.

Prime suspect (unconfirmed): `lua/parley/document_lease.lua:24` runs `vim.system(command, {stdin=..., text=true}):wait(2500)` on each lease operation. Check what happens to its pipes on timeout or when the process outlives the wait, and every other vim.system/jobstart/uv.spawn in the session-sync, reload and attention paths.

## Spec

Find the leaking spawn with a counted reproduction: open fds before and after N simulated external writes and reloads of a session-sync document must be equal. Fix it at the root: every child's stdin, stdout and stderr closed on every path, including timeout and kill. Add a regression that counts the nvim process's own fds across 200 reloads (or the lease calls) and fails if they grow.

## Done when

- The counted fd regression is red before the fix and green after, over 200 cycles.
- A live check: an embedded session-file nvim keeps a flat fd count across a busy hub session.

## Plan

- [ ]

## Log

### 2026-10-19
