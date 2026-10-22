---
id: 000411
status: open
deps: []
github_issue:
created: 2026-10-21
updated: 2026-10-21
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'da0c045ab389031b00d967940a400e2ebd893e74' # card fields mirrored from issue-cards; edit via sdlc
---

# Handle nvim's file-changed event for registered session files and side docs: silent reload when unmodified, keep-a-copy when modified, never the prompt

## Problem

## Spec

Operator (10-21, item 14): "can't we disable nvim's warning of disk file changed and handle it, as part of the
locking mechanism on session and side docs?" (answer: ops `session.side/2026-10-21-27-nvim-file-changed.md`).

#404 takes the operator lock on entering insert mode and #408 closes the insert-entry race. What remains is a Couch
or TL write while the operator is only *viewing* a registered session file or side doc: nvim shows its
file-changed prompt. For registered documents, parley handles `FileChangedShell` itself:
- buffer unmodified: reload silently (`v:fcs_choice = "reload"`), cursor and view kept;
- buffer modified (only possible without a confirmed lock, e.g. Couch unreachable): take the existing keep-a-copy
  (clobber-copy) path with its notice, never nvim's prompt;
- unregistered files keep nvim's default behaviour.

## Done when

- A native test: an external write to a registered, unmodified, open document reloads it with no prompt, keeping the
  cursor.
- A modified registered buffer plus an external write keeps the operator's text via the copy path, with no prompt.
- An unregistered file still gets nvim's default handling.

## Plan

- [ ]

## Log

### 2026-10-21
