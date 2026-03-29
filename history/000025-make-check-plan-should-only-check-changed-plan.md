---
id: 000025
status: done
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# `make check-plan` should only check changed plan

do not check all files in issues, as it's by design will have future work items we are not addressing in this change

## Done when

- [x] `check-plan` only reviews issue files that changed in the diff
- [x] Skips entirely if no issue files changed

## Plan

- [x] Add `git_diff_context_issues()` and `git_changed_issues()` helpers to `pre-merge-checks.sh`
- [x] Scope the `plan` prompt to only changed issue files (pass issues diff instead of code diff)
- [x] Add early return when no issue files changed

## Log

### 2026-03-29

Changed `scripts/pre-merge-checks.sh`:
- Added two helpers: `git_diff_context_issues()` (issue-only diff) and `git_changed_issues()` (list of changed issue filenames)
- Rewrote `plan` prompt to only review changed issue files, passing the issues diff directly into the prompt
- Added early skip when no issue files changed — avoids wasting an agent invocation

