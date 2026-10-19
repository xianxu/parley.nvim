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
- [x] Red/green pure and native picker tests cover answer vs submit order, ties, seen/waiting, no unread, side-child position, both scopes, a below-fold target, typed filtering and late updates. Run required suite before close; normal landing follows.

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

- Required suite passes on `0aacd31110b4b31e1c60c928d943b1f33f1f4a1e`:480 unique spec paths pass (960 PASS records),805 lint files clean, no surviving test processes. Retained log `/Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/0aacd31110b4b31e1c60c928d943b1f33f1f4a1e/suite.log`, SHA256 `35d74c438f980020e127af3dc78e6199dc6ba4729661076567d6fd0c24103a6d`. Hub directed close and normal landing (submitted receiptbf032369-f897-456c-bfd5-65582f6747b1). This evidence-only commit leaves the tested source unchanged.

- Close round1 returned REWORK, not an infrastructure error: Critical BR-1 picker-repaint-preserves-viewport. It did not finalize, so no merge began. `/tmp/parley392-br1-red.log` reproduces hidden below-fold selection on both successful and failed automatic probes before typing. The fix captures viewport before update's first reflow/refilter and passes it through both intermediate numeric selection and final identity resolution; explicit scope retargeting retains ensure-visible behavior. `/tmp/parley392-br1-green.log` passes34 finder +18 rows +82 picker cases (134 total), zero failures/errors, no survivors. Both outcomes exercise current/all views and scope toggles before the existing filter/late-reply checks. Two-file luacheck and whitespace checks clean. Lessons updated. New full source-head suite required before normal re-close; the later landing turn will integrate main's #396 CI fix.

- Post-BR1 required suite passes on `384fc34433fc4fc5709cc5be8e75ac54e405d639`:480 unique spec paths pass (960 PASS records),805 lint files clean, no survivors. Retained log `/Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/384fc34433fc4fc5709cc5be8e75ac54e405d639/suite.log`, SHA256 `e7e609bd987a58cfca2b9c30d02af304ca2acf22c1a696992ddc67422ff117a7`. Hub directed normal re-close then normal landing with main integration (#396), submitted receipt8bf472b1-14b9-4428-9622-ff8447a9c33a. Evidence-only checkpoint leaves the tested source unchanged.

## Revisions

### 2026-10-19 — Preserve visibility through the whole background update

Close round1 raised Critical BR-1 (picker-repaint-preserves-viewport): refiltering resets the top-anchored viewport before selected identity is restored. Both successful/failed automatic probes, current/all scope and scopes reached through Ctrl+A share that update. Capture the viewport before any update reflow/refilter, then restore it together with the resolved selected identity; explicit operator retargeting still ensures visibility. Add below-fold probe-completion regressions before typing for both outcomes/scopes. Reopen the verification checkbox until green. No new state, scope, or surface. ARCH-ORDER, ARCH-PURPOSE.
