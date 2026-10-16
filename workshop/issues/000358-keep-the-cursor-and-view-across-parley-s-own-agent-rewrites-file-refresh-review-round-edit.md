---
id: 000358
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: 'be9d67dd23b57a3d5ad4622bcd58aa33ffb1ea76' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T12:49:00-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6e340b9c", done: "93e0d3d8"}
---

# Keep the cursor and view across parley's own agent rewrites (file_refresh, review round edit!)

## Problem

#356 keeps each window's cursor and top line on its text across the two external-write reload paths in `session_sync`: `reload()`'s `edit!`, and the native `FileChangedShell` reload. That covers the session file and every agentic document. Two other paths also rewrite a document the operator has open, and they still keep line numbers, so the cursor jumps:
- `lua/parley/tools/file_refresh.lua`: after parley's own chat agent writes a file (the write and edit tools), it refreshes the captured buffers from the committed bytes.
- `lua/parley/skills/review/init.lua`: the review round reloads its document with `:edit!` (the projection watcher is suppressed around it).

Found by #356's close review (an advisory, ARCH-PURPOSE). It was out of #356's scope, which was session_sync.

## Spec

## Done when

- Both paths map each window's cursor and top line through `view_map`, which is pure, with `hunks` computed once per reload. They capture before the rewrite and restore after it, as `session_sync`'s `capture_views` and `restore_views` do. The pair is lifted into one shared helper rather than copied (ARCH-DRY).
- Tests: for each path, an edit above the cursor shifts it, and an edit below leaves the cursor and the top line exactly in place. Each test fails without the restore.

## Plan

Quick flow. Both remaining agent rewrites replace the **whole** buffer through `buffer_edit.apply_user(capture, {{region = 1, text = …}})`:
- `tools/file_refresh.complete`, after parley's chat write, edit and propose tools (it can also use `replace_all_lines`);
- `skill_invoke`'s `source_completion`, the review round's reload of its document.

A partial edit keeps Neovim's own cursor adjustment. A whole-buffer replace loses it, which is where the jump comes from.

**Core concepts**

| Name | Lives in | Status |
|------|----------|--------|
| `capture` | `lua/parley/window_views.lua` | new |
| `restore` | `lua/parley/window_views.lua` | new |
| `capture_views` | `lua/parley/session_sync.lua` | deleted |
| `restore_views` | `lua/parley/session_sync.lua` | deleted |

`window_views` is the integration half of #356, lifted out of `session_sync` unchanged (ARCH-DRY). It wraps the editor's windows. The pure mapping stays in `view_map`, which already has its tests.

**Steps**
- [ ] Move `capture_views` and `restore_views` from `session_sync.lua` into `lua/parley/window_views.lua` as `capture(buf)` and `restore(buf, snap)`. `session_sync` calls them at its two reload paths. #356's `session_sync_spec` cases stay green unchanged, which proves the move.
- [ ] `file_refresh.complete`: capture each buffer's views before its whole-buffer apply. Restore after a successful apply, meaning when `matches()` holds. A refused or reconciling refresh leaves the views alone.
- [ ] `skill_invoke` `source_completion`: capture before `apply_user` and restore when the receipt says `applied`.
- [ ] Tests:
  - `tool_file_refresh_spec`: a buffer of numbered lines in two windows. A `write_file` that adds lines above the cursor shifts both cursors onto the same text; one that appends below leaves cursor and top line exact.
  - `skill_invoke_review_spec`: a round that inserts above the cursor keeps it on its text.
  - Each test fails with the restore removed.

**Done when:** as in the issue: both paths map each window's cursor and top line, through one shared helper, with tests for an edit above and an edit below that fail without the restore.

## Log

### 2026-10-16
