---
id: 000358
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: '5f0f332d808184a1cf356b0c6e787c70a94d1fd8' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-16
