# Boundary Review — parley.nvim#186 (whole-issue close)

| field | value |
|-------|-------|
| issue | 186 — issue finder in repo mode should present repo facet search |
| boundary | whole-issue close |
| window | `ef733b096bd4aed43cd65ed0cac7f2d00af229a2..HEAD` |
| timestamp | 2026-07-14T17:29:00-07:00 |
| verdict | SHIP |
| confidence | high |

## Summary

The implementation matches #186's Spec and completed Plan. It extracts one
reusable pure facet model, preserves Chat Finder behavior, adds correctly gated
persistent repository facets to Issue Finder, and keeps ALL reachable after
persisted NONE. No blocking or advisory findings remain.

## Findings

None.

## Verified strengths

- `finder_facets.lua` centralizes discovery, immutable state transitions, OR
  filtering, and picker projection (`ARCH-DRY`, `ARCH-PURE`).
- Issue Finder requires a completely labelled expanded root set with at least
  two distinct repositories and filters only after view sorting.
- Persistent state spans views/invocations, while picker updates preserve the
  live query and allow NONE→reopen→ALL recovery (`ARCH-PURPOSE`).
- The corrected Core concepts table names greppable entities at their actual
  locations; atlas and traceability cover the new model and flow.

## Independent evidence

- `finder_facets_spec.lua`: 12 passed.
- `chat_finder_logic_spec.lua`: 36 passed.
- `issue_finder_spec.lua`: 19 passed.
- `float_picker_spec.lua`: 63 passed.
- `finder_sticky_spec.lua`: 12 passed.
- Both `modes/super_repo` and `issues/issue-management` traceability suites
  passed.
- Lint passed with zero warnings/errors across 269 files.
- `git diff --check` passed.

The generated terminal transcript was normalized to this durable review record
before publishing, per the repository's sidecar rule.
