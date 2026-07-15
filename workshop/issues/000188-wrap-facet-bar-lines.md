---
id: 000188
status: working
deps: []
github_issue:
created: 2026-07-14
updated: 2026-07-15
estimate_hours: 2.27
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

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.30 impl=0.12
item: lua-neovim design=0.60 impl=0.60
item: atlas-docs design=0.10 impl=0.08
item: milestone-review design=0.10 impl=0.20
design-buffer: 0.15
total: 2.27
```

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only. The thorough reviewed spec earns the
v2.1 lineage's reduced design buffer; v3.1 scales implementation hours to the
AI-paired ship-wall-clock unit. The calibration source is currently marked
stale by `sdlc estimate-source`, so this derivation is provisional.

## Plan

- [x] Extract a pure display-width-aware facet row layout with focused tests.
- [x] Teach the shared facet window, highlights, and mouse hit testing to consume
  the multi-row layout.
- [x] Recompute facet height and prompt placement on open, resize, and update.
- [x] Run focused picker/finder regressions and the full test suite.

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

### 2026-07-15 — implementation planning

- Derived a 2.27-hour v3.1 estimate and captured the executable TDD plan in
  `workshop/plans/000188-wrap-facet-bar-lines-plan.md`. This remains one atomic
  close boundary rather than artificial milestones.
- Fresh-context plan review tightened greppable entity names, full grapheme
  fixtures, lower-row highlight coverage, insert/normal wheel fallthrough, and
  deferred multi-click suppression tests.
- Its second pass corrected the RED/GREEN ordering and added production-adapter,
  omitted-tag, capability, closed-handle, and invalid-window regressions.

### 2026-07-15 — Task 1 pure layout

- Added `facet_bar_layout.build/hit` under strict two-stage TDD. The module-missing
  and wrapping RED states were observed; the serialized unit suite passed.
- Independent spec and quality reviews approved commit `0295d90` with no
  findings (`ARCH-DRY`, `ARCH-PURE`).

### 2026-07-15 — Task 2 stacked geometry

- Extended `float_picker.compute_layout` with requested/visible facet heights
  while retaining its first six returns and boolean/non-faceted compatibility.
- The expected five geometry assertions failed before implementation; serialized
  unit/integration suites and independent reviews passed commit `9a9bb82`.
- Quality review additionally swept screen heights 1–200, facet requests through
  10,000, and historical non-faceted geometry without finding a boundary defect.

### 2026-07-15 — Task 3 shared reflow

- Replaced the one-row renderer and parallel lifecycle calculations with
  production grapheme units, pure-model rows/highlights, and one reflow path for
  open, resize, and update. Unit, mapped picker, and lint verification passed.
- Quality review found and reproduced two boundary defects: zero visible facet
  height could open an invalid float, and row-0 whitespace could hit a lower-row
  flattened range. Follow-up `1fed6b6` withheld zero-height windows while
  retaining logical state and moved transitional clicks to
  `facet_bar_layout.hit`; both review stages then approved with no findings.

### 2026-07-15 — Task 4 viewport interaction

- Added `topline`-aware row/cell mapping, model-based lower-row clicks, clamped
  facet wheel scrolling in prompt/results modes, and native outside-bar
  fallthrough. Focused tests grew to 27 cases and all mapped/lint checks passed.
- Quality review reproduced pending single-click dispatch after a physical
  double-click and extra mappings overwriting wheel reachability. Follow-up
  `f7c7fbb` added multi-click generation cancellation and reserved wheel keys;
  focused coverage reached 30 cases and both re-reviews approved.
- Headless Neovim has no attached mouse grid for a native viewport probe, so
  fallthrough is enforced through returned raw termcodes plus expression and
  nonrecursive mapping metadata in all three modes.

### 2026-07-15 — Task 5 documentation and verification

- `make test-spec SPEC=ui/pickers` passed all 10 mapped files: 245 tests, 0
  failures, and 0 errors. This includes automated headless UI coverage for
  exact wrapping and highlights, extended graphemes, open/resize/update reflow,
  active and zero-height facet-window transitions, `topline`-aware clicks and
  wheel scrolling in every picker mode, native outside-bar fallthrough, and
  single-row/query-preserving compatibility.
- `make test JOBS=1` passed every emitted unit, architecture, and integration
  spec file serially; Luacheck inspected 273 files with 0 warnings and 0 errors.
- `git diff --check` reported no whitespace errors, and
  `sdlc issue validate --issue 188` confirmed the issue schema conforms.
- Atlas traceability now maps the pure positional authority and both focused
  regression suites under `ui/pickers` (`ARCH-DRY`, `ARCH-PURE`,
  `ARCH-PURPOSE`).
- `ruby -e 'require "yaml"; YAML.load_file("atlas/traceability.yaml"); puts
  "traceability YAML: valid"'` parsed the traceability map successfully and
  printed `traceability YAML: valid`.

