---
id: 000191
status: working
deps: []
github_issue:
created: 2026-07-16
updated: 2026-07-16
estimate_hours: 0.7
started: 2026-07-16T12:19:56-07:00
---

# Fix issue finder archive path

## Problem

The SDLC archive layout now stores completed issue records in
`workshop/history/issues/`, but Parley's default `history_dir` still points at
the parent `workshop/history/`. Issue Finder's history view therefore scans a
directory containing only subdirectories and returns no archived issues.

## Spec

- Change the canonical default `history_dir` to `workshop/history/issues` so
  Issue Finder, next-ID discovery, and super-repo root expansion all derive the
  archive location from the migrated layout (`ARCH-DRY`, `ARCH-PURPOSE`).
- Preserve explicit `history_dir` overrides exactly; do not add dual-directory
  fallback scanning or recursive traversal.
- Update direct Issue Finder coverage to prove the production default selects
  `workshop/history/issues`, and update stale atlas path descriptions.

## Done when

- Issue Finder's history view discovers archived issue files under
  `workshop/history/issues/` in ordinary and super-repo modes.
- Explicit custom `history_dir` values remain supported.
- Focused tests, mapped tests, lint, and `git diff --check` pass.

## Plan

- [ ] Add a failing regression for the migrated default archive path.
- [ ] Change the canonical default and update stale test/atlas consumers.
- [ ] Run focused, mapped, lint, and diff verification; close and land.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.10 impl=0.20
item: atlas-docs design=0.05 impl=0.10
item: milestone-review design=0.00 impl=0.20
design-buffer: 0.05
total: 0.70
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only; the calibration source is stale, so
this estimate is provisional.*

## Log

### 2026-07-16

- Root cause: commit `ebaf054` moved archived issues into the per-kind
  `workshop/history/issues/` subdirectory without updating Parley's
  `history_dir` default or its documentation/tests. A single default-path
  correction keeps all existing consumers aligned; fallback scanning would
  preserve two sources of truth and could mix plan artifacts into issue search.
- Fresh-context spec review approved the narrow default-path correction with no
  findings. This simple fix keeps its complete plan in the issue file rather
  than adding a separate durable plan.
