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

- Lay out the existing `ALL` and `NONE` actions plus bracketed facet labels
  across as many rows as needed to
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
buttons, the facet-window content width, and injected text-width/splitting
callbacks, it returns rendered lines plus semantic segments. Every segment
records button identity/style, a zero-based row, zero-based end-exclusive byte
columns for highlights, and zero-based end-exclusive display-cell columns for
mouse lookup. The UI adapter converts mouse screen coordinates to a facet-row
and content-cell pair, then queries those cell spans. It uses the same result
for buffer text and highlights; no consumer reconstructs positions.

Packing is deterministic. Every row starts with one ASCII-space cell. The
prefix before a button is zero cells for the first button on a row, one cell
between buttons in the same group, and two cells between `NONE` and the first
facet when they share a row. Prefix plus whole button must fit the remaining
content width; otherwise the button starts after the next row's one-cell
indent, without carrying its old group gap. No trailing separator or padding
is rendered. This preserves the visible one-row presentation and fixes exact
row breaks for tests; byte-identical preservation of the old invisible trailing
space is not required.

Buttons normally remain intact. A button wider than a fresh row's usable width
is split into maximal non-empty extended grapheme-cluster sequences; combining
marks and ZWJ-connected codepoints stay attached. Continuation rows use only
the normal one-cell indent, with no added inter-button separator. Each segment
retains the button's semantic identity/style and is clickable. The splitter
must always consume at least one grapheme cluster; if an indivisible cluster is
wider than the usable row, it is emitted alone to guarantee progress and
preserve text. The picker's normal minimum width makes that fallback exceptional.

The shared picker geometry accepts the computed facet content height. Facet
window overhead is therefore `content height + two border rows`; results yield
vertical space down to `float_picker`'s existing `MIN_H = 1` results-row
minimum, and the prompt begins immediately below the facet window. If prompt,
borders, one results row, and all facet rows cannot physically fit, valid
on-screen geometry takes priority: the facet window is capped to the remaining
positive height and retains every rendered row in its buffer. Mouse-wheel input
over its screen rectangle scrolls that non-focusable window; row hit testing
maps the visible screen row through the facet window's current `topline` before
querying semantic segments, so facets exposed by scrolling remain clickable.
Wheel input elsewhere keeps its existing behavior. Complete simultaneous facet
visibility is guaranteed whenever the editor can contain the required stack.
The exported geometry helper's non-faceted behavior and Review Menu consumer
remain unchanged.

Opening, `VimResized`, and `picker.update(items, tags)` all follow one reflow
path: compute the current picker width, rebuild the pure facet layout, then
apply the results/facet/prompt window geometry and render from that model. The
update path must retain the existing prompt buffer, query text, selection, and
callbacks. Invalid or closed windows continue to use the picker's existing
no-op/cleanup behavior.

Facet capability is configured by the presence of `opts.tag_bar`; active facet
content is determined by whether its `tags` list is non-empty. Within a
configured picker, an update that supplies an empty list removes the facet
window and reclaims its rows, while a later non-empty list recreates it and
reflows the stack using the retained callbacks. Omitting the update's `tags`
argument preserves the current facet set. A picker opened without
`opts.tag_bar` has no facet callbacks, so updates cannot introduce facets.

## Done when

- A facet set wider than the picker renders completely over multiple rows.
- Every wrapped facet remains visibly styled and mouse-clickable.
- Picker resize and in-place facet updates recompute wrapping and keep the
  prompt directly below the facet window.
- Existing single-row facet presentation and query-preserving updates remain
  unchanged.
- Automated tests cover exact row breaks, multibyte display widths, wrapped-row
  hit testing, resize/update reflow, and the single-row compatibility case.
- Automated tests also cover indivisible over-width grapheme progress,
  constrained-height scrolling with viewport-aware clicks, empty/non-empty
  facet-window transitions, and unchanged non-faceted geometry.

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

### 2026-07-15 — spec review resolution

- Defined canonical byte and display-cell spans, exact spacing and wrapping,
  grapheme-safe oversized buttons, constrained-height fallback, and facet
  window activation/deactivation during updates.

### 2026-07-15 — constrained-height review resolution

- Specified wheel scrolling for the non-focusable capped facet window,
  `topline`-aware click mapping, and regression coverage for the new edge
  contracts. Confirmed the current picker minimum is already `MIN_H = 1`.

## Revisions

### 2026-07-15

- Reason: design approval clarified that wrapping must be controlled by the
  picker rather than delegated to Neovim's window wrapping.
- Delta: specified row-layout output, multibyte and oversized-button behavior,
  row-aware hit regions, dynamic geometry, and the shared reflow path.

### 2026-07-15 — fresh-context spec review

- Reason: independent review found ambiguity in action syntax, coordinate
  conventions, exact row packing, indivisible display units, vertical overflow,
  and zero/nonzero facet updates.
- Delta: aligned action text with the existing UI and made each boundary
  deterministic, including a valid-geometry fallback for physically impossible
  full-height layouts.

### 2026-07-15 — second fresh-context spec review

- Reason: review identified that capped overflow rows lacked a reachable scroll
  mechanism and that newly clarified edge contracts were absent from Done when.
- Delta: defined mouse-wheel/topline behavior, expanded automated coverage, and
  clarified visible—not trailing-whitespace—single-row compatibility. The
  review's separate minimum-height concern was checked against
  `float_picker.MIN_H = 1` and required no behavior change.