### 2026-07-15 — Task 5 traceability quality follow-up

- Root cause: independently added `providers/system_prompts` mappings shared a
  scalar key, so ordinary YAML loading silently shadowed the earlier code/test
  set; `ui/pickers` also retained `lua/parley/chat_dir_picker.lua` after
  `a3d9bed` deliberately deleted that dormant UI. The RED semantic audit
  reported exactly `duplicate key atlas/providers/system_prompts at line 428`
  and `missing ui/pickers/code: lua/parley/chat_dir_picker.lua`.
- Merged the system-prompt mapping as the duplicate-free union and removed only
  the stale picker path (`ARCH-DRY`, `ARCH-PURPOSE`). The duplicate-aware Psych
  AST plus path-existence GREEN audit printed `traceability semantic audit:
  PASS (no duplicate mapping keys; all code/test paths exist)`.

### 2026-07-15 — close-boundary readiness

- Fresh post-repair verification passed all 10 `ui/pickers` mapped files (245
  tests, 0 failures/errors), the complete serialized repository suite, and
  Luacheck across 273 files with 0 warnings/errors.
- Fresh spec and quality re-reviews approved the corrected Task 5 slice with no
  Critical, Important, or Minor findings. The sole close-boundary plan step is
  checked for the binary-owned boundary review.

### 2026-07-15 — close-boundary REWORK resolution

- The binary-owned review reproduced a tab-sensitive positional defect: the
  rendered facet ended at display cell 18 while its semantic span ended at 21,
  making trailing blank cells clickable (`ARCH-PURPOSE`). It also required the
  new wrapped-bar wheel interaction to be discoverable in the README.
- Pure and production-adapter tests first failed on the exact premature wrap
  and `21 != 18` span mismatch. The shared layout now passes each fragment's
  actual starting cell into the injected width operation for whole-button fit,
  split packing, and span endpoints; both focused regressions pass
  (`ARCH-DRY`, `ARCH-PURE`).
- Post-fix `make test-spec SPEC=ui/pickers` passed all 10 mapped files with 247
  tests and no failures/errors. A fresh `make test JOBS=1` exited 0 after every
  unit, architecture, and integration file passed; Luacheck reported 0 warnings
  and 0 errors across 273 files. Diff, issue-schema, and semantic traceability
  audits also passed before the close retry.

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

### 2026-07-15 — plan and estimate

- Reason: the reviewed spec was approved for implementation planning.
- Delta: added the reconciled v3.1 estimate and linked the durable plan; no
  product scope or acceptance behavior changed.

### 2026-07-15 — fresh-context plan review

- Reason: the first plan review found execution gaps around traceable symbols,
  Unicode fixtures, wrapped highlights, wheel fallthrough, active picker modes,
  and multi-click behavior.
- Delta: made each gap an explicit TDD assertion and based grapheme splitting on
  Neovim's tested `strcharpart(..., skipcc=true)` contract.

### 2026-07-15 — second plan review pass

- Reason: review found one TDD ordering error and lifecycle/adapter contracts
  that were specified but not yet tied to executable tests.
- Delta: moved exact wrapping assertions before implementation and added direct
  production-grapheme, omitted-tag, no-capability, closed, and invalid-window
  cases.
