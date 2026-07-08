---
id: 000175
status: working
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.24
started: 2026-07-08T13:46:25-07:00
---

# footnote diagnosis should open only on anchor span

## Problem

Parley's custom diagnostic virtual-line display currently opens a footnote
diagnosis whenever the cursor is anywhere on the logical line containing the
diagnostic span. In wrapped prose that is too broad: the diagnosis should appear
only while the cursor is on the selected term / `[^footnote]` anchor span. The
block also needs a small visual inset from the paragraph text column.

## Spec

- For diagnostics sourced from `parley-footnote`, current-line display should
  require the cursor position to be inside the diagnostic's `lnum/col` through
  `end_lnum/end_col` span.
- Non-footnote diagnostics, especially review diagnostics sourced from
  `parley-skill`, should keep the existing region behavior so a multi-line review
  explanation remains visible anywhere in its edit span.
- The virtual diagnosis block should render at buffer column 2, not column 0,
  while still avoiding Neovim's stock diagnostic-column indentation.
- Keep the logic in `skills/review/diag_display.lua` so review and define
  diagnostics share one display controller (ARCH-DRY, ARCH-PURPOSE).

## Done when

- Moving the cursor away from a footnote anchor on the same line hides the
  diagnosis.
- Moving the cursor onto the anchor span shows it.
- Review multi-line diagnostics still show anywhere inside their edit span.
- The display extmark is placed at column 2.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.03 impl=0.00
item: lua-neovim design=0.02 impl=0.11
item: milestone-review design=0.00 impl=0.08
total: 0.24
```

## Plan

- [x] Add failing integration coverage for footnote cursor-span scoping and
  column-2 display placement.
- [x] Update `diag_display` to distinguish footnote span scoping from review
  region scoping.
- [x] Run focused display/define tests, scoped whitespace check, and full suite.

## Log

### 2026-07-08
- Root cause: the current display predicate uses only line containment for all
  diagnostics, which is correct for review edit regions but too broad for
  footnote anchors on long wrapped markdown lines.
- Red: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`
  failed because the display extmark was still at column 0 and a footnote
  diagnostic rendered while the cursor was before the anchor on the same line.
- Green: `parley-footnote` diagnostics now require cursor position inside the
  diagnostic span; non-footnote diagnostics keep line/range containment. The
  display extmark now renders at column 2.
- Verification: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`;
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
  `git diff --check -- lua/parley/skills/review/diag_display.lua
  tests/integration/review_diag_display_spec.lua atlas/chat/inline_define.md
  atlas/modes/review.md workshop/issues/000175-footnote-diagnosis-anchor-span.md`;
  `make test`.
