---
id: 000188
status: open
deps: []
github_issue:
created: 2026-07-14
updated: 2026-07-14
estimate_hours:
---

# wrap facet bar across multiple lines

## Problem

The shared float-picker facet bar renders every action and facet on one
non-wrapping row. When the available facets exceed the picker width, later
facets are clipped and cannot be seen or selected. This is especially visible
in super-repo finders with many repository facets.

## Spec

- Lay out `[ALL]`, `[NONE]`, and facet labels across as many rows as needed to
  fit the current picker width instead of clipping the tail of one long row.
- Preserve the current styling, ordering, enabled/disabled highlights, keyboard
  behavior, and mouse selection semantics on every wrapped row.
- Size and position the facet window and prompt dynamically so wrapped facet
  rows sit between results and the search prompt without overlap.
- Reflow the facet rows when the picker width changes and when an in-place
  finder update changes the facet set.
- Keep the one-row presentation unchanged when all facets fit.
- Implement the wrapping/layout policy once in the shared `float_picker`; Chat,
  Issue, and future Markdown finders must not carry finder-specific wrapping
  logic (`ARCH-DRY`, `ARCH-PURE`).

## Done when

- A facet set wider than the picker renders completely over multiple rows.
- Every wrapped facet remains visibly styled and mouse-clickable.
- Picker resize and in-place facet updates recompute wrapping and keep the
  prompt directly below the facet window.
- Existing single-row facet presentation and query-preserving updates remain
  unchanged.
- Automated tests cover exact row breaks, multibyte display widths, wrapped-row
  hit testing, resize/update reflow, and the single-row compatibility case.

## Plan

- [ ] Extract a pure display-width-aware facet row layout with focused tests.
- [ ] Teach the shared facet window, highlights, and mouse hit testing to consume
  the multi-row layout.
- [ ] Recompute facet height and prompt placement on open, resize, and update.
- [ ] Run focused picker/finder regressions and the full test suite.

## Log

### 2026-07-14

- Filed from smoke testing #186: many repository facets currently run past the
  available row width, hiding later repositories. The desired behavior is a
  shared, wrapping facet bar rather than finder-specific truncation.
