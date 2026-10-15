---
id: 000333
status: open
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '36cb23fe6cdcd339137692c08231d120975530a4' # card fields mirrored from issue-cards; edit via sdlc
---

# Alt+Shift+O: go back through visited files (per window), up the tree to the root

## Problem

The universal-agent-input-interface project (ops `teams/devinfra/projects/universal-agent-input-interface/`) turns
markdown files into a connected tree: the session file → an answer or side doc → a link inside it → … The operator
navigates down with Alt+o (parley#327) and needs to come back **up the tree, file by file, to the root** (e.g. the
session file). `Ctrl-o` walks every cursor position, so it takes many presses per file; `Ctrl-^` toggles only between
two files; `:bp` follows buffer-list order, not visit order.

## Spec

- **Alt+Shift+O** (`<M-O>`): go back to the previous **file** in this window's visit history, skipping same-file jumps,
  restoring that file's last cursor position. Repeated presses walk further back, up to the root.
- The history is per window, ordered by visit, collapsing consecutive visits to the same file; it records files
  entered by any means (Alt+o, `gf`, `:e`, a picker).
- Going back then visiting a new file truncates the forward part (like a browser).
- Optional and cheap: a forward counterpart, if one is free (otherwise none).

## Done when

- Headless tests: session file → answer (Alt+o) → side doc (Alt+o), moving around inside each; two Alt+Shift+O presses
  land back on the session file at its previous cursor; same-file jumps don't count; history is per window.
- README documents the key.

## Plan

- [ ]

## Log

### 2026-10-15
