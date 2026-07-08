---
id: 000173
status: codecomplete
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 0.38
started: 2026-07-08T13:21:02-07:00
actual_hours: 0.14
---

# diagnostic virtual lines blank on long wrapped markdown

## Problem

After #172, managed markdown footnotes are correctly restored as diagnostics,
but their inline virtual-line display can look blank on long wrapped markdown
paragraphs. The diagnostic payload is present and floats display it, but
Neovim's built-in `virtual_lines` handler prefixes the rendered message with
spaces equal to the diagnostic byte column. On a long prose line, the selected
text may be visible on a wrapped screen row while the virtual-line message starts
far to the right outside the viewport.

## Spec

- Parley diagnostics should remain anchored on the selected text / `[^footnote]`
  span so signs, underline, cursor-line filtering, jumps, and floats keep their
  existing behavior.
- The inline diagnostic display for Parley's namespace should render current-line
  messages from the left column, not from the diagnostic byte column.
- The display text should keep the existing wrapped diagnostic message and a
  clear `Diagnostics:` label.
- The fix should apply to the shared Parley diagnostic namespace, covering review
  diagnostics and footnote diagnostics without changing global/LSP diagnostics.

ARCH-DRY: keep one Parley diagnostic display controller in
`skills/review/diag_display.lua`; do not add a separate footnote-only renderer.
ARCH-PURE: no parser/data changes; keep the change in the thin Neovim display
shell and test its extmark output directly.
ARCH-PURPOSE: solve the actual blank-row symptom for long wrapped markdown, not
only color the hidden text.

## Done when

- A Parley diagnostic on a long line with a high column renders a visible
  left-column virtual line.
- The diagnostic itself remains at its original span for underline/float/jump
  behavior.
- Toggling `:ParleyShowDiagnostics` still disables/enables the inline display.
- Focused tests and full verification pass.

## Estimate

Produced via `estimate-logic-v3.1` against the repo-local calibration source
reported by `sdlc estimate-source` (stale but canonical for this repo).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.04 impl=0.00
item: lua-neovim design=0.06 impl=0.18
item: milestone-review design=0.00 impl=0.10
total: 0.38
```

## Plan

- [x] Add failing tests proving Parley virtual lines render from the left column.
- [x] Implement the Parley-owned virtual-line display handler.
- [x] Update atlas/issue log and run verification.

## Log

### 2026-07-08
- 2026-07-08: closed — Implemented Parley-owned left-column diagnostic virtual lines while preserving multi-line review diagnostic spans; verified focused display/find/define specs, git diff --check on touched files, and full make test.; review verdict: FIX-THEN-SHIP
- Root cause: a headless reproduction of Neovim's stock diagnostic virtual-lines
  handler showed `virt_lines = { { { string.rep(" ", diagnostic.col), "" }, ... } }`
  with `virt_lines_overflow = "scroll"`, so long wrapped markdown can display a
  blank inserted row while the message starts outside the viewport.
- Red test: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`
  failed because `diag_display` still configured stock `virtual_lines` and no
  `parley_diagnostic_virtual_lines` extmark was rendered.
- Implemented `parley/virtual_lines`, a custom diagnostic handler scoped to the
  Parley namespace. It renders a left-column `Diagnostics:` virtual-line block,
  updates on `CursorMoved`, disables stock virtual lines for Parley, and leaves
  the underlying diagnostic span unchanged.
- Focused green: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`.
- Final green: `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
  `git diff --check -- lua/parley/skills/review/diag_display.lua
  tests/integration/review_diag_display_spec.lua atlas/modes/review.md
  atlas/chat/inline_define.md
  workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.
- Boundary review returned REWORK: the custom renderer used `diagnostic.lnum ==
  cursor_line`, which regressed review diagnostics spanning `lnum..end_lnum`.
- Added a regression test for a multi-line review diagnostic, changed the
  current-line predicate to include `end_lnum`, and updated the stale module
  header comment.
- Re-verified: `nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"`;
  `nvim --headless -c "PlenaryBustedFile tests/unit/tools_builtin_find_spec.lua"`;
  `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`;
  `git diff --check -- lua/parley/skills/review/diag_display.lua
  tests/integration/review_diag_display_spec.lua atlas/modes/review.md
  atlas/chat/inline_define.md
  workshop/issues/000173-diagnostic-virtual-lines-leftcol.md
  workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md`; `make test`.
- Close re-review returned FIX-THEN-SHIP for generated review-sidecar hygiene
  only. Normalized the sidecar's terminal/control output and trailing whitespace,
  then re-ran the full branch whitespace check.
