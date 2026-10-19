---
id: 000391
status: working
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '7b313c4575cefab790d5991d4d3c3aa3f6776ccf' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-18T20:36:10-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "87ce7a81", done: "8dfa3369"}
---

# breadcrumb winbar: show a side doc's tree path (parent chain), not the navigation path that reached it

## Problem

The breadcrumb winbar (#353, atlas/ui/breadcrumb.md) shows the navigation trail Alt+o recorded: the path the operator actually followed. For side-doc trees that is wrong. With A > B1 > C1 and A > B2 > C2, if the operator is at C2 and follows a link to C1, the winbar shows A > B2 > C2 > C1; it should show A > B1 > C1, C1's place in the tree. Operator, 2026-10-18 (ops session file, Operator instructions item 3).

## Spec

For a document in a side-doc tree (a `.side/` doc with `parent:` frontmatter, or a parent that lists `discussions:`), the winbar displays its tree path: the chain of `parent:` links up to the root, regardless of how the window reached it. The chain is bounded (depth cap, cycle detection, a missing parent ends the chain with a marker) and read from frontmatter only. For a file outside any side-doc tree, today's navigation trail stays. Shift+Alt+O (Back) is unchanged: it walks the window's visit history, not the tree. Labels, collapsing and narrow-window rules stay as they are.

## Done when

- The A > B1 > C1 / A > B2 > C2 case shows A > B1 > C1 after jumping from C2 to C1 (spec test).
- A cycle, a missing parent and a depth over the cap each show a bounded path with a marker, no hang.
- Files outside trees keep today's trail; Back behaves as before.

## Plan

Quick flow (display-only; ~80 code lines). The tree path is a display value beside the navigation trail, never a replacement for it: `snapshot`/`restore`/`origin`/`follow`/Back keep reading the trail, so Back and finder snapshots are unchanged.

- [ ] `lua/parley/side_tree_model.lua` (pure): `chain(leaf, read, cap)`. `read(path)` returns `{ parent = abs|nil, tree = bool }` or nil (unreadable). A leaf with no `parent:` and no `discussions:` is outside any tree → nil (caller keeps the trail). Otherwise walk `parent:` up: a repeated path stops with `marker = "cycle"`, an unreadable parent stops with `marker = "missing"`, more than `cap` (32) ancestors keeps the nearest and sets `marker = "depth"`. Returns `{ version = 1, paths = root..leaf, omitted = 0, marker }`.
- [ ] `breadcrumb_model.project`: a `marker` renders as a lead segment (`?` missing, `↻` cycle, `…` depth), and shows even with one path; `document_band_model.compose` treats a marked value as a trail.
- [ ] `file_history.lua`: per-window `trees[win] = { path, value }`, recomputed in `observe` on every `visit` (BufEnter/WinEnter, so a frontmatter edit shows on re-entry) and whenever the observed path changes; cleared on WinClosed. Reader adapter: loaded buffer lines else `readfile(path, "", 200)`; frontmatter only when line 1 is `---`; `parent:` resolved against the doc's directory. New `M.display(win)` = `peek`'s proof check, then the tree value when present, else the trail; `document_band.trail_for` calls it. `peek` stays the trail (restore/snapshot contract).
- [ ] Tests: unit `side_tree_model_spec` (chain, cycle, missing, depth cap, not-in-tree; counted reads: chain N reads N+1, 2N reads 2N+1); unit project marker; integration `file_history_spec`: A > B1 > C1 / A > B2 > C2, Alt+o C2 → C1 shows `A › B1 › C1`; Back from C1 still returns to C2; a non-tree file keeps `session › answer`.
- [ ] atlas/ui/breadcrumb.md: tree-path rule + `display` vs `peek`.

Hot path: BufEnter/WinEnter per event; growth driver = tree depth d, cost d+1 frontmatter reads of ≤200 lines, bounded by cap 32 (counted test above). ARCH-FUNERAL: creates nothing durable; `trees[win]` dies with the window (WinClosed).

## Log

### 2026-10-18
