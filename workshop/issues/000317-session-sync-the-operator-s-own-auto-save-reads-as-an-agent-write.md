---
id: 000317
status: working
deps: []
github_issue:
created: 2026-10-11
updated: 2026-10-11
estimate_hours:
card_mirror: '0348702b831aa80cbe987a248ce73cf1b1f6853f' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-11T11:29:20-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# session-sync: the operator's own auto-save reads as an agent write

## Problem

A false session-sync violation (TL report, 10-11 11:26, ops `teams/devinfra/tl-status-xian-xu.md`). The operator took the lock at 11:24:27, and the TL's last write was 11:15:06. At 11:26:14 the file and `.clobbered` were byte-identical: the operator's own save was treated as an agent write.

Cause: the operator's nvim config auto-saves markdown from a non-nested autocmd (`silent! write` on `InsertLeave`/`TextChanged`). A write inside a non-nested autocmd fires no `BufWritePost`, and `BufWritePost` was the only thing that moved session-sync's mtime baseline (`s.loaded`). The next watch tick saw the new mtime as foreign.

## Spec

Let Neovim, which records every write a buffer makes, decide whose write it was, instead of parley's own autocmd-fed baseline.

- When the disk mtime differs from `s.loaded` and the change isn't already known to be foreign, run `:checktime <buf>`. If Neovim raises `FileChangedShell`, the write is foreign. If not, this buffer wrote it, and the baseline moves.
- `FileChangedShell` records the foreign mtime (`s.foreign`). During parley's own check it only records, and the caller acts on it.
- The buffer's `autoread` goes off. With `autoread` on, an unmodified buffer reloads on `:checktime` with no `FileChangedShell`, so an agent write under the operator's lock (the buffer can be clean right after an auto-save) would reload over the operator's text.
- `:checktime` cannot run from inside an autocmd (it would prompt), so the first-edit race check moves into the scheduled callback.

## Done when

- An auto-save from a non-nested autocmd during the operator's turn raises no violation, writes no `.clobbered` and sends no message (test; it fails before the fix).
- An agent write under the lock while the buffer is clean (just auto-saved) is still a violation that restores the operator's copy (test).
- The existing session-sync specs pass.

## Plan

- [x] `disk_changed` asks Neovim through `:checktime` when the mtime moved; `FileChangedShell` records `s.foreign`.
- [x] `autoread` off; the first-edit race check runs in the scheduled callback.
- [x] Tests for both Done-when rows; atlas note.

Core concepts:

| Name | Where | Role | Status |
|---|---|---|---|
| `disk_changed` | `lua/parley/session_sync.lua` | mtime cache, confirmed by Neovim through checktime | modified |
| `attach` | `lua/parley/session_sync.lua` | autoread off; FileChangedShell records the foreign mtime | modified |

## Log

### 2026-10-11
- Reproduced with a spec that auto-saves from a non-nested `TextChanged` autocmd, as `~/.config/nvim/lua/core/options.lua` does: false `.clobbered` + violation message before the fix. A second hazard showed up: with `autoread` on, `:checktime` reloaded the agent's write over a just-auto-saved buffer under the lock.
- Fix: `disk_changed` treats `s.loaded` as a cache and asks Neovim (`:checktime`, `FileChangedShell` → `s.foreign`); `autoread` off; the first-edit race snapshots the mtime move and confirms it in the scheduled callback. Mutation: re-enabling `autoread` fails 3 specs.
- TL's second report (11:34) and refinement: the flagged save was the operator's first Alt+Return after a TL write; a second press submitted. Added the exact sequences: agent write → reload (watch or :checktime) → first edit → auto-save or :w, and agent write → edit → one Alt+Return → submitted, no `.clobbered`. Against origin/main's session_sync.lua, all 4 auto-save cases fail (the Alt+Return one at `.clobbered`); with the fix, 34/34 pass.
- The TL's hypothesis (nvim notices a pre-lock write only at focus/Alt+Return) doesn't fit: the watch polls the mtime every second, the buffer had reloaded the TL's content before the edit, and `.clobbered` byte-identical to the file means the 'foreign' copy already held the operator's comment, i.e. it was the operator's own save. Comparing mtime with the lock time wouldn't catch it either (the auto-save is after the lock). Checking before taking the lock is what the first-edit step now does via :checktime.
