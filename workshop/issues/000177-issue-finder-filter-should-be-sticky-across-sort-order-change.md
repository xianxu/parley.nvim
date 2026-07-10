---
id: 000177
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-10
estimate_hours: 0.98
started: 2026-07-10T01:19:44-07:00
---

# issue finder filter should be sticky across sort order change

## Problem

Issue Finder loses the user's prompt query whenever it closes and opens again. This
includes the repaint triggered by changing between the `issues` and `history` views,
so the visible result set unexpectedly becomes unfiltered after a sort/view change.

## Spec

- Preserve Issue Finder's complete prompt query in its existing finder state whenever
  the query changes. Plain search text, structured `{repo}` filters, and mixtures of
  both must survive unchanged.
- Seed every later Issue Finder invocation from that saved query, including the
  invocation used to repaint after cycling between `issues` and `history`.
- Clearing the prompt must clear the saved query; a later invocation must open with
  an empty prompt rather than resurrecting an older query.
- Keep this full-query policy local to Issue Finder. Other finders retain their
  existing structured-filter-only persistence semantics (`ARCH-DRY`, `ARCH-PURPOSE`).
- Keep filtering in `float_picker`; Issue Finder only captures and restores the query
  at the UI boundary (`ARCH-PURE`).

## Done when

- Plain text remains in the prompt after cycling the Issue Finder view and after
  closing and invoking Issue Finder again.
- `{repo}` filters and mixed plain/structured queries are restored exactly.
- Clearing the prompt persists as an empty query.
- Automated tests cover capture and restoration without changing other finders'
  persistence policy.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.10 impl=0.04
item: lua-neovim design=0.30 impl=0.30
item: milestone-review design=0.05 impl=0.12
design-buffer: 0.15
total: 0.98
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.*

## Plan

- [ ] Add failing coverage for raw full-query capture/restoration, clearing,
  later invocation, and view-cycle repaint.
- [ ] Replace Issue Finder's structured-only query extraction with direct opaque
  query state; keep other finders unchanged.
- [ ] Run focused and full verification, reconcile documentation, and close #177.

Durable implementation plan:
`workshop/plans/000177-sticky-issue-finder-query-plan.md`.

## Log

### 2026-07-08
