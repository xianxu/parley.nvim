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
- Update coverage to prove the production default reaches ordinary Issue
  Finder discovery, super-repo root expansion, and next-ID discovery while
  explicit `history_dir`/`history_dir_override` values remain verbatim; update
  stale atlas path descriptions.

## Done when

- Issue Finder's history view discovers archived issue files under
  `workshop/history/issues/` in ordinary and super-repo modes.
- Explicit custom `history_dir` values remain supported.
- Next-ID allocation includes archived issue IDs from the migrated directory.
- Focused tests, mapped tests, lint, and `git diff --check` pass.

## Plan

- [x] In `tests/unit/issue_finder_spec.lua`, add failing ordinary and super-repo
  discovery regressions deriving roots from `require("parley.config").history_dir`;
  in `tests/unit/issues_spec.lua`, pin next-ID archive discovery and existing
  explicit `history_dir`/`history_dir_override` forwarding.
- [x] Change only `lua/parley/config.lua`'s canonical `history_dir` default;
  keep `issues.get_history_dir()` and super-repo expansion as the shared
  consumers, then update stale fixtures plus `atlas/issues/issue-management.md`
  and `atlas/infra/repo_mode.md` (`ARCH-DRY`, `ARCH-PURPOSE`).
- [x] Run focused, mapped, lint, and diff verification; close and land.

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
- TDD red reproduced the regression in ordinary Issue Finder, super-repo root
  expansion, and next-ID allocation. Changing only `config.history_dir` to
  `workshop/history/issues` made Issue Finder 30/30, issue management 102/102,
  and neighborhood 13/13 pass; explicit custom overrides remain verbatim.
- `make test-changed` and the full `make test` suite pass. Lint reports zero
  warnings/errors across 301 files, atlas and comments contain no stale flat
  production path, and `git diff --check` is clean.

## Revisions

### 2026-07-16 — plan-quality consumer matrix

- Reason: the first `sdlc change-code` review found the plan named ordinary
  Issue Finder, super-repo expansion, next-ID allocation, and override
  compatibility as consumers but promised only one unspecified regression.
- Delta: name the exact production/test/atlas files and require coverage for
  each derived path while retaining the single default-constant production
  change. No fallback or new path resolver is added (`ARCH-DRY`,
  `ARCH-PURPOSE`).
