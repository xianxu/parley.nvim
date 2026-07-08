---
id: 000167
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
started: 2026-07-08T10:12:09-07:00
estimate_hours: 0.91
---

# define diagnostic highlight should target footnote span

## Problem

After #166, visual definitions persist as `term[^id]` plus a managed footnote.
The diagnostic record spans that text, but the visible DiffChange decoration
still highlights the whole line. In a long paragraph that makes the annotation
appear paragraph-scoped instead of scoped to the selected text plus footnote
reference.

## Spec

- Visual definition diagnostics continue to cover the selected text plus the
  appended `[^id]` reference.
- The visible DiffChange highlight covers the same span, not the whole paragraph
  line.
- Undo/redo projection preserves that column span instead of restoring a
  full-line highlight or line-anchored diagnostic.

ARCH-PURE: keep span calculation in `define.apply_definition_footnote`.
ARCH-DRY: diagnostic and highlight ranges derive from the same span.
ARCH-PURPOSE: the fix is not complete if the visible decoration remains
paragraph-wide.

## Done when

- Defining `ASIN` inside `here is ASIN in context` highlights only
  `ASIN[^asin]`.
- Undo/redo still clears/restores the define diagnostic and exact highlight.
- After redo, both the diagnostic and highlight still span `ASIN[^asin]`, with
  diagnostic `col`/`end_col` preserved.
- Focused define/render tests and final verification pass.

## Estimate

Produced via `estimate-logic-v3.1` against the repo-local calibration source
reported by `sdlc estimate-source` (stale but canonical for this repo). Method A
only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.10 impl=0.00
item: lua-neovim design=0.20 impl=0.37
item: milestone-review design=0.00 impl=0.15
total: 0.91
```

## Plan

- [x] Add failing tests for exact define highlight/diagnostic spans and projection restore.
- [x] Add span highlight support to `skill_render` and preserve highlight plus diagnostic spans in snapshots.
- [x] Render define highlight from `DefinitionDiagnosticSpan`.
- [x] Run focused and final verification.

## Log

### 2026-07-08
- Created after user reported that #166 definitions visibly annotate the whole
  paragraph instead of the selected term/reference span. Root cause: define still
  used `skill_render.highlight_line`, and projection snapshots only restored
  whole-line highlights.
- Added failing coverage:
  `tests/unit/skill_render_spec.lua` failed because `highlight_span` did not
  exist; `tests/integration/define_spec.lua` failed because the define
  highlight and redo-restored highlight started at column 0 instead of column 8.
- Implemented `skill_render.highlight_span`, preserved highlight and diagnostic
  column spans in `snapshot`/`apply_snapshot`, and switched define rendering to
  use `e.diagnostic_span` for the visible highlight.
- Focused verification passed:
  `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"` and
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`.
- Final verification passed: `git diff --check -- lua/parley/skill_render.lua
  lua/parley/init.lua tests/unit/skill_render_spec.lua
  tests/integration/define_spec.lua
  workshop/issues/000167-define-diagnostic-highlight-span.md
  workshop/plans/000167-define-diagnostic-highlight-span-plan.md` and
  `make test`.
