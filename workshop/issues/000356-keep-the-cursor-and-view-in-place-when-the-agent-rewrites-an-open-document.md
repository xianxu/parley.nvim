---
id: 000356
status: codecomplete
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '96b33e2c642c3faebb19dfde11e55b649d2c95be' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T11:10:23-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
actual_hours: 0.48
---

# Keep the cursor and view in place when the agent rewrites an open document

## Problem

When the agent writes a document the operator has open, the reload makes the cursor jump. That covers the session file, QA files and any agentic document. Operator request, relayed by the TL (ops:0) on 2026-10-16; part of universal-agent-input-interface.

## Spec

On a reload caused by an external write, map each window's cursor and top line from the old text to the new one with a line diff (`vim.diff`, hunk indices):
- A line outside every changed hunk shifts by the net line offset of the hunks above it.
- A line inside a changed hunk goes to that hunk's new start. It is refined by searching the new hunk for the text around the old cursor, about 50 characters, exact match first.
- The column is kept when the cursor's line is unchanged.
- Each window showing the buffer is mapped on its own.
- This never applies to the operator's own edits: only to reloads of text written outside the buffer.

## Done when

- Tests cover: an edit above the cursor, at it, and below it; two windows on the same buffer, each mapped; and a top line that stays stable.
- After that, the operator's live check on the session file.

## Plan

Quick flow. One pure mapper, plus capture and restore around the two external-write reload paths that every agentic document shares. Each such document attaches `session_sync`.

**Core concepts**

| Name | Lives in | Status |
|------|----------|--------|
| `map` | `lua/parley/view_map.lua` | new |
| `map_line` | `lua/parley/view_map.lua` | new |
| `capture_views` | `lua/parley/session_sync.lua` | new |
| `restore_views` | `lua/parley/session_sync.lua` | new |

`map` and `map_line` are pure, with no IO, tested in `tests/unit/view_map_spec.lua`. `capture_views` and `restore_views` are the integration point: they wrap the editor's window views around the two reload paths.

**The pure mapper, `lua/parley/view_map.lua`:** `map(old_lines, new_lines, pos) -> pos`, where pos is `{lnum, col}`.
- **Hunks:** from `vim.diff(old, new, {result_type = "indices"})`, as `{a_start, a_count, b_start, b_count}`. A hunk with `a_count == 0` inserts after `a_start`; one with `b_count == 0` deletes, and its `b_start` is the line before.
- **Outside every hunk:** `lnum + Σ(b_count - a_count)` over the hunks above. An insertion counts as above when `a_start < lnum`. The column is kept.
- **Inside a hunk:** search the new hunk's lines for the old line's text around the column, about 50 characters (`col-25 .. col+25`).
  - An exact match lands the cursor on the matching spot, at the same offset into the needle.
  - With no match, it tries the text before the cursor, then the text after.
  - Failing those, it goes to the hunk's new start at column 0, clamped to `[1, #new]`. A pure deletion lands on the line after it.
- **The top line:** mapped by the same rule, without the text search.
- **Tests:** `tests/unit/view_map_spec.lua`, pure: an edit above, at and below the cursor; an insertion and a deletion; an exact refine and a fallback; a top line that stays put when the edit is below the view.

**Capture and restore, `session_sync.lua`:**
- `capture(buf)` takes the buffer's lines plus each window from `win_findbuf(buf)`, with its `winsaveview()` cursor and top line. `restore(buf, snap)` maps each window and calls `winrestview` in that window.
- **Path 1:** `reload(buf)`, the `silent edit!` of a clean buffer, gets wrapped in capture and restore.
- **Path 2:** the native `FileChangedShell` reload, where `fcs_choice = "reload"`, captures at the moment it chooses to reload. It restores in the existing `FileChangedShellPost` handler, then clears the snapshot.
- **Never on the operator's own edits:** those never pass through these two paths, since only a foreign write reaches them.
- **Tests:** `tests/integration/session_sync_spec.lua` (or a new `session_sync_view_spec.lua`) uses real files and two windows on one buffer:
  - an external write above the cursor shifts both windows by the inserted lines;
  - a write at the cursor line keeps it on the same text;
  - a write below keeps the cursor and the top line exactly.
  - Each goes through the real `checktime` and `edit!` paths.

**Done when:** as in the issue, and then the operator's live check on the session file, staged with `sdlc stage --build` after asking the hub.

## Log

### 2026-10-16
- 2026-10-16: closed — On an external-write reload (session_sync reload() via edit!, and the native FileChangedShell reload), each window showing the buffer keeps its cursor and top line on the text it showed. view_map (pure) maps positions through vim.diff index hunks: outside a hunk the line shifts by the net offset above it and keeps its column; inside a hunk it searches the new hunk for about 50 chars around the column, exact first, then the text before, then after (min 3 chars), else the hunk new start, clamped. Operator edits never pass these paths. Tests: view_map_spec 10/10 (above, at, below, insertion, deletion, refine, fallback, top line). session_sync_spec adds 4 cases with two windows through the real paths: above (both windows shift by 2, top lines too), at the cursor line (stays on its text, col 5->13), below (cursor and top line exact), and the native :checktime path. Mutations: no restore fails above, at and checktime; only the native restore removed fails checktime alone. agentic_document and session_sync specs green. The operator live check on the session file follows, via the hub.; review verdict: SHIP
- 2026-10-16: flow upgraded quick → full — 113 added lines in code files (limit 100)
- Built. `view_map_spec` passes 10/10. The 4 new `session_sync_spec` cases pass, and so do the agentic_document and session_sync specs.
- Mutation checks:
  - With both restores removed, the above, at-cursor and `:checktime` cases fail. The below case passes either way, since it guards the no-change baseline.
  - With only the native-path restore removed, just the `:checktime` case fails, so each reload path is pinned by its own test.
- The quick-flow plan needed a Core-concepts table: `single_source_sweeps_spec` reads the current issue's tables, and it failed with none.
