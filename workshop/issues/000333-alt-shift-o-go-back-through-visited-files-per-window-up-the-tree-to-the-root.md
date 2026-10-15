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
flow: {kind: quick, provenance: inferred, spec: "5f416a11", done: "747d985a"}
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
- A new split inherits its parent history independently; Back reaches the session file from the split.

## Plan

- [x] Implement and unit-test the pure bounded history transition model.
- [x] Wire the per-window event adapter, FileBack command, registry/config mapping and real-key integration tests.
- [ ] Update README, runtime-generated help and atlas; run targeted and full tests.

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

## Revisions

### 2026-10-15 — TL approval and split inheritance

Approved by ops:0 delivery 499f2cb2-4d7a-42df-80e9-06b6c25d9175,
including the 200-visit limit. Supersedes fresh split histories: a new split
inherits a copy of its parent window's history, then evolves independently,
so Back can still reach the session file. Capture the source on WinLeave and
copy its immutable model state when WinNew creates the child; cover a split
showing the same file and a split opening a new file. A tab opened from a
window follows the same inheritance when Neovim creates its window.

Insert-mode Back bypasses the global registry's stopinsert wrapper using an
entry-specific preserve_insert flag; other entries keep the current behavior.
Native probes confirm buffer switching itself preserves Insert mode. The help
surface is generated at runtime from the registry; no static help file or
help-generator script exists, so assert the generated help lines directly.

### 2026-10-15 — initial implementation evidence

- Model delegation: 7 pure cases pass, including independent branches from a
  shared immutable split snapshot. Integration baseline: 11 expected failures
  before the adapter/command/key; after wiring, 10 pass and Insert typing fails.
- Tracing proved prep_md exits Insert and drains typeahead during Back's native
  BufEnter. It now honors the adapter's synchronous restoration scope. All 11
  integration cases pass, including linked session/answer/side-doc traversal,
  split inheritance, source/gf/picker entries, native refusal and deleted targets.
- Added queued repeated Back, root Insert typing, new-tab inheritance and
  split-close coverage. Running the complete keybinding mapping next.

### 2026-10-15 — split-source and mode regression evidence

- Full ui/keybindings mapping passed. Added an inactive API split case and saw
  it inherit the wrong previous window. Native tracing shows WinNew runs in
  the child even without WinLeave in the source; track the focused source via
  WinEnter and snapshot it at creation. All 15 integration cases then pass.
- Reverting only preserve_insert makes both actual typed-key regressions fail
  (successful Back and root no-op); restored it before final verification.
- Checklist bookkeeping now ends at test verification; close, merge and staging
  are subsequent SDLC operations recorded by their actual outcomes, rather than
  marking them complete before the close gate runs. Approved scope is unchanged.
