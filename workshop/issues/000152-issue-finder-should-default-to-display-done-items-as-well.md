---
id: 000152
status: done
deps: []
created: 2026-06-29
updated: 2026-06-29
started: 2026-06-29T15:55:34-07:00
estimate_hours: 1.0
actual_hours: 0.43
---

# issue finder should default to display done items as well

## Problem

currently we hide done items in workshop/issues, and user can use <C-a> to toggle it on when issue finder is open. we should switch the default to display done items in workshop/issues. 

## Done when

- [x] Issue finder shows done items by default.
- [x] The existing toggle still lets the user hide done items.

## Spec

Issue finder should invert the current default visibility for done issues: done
items in `workshop/issues/` are visible on open, and the existing `<C-a>` toggle
switches them off instead of on.

The `<C-a>` control is not a boolean — it cycles a tri-state `view_mode`
(`active` / `all` / `all+history`). Confirmed design (Option B): the default is
`all` (done items in `workshop/issues/` visible, history excluded), and the
cycle order is `all → active(hide done) → all+history → all`, so the **first**
`<C-a>` press hides done items (matching "switches them off"), the second adds
archived history, the third returns to default.

Implementation honours `ARCH-PURE`: the `view_mode → include_history` mapping and
the `view_mode → filtered issues` selection are extracted as pure functions on
the `issue_finder` module, leaving `M.open` a thin IO/UI seam, so the behaviour
is unit-testable without driving the float picker.

## Plan

- [x] Add failing `tests/unit/issue_finder_spec.lua` for `filter_for_view`
  (mode 0/2 show done, mode 1 hides done + archived) and `includes_history`
  (only mode 2).
- [x] Extract pure `M.VIEW_LABELS`, `M.includes_history`, `M.filter_for_view`
  in `issue_finder.lua`; rewire `M.open` to use them with the new mode meanings.
- [x] Update `init.lua` `_issue_finder.view_mode` comment to the new semantics
  (default `0` now means `all`); update the view-mode cycle string at
  `atlas/issues/issue-management.md:17` to `(all/active/all+history)`; register
  `tests/unit/issue_finder_spec.lua` under `issues/issue-management` in
  `atlas/traceability.yaml`.
- [x] Run `make test-spec SPEC=issues/issue-management`, `make test`, and
  `make lint`.

## Estimate

```estimate
model: estimate-logic-v2
familiarity: 1.0
item: lua-neovim design=0.1 impl=0.55
item: atlas-docs design=0.0 impl=0.1
item: milestone-review design=0.0 impl=0.2
design-buffer: 0.15
total: 1.0
```

Reconciles as Σ(impl) 0.85 + design-buffer 0.15 = 1.0. Small, high-familiarity
change in known code (issue_finder filtering): `lua-neovim impl` covers the
pure-function extraction, the default/cycle rewire, and the new spec; `atlas-docs`
the pickers atlas note; `milestone-review` the single close-boundary review.

## Log

### 2026-06-29
- 2026-06-29: closed — TDD red→green: tests/unit/issue_finder_spec.lua 6 new tests (filter_for_view modes 0/1/2, includes_history, no-mutation, VIEW_LABELS order) red with nil functions then green. make test-spec SPEC=issues/issue-management green (6 new + existing issue specs). make test full suite exit 0, 0 failures/errors. make lint 0/0 across 237 files. Behavior: default view_mode 0 now means all (done items in workshop/issues visible), cycle all→active→all+history so first <C-a> hides done; pure filter_for_view/includes_history extracted per ARCH-PURE leaving M.open a thin UI seam.; review verdict: SHIP

Created from user feedback while landing #108. Scoped the desired behavior:
show done issues by default in the issue finder while preserving the existing
toggle as a way to hide them.

Design: discovered `<C-a>` is a tri-state `view_mode` cycle, not a boolean —
the issue's "toggle on/off" framing didn't fit. Confirmed Option B with the user
(`AskUserQuestion`): default `all` (done visible), cycle `all → active → all+history`
so the first press hides done. `view_mode` is read only by `issue_finder.lua` and
initialised in `init.lua:2988` — change is contained to those two files plus a new
spec. Filtering extracted to pure functions per `ARCH-PURE` so it is testable
without the float picker.

Implemented via TDD: `tests/unit/issue_finder_spec.lua` red (6 fail, functions
nil) → extracted `VIEW_LABELS` / `includes_history` / `filter_for_view` and
rewired `M.open` → green. Remapped the integer cycle so `0=all` (default) keeps
the `(view_mode+1)%3` arithmetic while yielding `all → active → all+history`.
Dropped the already-stale `"open+blocked"` prompt-title fallback.

`change-code` plan-quality judge (INFO) caught two mis-targets, both fixed before
coding: the atlas surface is `atlas/issues/issue-management.md` (not `ui/pickers`),
and `issue_finder.lua` maps under `issues/issue-management` in traceability —
registered the new spec there.

Verified: `make test-spec SPEC=issues/issue-management` (6 new + 90 existing
green), `make test` (full suite, 0 failures/errors), `make lint` (0/0, 237 files).
