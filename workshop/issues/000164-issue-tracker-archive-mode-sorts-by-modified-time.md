---
id: 000164
status: codecomplete
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.56
started: 2026-07-08T08:04:06-07:00
actual_hours: 0.15
---

# issue tracker archive mode sorts by modified time

## Problem

The issue finder history/archive view is sorted with the same issue-number/status
ordering used for active issues. In the bottom-anchored picker, that puts recent
archive activity away from the prompt instead of closest to the text input.

## Spec

- Keep the normal `issues` view sorted exactly as it is today: active/open issue
  rows use the existing issue/status/ID ordering.
- Sort the `history` view by archive file modification time ascending, so the
  newest archived file is last in the item list and appears closest to the input
  in the bottom-anchored picker.
- Use deterministic tie-breakers for equal mtimes.

## Done when

- `:ParleyIssueFinder` history mode shows archived issues oldest-to-newest by
  file modification time.
- The default/open issues view remains sorted by issue number/status behavior.
- Focused unit tests cover both view-specific sort paths.

## Plan

- [x] Add scanned issue `mtime` data in `lua/parley/issues.lua` without changing
  the existing `scan_issues` default ID ordering.
- [x] Add `issue_finder.sort_for_view(view_mode, issues)` in
  `lua/parley/issue_finder.lua`: view `0` delegates to `issues.topo_sort`, view
  `1` sorts by `mtime` ascending with ID fallback (`ARCH-DRY`, `ARCH-PURE`).
- [x] Replace the inline `issues_mod.topo_sort(filter_for_view(...))` call in
  `issue_finder.open` with `sort_for_view`.
- [x] Extend `tests/unit/issue_finder_spec.lua` with failing tests proving
  issues view preserves ID/status ordering and history view orders by mtime
  oldest-to-newest (`ARCH-PURPOSE`).
- [x] Update `atlas/issues/issue-management.md` to document the history ordering.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.15 impl=0.25
item: atlas-docs design=0.05 impl=0.05
design-buffer: 0.30
total: 0.56
```

## Log

### 2026-07-08
- 2026-07-08: closed — History issue finder view sorts archived rows by filesystem mtime ascending while issues view keeps status/ID order; red/green focused specs passed; make test passed with lint 0 warnings/0 errors.; review verdict: SHIP

- Planning: keep active issue ordering on the existing `issues.topo_sort`
  pathway (`ARCH-DRY`), isolate the view-specific ordering in a pure helper
  (`ARCH-PURE`), and explicitly test the archive bottom-proximity requirement
  (`ARCH-PURPOSE`).
- `sdlc change-code` passed plan-quality CLEAN and estimate-quality INFO, then
  created branch `000164-issue-tracker-archive-mode-sorts-by-modified-time`.
- TDD red: `tests/unit/issue_finder_spec.lua` failed on missing
  `issue_finder.sort_for_view`; green after adding view-specific sorting.
- TDD red: `tests/unit/issues_spec.lua` failed because scanned archived rows had
  nil `mtime`; green after `scan_issues` exposed filesystem mtime on issue rows.
- Verification: scoped `git diff --check` passed for #164 files;
  `make test-spec SPEC=issues/issue-management` passed; full `make test` passed
  with lint at 0 warnings / 0 errors and all unit/integration specs green.
