---
id: 000358
status: open
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
severity: low
---

# Keep the cursor and view across parley's own agent rewrites (file_refresh, review round edit!)

## Problem

#356 keeps each window's cursor and top line on its text across the two external-write reload paths in `session_sync`: `reload()`'s `edit!`, and the native `FileChangedShell` reload. That covers the session file and every agentic document. Two other paths also rewrite a document the operator has open, and they still keep line numbers, so the cursor jumps:
- `lua/parley/tools/file_refresh.lua`: after parley's own chat agent writes a file (the write and edit tools), it refreshes the captured buffers from the committed bytes.
- `lua/parley/skills/review/init.lua`: the review round reloads its document with `:edit!` (the projection watcher is suppressed around it).

Found by #356's close review (an advisory, ARCH-PURPOSE). It was out of #356's scope, which was session_sync.
