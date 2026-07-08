---
id: 000165
status: codecomplete
deps: []
github_issue:
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 1.00
started: 2026-07-08T08:23:50-07:00
actual_hours: 0.11
---

# visual selection definition search should anchor at right column

right now, the diagnosis is anchored on the whole paragraph containing the visual selection, instead just the visually selected text span.

## Problem

`define_visual` preserves the selected phrase and wraps that exact span in
`[term]`, but `render_definition` attaches the resulting diagnostic at column
zero with no end column. For a selected term inside a paragraph, the definition
diagnostic is therefore anchored to the line/paragraph instead of the visual
selection that triggered the lookup.

## Spec

When a visual selection is defined, the inline definition diagnostic must carry
the post-render span of the selected text. For a single-line selection inside a
paragraph, that means the diagnostic starts at the selected text's left column
after the opening `[` is inserted and ends at the selected text's right column
before the closing `]`.

The existing exchange-context lookup, bracket edit, whole-line highlight, and
undo/redo projection behavior stay unchanged. ARCH-PURE: any new column math
should remain pure/testable or be a direct mapping from the already captured
visual span; `render_definition` remains the thin Neovim IO shell. ARCH-DRY: the
fix must reuse the existing `span`/`bracket_edit` data rather than re-scanning the
paragraph for the term. ARCH-PURPOSE: the diagnostic range, not just the bracket
text, is the acceptance surface.

## Done when

- A visual selection definition in paragraph text produces a diagnostic whose
  `col`/`end_col` match the selected term span in the bracketed buffer.
- Existing define behavior still brackets the term, highlights the affected
  lines, shows the definition message, and preserves undo/redo projection.
- Focused define tests and the full suite pass.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.10 impl=0.00
item: lua-neovim design=0.25 impl=0.35
item: milestone-review design=0.00 impl=0.20
design-buffer: 0.30
total: 1.00
```

## Plan

- [x] Add a failing integration assertion for the diagnostic's selected-text
      `col`/`end_col` after `[term]` insertion.
- [x] Update the define render path so the diagnostic range is anchored to the
      selected span's post-bracket columns.
- [x] Run focused define tests, then `make test`.

## Log

### 2026-07-08
- 2026-07-08: closed — TDD red confirmed with nvim --headless -c 'PlenaryBustedFile tests/integration/define_spec.lua' failing on diagnostic col 0 vs expected 9. Green verification: nvim --headless -c 'PlenaryBustedFile tests/unit/define_spec.lua'; nvim --headless -c 'PlenaryBustedFile tests/integration/define_spec.lua'; git diff --check on touched files; make test passed on rerun after an unrelated tools_builtin_find_spec transient passed in isolation.; review verdict: SHIP
- Claimed the issue and entered planning. Root cause: `render_definition` writes
  `col = 0/end_col = 0` even though it already receives the visual span.
- TDD red: `tests/integration/define_spec.lua` failed with diagnostic `col = 0`
  where the selected term should start at `9`.
- Implemented `define.diagnostic_span_after_bracket` (ARCH-PURE) and wired
  `render_definition` to use it; focused unit/integration define specs pass.
- Full `make test` passed after one transient unrelated
  `tests/unit/tools_builtin_find_spec.lua` failure reproduced green in isolation
  and on rerun.
