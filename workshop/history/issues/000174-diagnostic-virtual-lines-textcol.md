---
id: 000174
status: done
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.20
started: 2026-07-08T13:37:10-07:00
actual_hours: 0.04
---

# diagnostic virtual lines should align with buffer text

## Problem

The #173 diagnostic display fix made long-line footnote diagnostics visible by
rendering Parley-owned virtual lines from the left edge of the window. In
practice that starts the block in the gutter/line-number area, so the
`Diagnostics:` label and wrapped text are visibly misaligned with the paragraph
text.

## Spec

- Parley's diagnostic virtual-line block should start at the buffer text column,
  not in the sign/number gutter.
- The block must still avoid Neovim's stock diagnostic-column indentation, so a
  high-column footnote diagnostic stays visible on long wrapped paragraphs.
- The underlying diagnostic span must remain unchanged for underline, jumps, and
  floats.
- Keep the behavior in the existing `skills/review/diag_display.lua` controller
  so review diagnostics and markdown footnote diagnostics stay unified
  (ARCH-DRY, ARCH-PURPOSE).
- This is a display-shell change only; no parser or diagnostic payload changes
  (ARCH-PURE).

## Done when

- A Parley diagnostic on a long line renders at text-column alignment.
- It no longer sets the gutter-anchored virtual-line option.
- Existing current-line and multi-line span behavior stays covered.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.02 impl=0.00
item: lua-neovim design=0.00 impl=0.10
item: milestone-review design=0.00 impl=0.08
total: 0.20
```

## Plan

- [x] Add a failing integration assertion for text-column virtual-line anchoring.
- [x] Update the custom renderer to stop using gutter anchoring.
- [x] Run focused diagnostics tests and whitespace checks.

## Log

### 2026-07-08
- 2026-07-08: closed — Removed gutter anchoring from Parley diagnostic virtual lines so the block aligns to buffer text column while preserving high-column diagnostic spans; verified red/green review diagnostic spec, define integration spec, scoped git diff --check, and full make test.; review verdict: SHIP
- Root cause: #173 set `virt_lines_leftcol = true`, which solved off-screen
  diagnostic-column indentation but anchors the block at the absolute window left
  edge, including the gutter. The desired anchor is buffer column 0 with normal
  virtual-line placement.
- Red: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`
  failed because the display extmark still set `virt_lines_leftcol = true`.
- Green: removed `virt_lines_leftcol` from the custom renderer, kept the extmark
  at column 0, updated atlas wording, and re-ran the focused spec successfully.
- Verification: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`;
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
  `git diff --check -- lua/parley/skills/review/diag_display.lua
  tests/integration/review_diag_display_spec.lua atlas/chat/inline_define.md
  atlas/modes/review.md workshop/issues/000174-diagnostic-virtual-lines-textcol.md`;
  `make test`.
