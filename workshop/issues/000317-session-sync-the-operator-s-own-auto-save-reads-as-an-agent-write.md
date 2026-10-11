---
id: 000317
status: open
deps: []
github_issue:
created: 2026-10-11
updated: 2026-10-11
estimate_hours:
card_mirror: '65435c6a08b35d66a8c1e8e87f272da18913f4c1' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ] `disk_changed` asks Neovim through `:checktime` when the mtime moved; `FileChangedShell` records `s.foreign`.
- [ ] `autoread` off; the first-edit race check runs in the scheduled callback.
- [ ] Tests for both Done-when rows; atlas note.

## Log

### 2026-10-11
