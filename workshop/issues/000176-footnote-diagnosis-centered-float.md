---
id: 000176
status: codecomplete
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.36
started: 2026-07-08T14:02:53-07:00
actual_hours: 0.10
---

# footnote diagnosis should display in centered float

## Problem

Virtual-line diagnostics cannot render directly under a soft-wrapped screen row.
For footnote definitions, the desired effect is closer to an automatically
managed diagnostic float: while the cursor is on the term/`[^footnote]` anchor,
show the definition in a centered floating window like the built-in diagnostic
float, sized to most of the editing window.

## Spec

- `parley-footnote` diagnostics should render in an auto-managed floating window,
  not as Parley virtual lines.
- The float should open only while the cursor is inside the footnote diagnostic
  span, preserving #175's anchor-only trigger.
- The float should be 80% of the current editor window width, centered
  horizontally over that window, non-focusable, bordered, and visually similar to
  the current diagnostic presentation with a `Diagnostics:` header.
- The float should close when the cursor leaves the anchor span, when diagnostics
  are disabled, or when the handler hides/clears diagnostics.
- Non-footnote diagnostics, especially review diagnostics sourced from
  `parley-skill`, should keep the existing virtual-line behavior and multi-line
  region visibility.
- Keep this in `skills/review/diag_display.lua` so the display policy stays
  centralized (ARCH-DRY, ARCH-PURPOSE). Extract small deterministic helpers for
  width/column math where useful (ARCH-PURE).

## Done when

- A footnote diagnosis produces no Parley virtual-line extmark while the cursor
  is on its anchor.
- The same footnote diagnosis opens a centered, non-focusable float at 80% of the
  active window width.
- Moving off the anchor closes the float.
- Review diagnostics still render as virtual lines and keep their region
  behavior.

## Estimate

Derived via `estimate-logic-v3.1` against the repo-local calibration source from
`sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.04 impl=0.00
item: lua-neovim design=0.06 impl=0.18
item: milestone-review design=0.00 impl=0.08
total: 0.36
```

## Plan

- [x] Add failing integration coverage for footnote float display and review
  virtual-line preservation.
- [x] Implement a footnote-only centered float path in `diag_display`.
- [x] Update atlas, run focused display/define tests, scoped whitespace check,
  and full suite.

## Log

### 2026-07-08
- 2026-07-08: closed — Changed parley-footnote diagnostics from virtual lines to an auto-managed centered non-focusable float at 80% of active window width while preserving review virtual lines; verified red/green review_diag_display_spec, define_spec, arch buffer mutation spec, scoped git diff --check, and full make test.; review verdict: FIX-THEN-SHIP
- Design: footnotes move from virtual lines to an auto-managed float because
  virtual lines attach to logical buffer lines, not soft-wrapped screen rows.
  Review diagnostics remain virtual lines because their edit-region display is
  already working and less intrusive.
- Red: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`
  failed because footnote diagnostics still created a virtual-line extmark and
  no diagnostic float.
- Green: added a footnote-only float path in `diag_display`, sized to 80% of the
  active window and centered horizontally; review diagnostics still render as
  virtual lines.
- Full-suite fix: the first implementation wrote float buffer contents directly
  with `nvim_buf_set_lines`, and `tests/arch/buffer_mutation_spec.lua` rejected
  that. Routed the scratch float buffer write through
  `buffer_edit.replace_all_lines`, then re-ran the arch spec and full suite.
- Verification: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`;
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
  `nvim --headless -c "PlenaryBustedFile tests/arch/buffer_mutation_spec.lua"`;
  `git diff --check -- lua/parley/skills/review/diag_display.lua
  tests/integration/review_diag_display_spec.lua atlas/chat/inline_define.md
  atlas/modes/review.md workshop/issues/000176-footnote-diagnosis-centered-float.md`;
  `make test`.
- Boundary review returned FIX-THEN-SHIP for stale README wording only. Updated
  README's visual `<M-CR>` description from grey pop-under to centered diagnostic
  float.
