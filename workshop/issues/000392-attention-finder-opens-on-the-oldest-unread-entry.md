---
id: 000392
status: working
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'e052277fd4c3d5d290f5da6ec52ce691f3159100' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-18T20:51:22-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "06dca77a", done: "29773055"}
---

# attention finder opens on the oldest unread entry

## Problem

The attention finder (Alt+Space) opens with the cursor at the top of the list (since #390's tree layout). The operator (2026-10-18): "attention finder upon open, should focus on oldest unread item": the cursor should land where the next thing to read is.

## Spec

On open, place the cursor on the oldest unread entry: state `answered` (an answer arrived and the operator has not seen it since), ordered by its answer time, oldest first; side docs count like any entry, and the tree layout is unchanged (only the cursor moves; the list scrolls to show it). If no entry is unread, keep today's position (the top). Filtering by typing behaves as today once the user types. Per-slot scope (Ctrl+A) applies before the choice: the oldest unread entry within the current scope.

## Done when

- With several answered-unseen entries, open lands on the one answered earliest, in both scopes.
- With none, open lands at the top as today.
- A side doc that is the oldest unread entry is selected inside its tree.

## Plan

- [x] Return an initial row index alongside the unchanged tree rows, choosing answered with earliest answered_at (legacy missing answer time falls back to submitted_at; ties keep tree order). Compute during the existing bounded row pass (ARCH-PURE, ARCH-DRY).
- [x] Apply it on open and empty-query scope toggles; preserve selection for async updates and typed filters. Ensure the selected row is visible through the picker's existing viewport rule, without changing row order.
- [ ] Red/green pure and native picker tests cover answer vs submit order, ties, seen/waiting, no unread, side-child position, both scopes, a below-fold target, typed filtering and late updates. Run required suite before close; normal landing follows.

Actions: open, toggle scope, type a filter, move selection, close. No new persisted state or lifecycle.

| Condition | Visible selection | Next action | Possible loss |
| --- | --- | --- | --- |
| Open / empty-query scope change with unread | oldest answered in scoped tree, scrolled into view | read or navigate | none |
| No unread / empty list | first row / existing empty state | navigate or close | none |
| Typed filter or late probe | existing filter and selection semantics | type or navigate | none |

Choice costs one comparison per displayed entry, bounded by the store's256 entries, with no extra IO or sorting; count state evaluations at8 and16 rows. Tests keep the same tree arrays and assert only cursor/view changes.

## Log

### 2026-10-18

- Read atlas/ui/attention_finder.md first. Card was unclaimed, then claimed by parley.nvim:2. start-plan refreshed the ariadne tool build and was rerun as directed. Existing top-anchored picker always selects row1; existing row generation already receives scope-filtered entries, and async repaint preserves identity. Keep those owners; do not sort the forest to implement cursor preference.

- RED `/tmp/parley392-red2.log` reproduces missing initial indices in three pure cases and the native picker staying at the top instead of the oldest child. The first native fixture needed its store directory created (`/tmp/parley392-red.log`); an intermediate GREEN hit a fixture assumption that the parent's probe was among the first four, corrected to complete an actually captured pending reply without changing production concurrency. Final `/tmp/parley392-green2.log` passes33 finder +18 rows +82 picker cases, zero failures/errors, no survivors. It checks below-fold initial visibility, exact forest order, both scoped preferences, typed filter retention through scope change and late observation, earliest answer vs submit time, ties/legacy fallback, no unread, and state reads8/16 for8/16 rows. Five-file luacheck and whitespace checks clean. Architecture guard replay and required suite follow.
- Production uses the second result of Rows.items for initial selection and empty-query scope changes. Async repaint still supplies selected identity and default view preservation. The picker initial selection uses its existing ensure-visible path; update accepts an optional selection option for explicit scope changes. No persisted state, row reordering, extra IO or sorting.

- Pre-suite architecture replay `/tmp/parley392-arch.log` passes all25 mapped architecture/helper spec files (144 cases), zero failures/errors, no survivors; includes the shared scanner and test-authoring guards.
