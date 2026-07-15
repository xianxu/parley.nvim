---
id: 000188
status: working
deps: []
github_issue:
created: 2026-07-14
updated: 2026-07-15
estimate_hours:
started: 2026-07-15T08:38:05-07:00
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

### Controlled layout design

`float_picker` owns a pure facet-row layout function. Given the ordered facet
buttons, the facet-window content width, and a display-width callback, it
returns rendered lines plus semantic hit regions shaped as `(row, start byte,
end byte, label)`. The UI adapter uses that same result for buffer text,
highlights, and mouse dispatch; it must not reconstruct positions separately.

Rows retain the existing leading space, button text, spacing, and highlight
semantics: `ALL NONE` remain actions, facets remain bracketed, and the action
group retains its wider gap before the first facet. A button moves intact to
the next row when it fits there. If one button is itself wider than the content
width, the layout splits it at display-character boundaries across rows so its
complete text remains visible; every segment keeps the same semantic label and
is clickable. Row width is measured with Neovim display width rather than Lua
byte length, while highlight and click ranges remain byte-column coordinates.

The shared picker geometry accepts the computed facet content height. Facet
window overhead is therefore `content height + two border rows`; results yield
vertical space as needed, and the prompt begins immediately below the facet
window. The exported geometry helper remains compatible with non-faceted
consumers such as Review Menu.

Opening, `VimResized`, and `picker.update(items, tags)` all follow one reflow
path: compute the current picker width, rebuild the pure facet layout, then
apply the results/facet/prompt window geometry and render from that model. The
update path must retain the existing prompt buffer, query text, selection, and
callbacks. Invalid or closed windows continue to use the picker's existing
no-op/cleanup behavior.

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

### 2026-07-15 — controlled layout design

- Chose an explicit display-width-aware row model over editor-managed wrapping
  or one float per row. One model drives text, highlights, hit testing, and
  stacked-window geometry (`ARCH-DRY`, `ARCH-PURE`, `ARCH-PURPOSE`).

## Revisions

### 2026-07-15

- Reason: design approval clarified that wrapping must be controlled by the
  picker rather than delegated to Neovim's window wrapping.
- Delta: specified row-layout output, multibyte and oversized-button behavior,
  row-aware hit regions, dynamic geometry, and the shared reflow path.
