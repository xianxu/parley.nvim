---
id: 000399
status: working
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'c3db61378b3a78036e36cef690998219546e78a4' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-19T07:21:18-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
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

- [ ] Find the leaking spawn with evidence before changing code (the measured candidates below are all flat).
- [ ] Fix it at the root, with a counted fd regression that is red before the fix.
- [ ] `session_sync_spec`'s 200-write fd count stays as a guard on parley's own reload/probe path.

## Log

### 2026-10-19
- Measured flat (open fds before = after; /dev/fd count in-process, lsof for peers):
  - Core nvim 0.11.7 `vim.system`: callback, `:wait`, `stdin` string and `true` (closed or not), timeout expiry, `:kill`, `:wait(20)` timeout, a grandchild holding stdout, spawn failure; `jobstart` with/without callbacks, `jobstop` before/after exit (lualine's pattern); `vim.fn.system`.
  - Real `couch --session-sync status --json` and `couch --actors --json` through `parley.couch.run`, 30 each, with and without `timeout`.
  - Parley's reload/probe path with the fake couch: 200 agent writes, each reloaded, status probes on (new `session_sync_spec` case).
  - The operator's full config (headless, isolated state, `COUCH_ISOLATED_ROOT`), 60 external writes: 3 orphans appear at startup and stay 3.
  - The restarted live session nvim (pid 28410, 07:21) across hub writes: 0 orphans.
- `document_lease.lua:24` spawns only for an identity containing NUL, so it is not on the per-write path.
- Overnight rate: 231 orphans over ~11 h, about one socket per hub write. One socket per event fits a `vim.system` output pipe left open, which in nvim 0.11 happens when a stdout/stderr handler raises before `pipe:close()` (`_system.lua` `handler_with_close`). It does not fit a whole leaked job (3 sockets).
- Mistake: a first headless run of the full config used owner `ops:0` with no `COUCH_ISOLATED_ROOT`, so parley sent a real session-sync ping to the hub. `forget` reported it was never registered. All later runs are isolated with a fake owner.
