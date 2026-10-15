---
id: 000333
status: working
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '33827239f5a0595e3dbb8dc86cbd489d02ea6700' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T11:08:10-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
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

- [ ] Implement and unit-test the pure bounded history transition model.
- [ ] Wire the per-window event adapter, FileBack command, registry/config mapping and real-key integration tests.
- [ ] Update README, generated help and atlas; run targeted and full tests, close on SHIP, and land.

## Log

### 2026-10-15

## Revisions

### 2026-10-15 — proposed implementation design

Use an explicit per-window file-visit history, not a filtered jumplist (which
cannot guarantee picker/API buffer switches). Detailed plan:
[000333-file-history-plan.md](../plans/000333-file-history-plan.md).
Proposed clarifications for TL approval: normal editing windows only; all named
normal file buffers, regardless of filetype; scratch/help/terminal/floating
buffers are not visits. Keep at most 200 visits per window, evicting the oldest
when full; no disk persistence. Each new split starts its own history.
Back at the first retained file is a quiet no-op. Missing, unloaded files are
skipped; a loaded buffer remains navigable even if its file was deleted.
A refused switch (e.g. unsaved text with hidden off) keeps the current file and
history position so the operator can save and retry. A successful Back never
appends itself as a new visit. No forward key in this slice.

Acceptance additions: verify all four entry paths (Alt+o, gf, edit, picker-like
buffer switch), n/i mappings, independent split histories, transient buffers,
forward-tail truncation, missing targets, safe switch refusal, cursor clamping,
window cleanup, repeated setup, configured keys, help and disabled mappings.

### 2026-10-15 — planning log

- Verified the ops:0 dispatch receipt, claimed #333 in parley.nvim:1, and
  started the issue branch through SDLC after its dependency catch-up.
- Read the owning ops project and design. This navigation slice has no
  dependency on the agentic-document registry or side-document protocol.
