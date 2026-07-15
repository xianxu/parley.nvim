# Boundary Review — parley.nvim#186 (whole-issue close)

| field | value |
|-------|-------|
| issue | 186 — issue finder in repo mode should present repo facet search |
| boundary | whole-issue close |
| window | `ef733b096bd4aed43cd65ed0cac7f2d00af229a2..HEAD` |
| timestamp | 2026-07-14T17:27:00-07:00 |
| verdict | REWORK |
| confidence | high |

## Summary

The fresh-context re-review confirmed that the implementation fulfills the
behavioral specification and independently reran the focused suites
successfully. It found one plan/code contradiction: the Core concepts table
used conceptual entity names that were not greppable symbols at their claimed
locations. Under the boundary contract this was Critical even though the code
and architecture were sound.

## Critical finding

`FinderFacetModel`, `ChatFinderFacetAdapter`, `IssueFinderRepoFacetAdapter`, and
`IssueFinderSessionState` did not exist as symbols. The table needed to name the
real `finder_facets` exports, finder entry points/local helpers, and
`_issue_finder.repo_facet_state`, then record the correction as a plan revision.

## Resolution

The Core concepts table now names actual greppable code entities at their stated
paths and retains their accurate PURE/INTEGRATION classifications. A timestamped
plan revision and a prevention rule in `workshop/lessons.md` record the change.
No implementation behavior changed.

## Evidence reviewed

- `finder_facets_spec.lua`: 12 tests passed.
- `chat_finder_logic_spec.lua`: 36 tests passed.
- `issue_finder_spec.lua`: 19 tests passed.
- `float_picker_spec.lua`: 63 tests passed.
- `git diff --check` passed.
- `ARCH-DRY`, `ARCH-PURE`, and `ARCH-PURPOSE` passed; atlas and traceability
  correctly cover the new model and Issue Finder flow.

The generated terminal transcript was compacted before immediate re-review per
the repository's failed-review-sidecar rule.
