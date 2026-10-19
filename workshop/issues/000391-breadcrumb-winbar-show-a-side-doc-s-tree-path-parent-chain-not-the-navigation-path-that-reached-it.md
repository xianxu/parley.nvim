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
flow: {kind: full, provenance: inferred}
---

# breadcrumb winbar: show a side doc's tree path (parent chain), not the navigation path that reached it

## Problem

The breadcrumb winbar (#353, atlas/ui/breadcrumb.md) shows the navigation trail Alt+o recorded: the path the operator actually followed. For side-doc trees that is wrong. With A > B1 > C1 and A > B2 > C2, if the operator is at C2 and follows a link to C1, the winbar shows A > B2 > C2 > C1; it should show A > B1 > C1, C1's place in the tree. Operator, 2026-10-18 (ops session file, Operator instructions item 3).

## Spec

For a document in a side-doc tree (a `.side/` doc with `parent:` frontmatter, or a parent that lists `discussions:`), the winbar displays its tree path: the chain of `parent:` links up to the root, regardless of how the window reached it. The chain is bounded (depth cap, cycle detection, a missing parent ends the chain with a marker) and read from frontmatter only. For a file outside any side-doc tree, today's navigation trail stays. Shift+Alt+O (Back) is unchanged: it walks the window's visit history, not the tree. Labels, collapsing and narrow-window rules stay as they are.

## Done when

- The A > B1 > C1 / A > B2 > C2 case shows A > B1 > C1 after jumping from C2 to C1 (spec test).
- A cycle, a missing parent and a depth over the cap each show a bounded path with a marker, no hang.
- Every other file shows its own path (repo-relative, else `~`, else absolute); no file window shows the navigation trail. A tree root and a repo-top file show a winbar too. Back behaves as before. (Revised 2026-10-18 for the operator's scope addition; was "files outside trees keep today's trail".)
- An unreadable parent ends the chain with the missing marker, never an error; a frontmatter edit repaints on window re-entry.
- `breadcrumb = { enable = false }` opts out; README and atlas describe the surface and the replaced user winbar.

## Plan

Quick flow (display-only; ~80 code lines). The tree path is a display value beside the navigation trail, never a replacement for it: `snapshot`/`restore`/`origin`/`follow`/Back keep reading the trail, so Back and finder snapshots are unchanged.

- [x] `lua/parley/side_tree_model.lua` (pure): `chain(leaf, read, cap)`. `read(path)` returns `{ parent = abs|nil, tree = bool }` or nil (unreadable). A leaf with no `parent:` and no `discussions:` is outside any tree → nil (caller keeps the trail). Otherwise walk `parent:` up: a repeated path stops with `marker = "cycle"`, an unreadable parent stops with `marker = "missing"`, more than `cap` (32) ancestors keeps the nearest and sets `marker = "depth"`. Returns `{ version = 1, paths = root..leaf, omitted = 0, marker }`.
- [x] `breadcrumb_model.project`: a `marker` renders as a lead segment (`?` missing, `↻` cycle, `…` depth), and shows even with one path; `document_band_model.compose` treats a marked value as a trail.
- [x] `file_history.lua`: per-window `trees[win] = { path, value }`, recomputed in `observe` on every `visit` (BufEnter/WinEnter, so a frontmatter edit shows on re-entry) and whenever the observed path changes; cleared on WinClosed. Reader adapter: loaded buffer lines else `readfile(path, "", 200)`; frontmatter only when line 1 is `---`; `parent:` resolved against the doc's directory. New `M.display(win)` = `peek`'s proof check, then the tree value when present, else the trail; `document_band.trail_for` calls it. `peek` stays the trail (restore/snapshot contract).
- [x] Tests: unit `side_tree_model_spec` (chain, cycle, missing, depth cap, not-in-tree; counted reads: chain N reads N+1, 2N reads 2N+1); unit project marker; integration `file_history_spec`: A > B1 > C1 / A > B2 > C2, Alt+o C2 → C1 shows `A › B1 › C1`; Back from C1 still returns to C2; a non-tree file keeps `session › answer`.
- [x] atlas/ui/breadcrumb.md: tree-path rule + `display` vs `peek`.

Hot path: BufEnter/WinEnter per event; growth driver = tree depth d, cost d+1 frontmatter reads of ≤200 lines, bounded by cap 32 (counted test above). ARCH-FUNERAL: creates nothing durable; `trees[win]` dies with the window (WinClosed).

## Revisions

- 2026-10-18, hub refinement: cache each file's parsed frontmatter by path plus stamp (mtime and size, or changedtick for a loaded buffer), bounded at 256 entries and reset when full.
- 2026-10-18, operator scope addition (hub-approved reading): no navigation trail in the winbar anywhere. A file outside any tree shows its own path as segments under the existing label and collapse rules, relative to the nearest `.git` root, else `~`, else `/`. Every file, including roots and repo-top files, shows a winbar. Back and snapshot/restore are unchanged. Delta: `breadcrumb_model.path_value` and `visible`; `file_history.display` returns the tree or file path, never the trail. The band, lock-leave and session-sync specs now treat the path band as every file's baseline: an operator's original winbar comes back only when the window stops showing a file.
- 2026-10-18, hub follow-up: `breadcrumb = { enable = false }` opts out (the band then shows only for lock states, and Back still works); atlas/ui/breadcrumb.md notes that the band replaces a user's own winbar in file windows.
- 2026-10-18, close review round 1 (REWORK, BR-1..7): an unreadable parent degrades to the missing marker (guarded read); every display value is visible, so a tree root shows itself (the lone-root rule hid only trails, which are never displayed); the band repaints when the shown value changes on re-entry; frontmatter parsing moved into the pure `side_tree_model.parse` with unit tests (top-level keys only, which is why chat_parser's indentation-trimming key parser is not reused); Done when and README updated. The Plan's `trees[win]` is `shown[win]` in code, and its "else the trail" fallback is the file's own path per the scope addition.

## Log

### 2026-10-18
- 2026-10-18: closed — Suite exit 0 on c3c50006; round-1 fixes at 0c9ab358 pass ui/breadcrumb (unit side_tree_model parse, band model, breadcrumb model; integration file_history: A>B1>C1 after C2->C1, Back, root A shows, re-entry repaint to ? marker, unreadable parent -> ? marker with no error, opt-out), lint 0 warnings; full suite rerunning on 0c9ab358.; review verdict: SHIP
- 2026-10-18: flow upgraded quick → full — 135 added lines in code files (limit 100); an earlier round of this close already ran the full review
- A loaded buffer is read as edited, not from disk, so a frontmatter edit shows before saving; that is why a buffer stamp is used instead of mtime.
- Three gates each asked "is there a trail to show?" (`project`, `document_band_model.compose`, `document_band.refresh`); folded into one `breadcrumb_model.visible` (ARCH-DRY) after the third surfaced as a no-repaint bug.
- Band specs had set operator options after the file opened. With a band on every file, the band reads those as overrides, so the specs set them before `:edit` or not at all.
