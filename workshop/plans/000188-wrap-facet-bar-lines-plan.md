# Controlled Facet-Bar Wrapping Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render every configured picker facet through a deterministic, display-width-aware multi-row bar that reflows, remains clickable, and keeps the prompt correctly positioned.

**Architecture:** Add a small pure `facet_bar_layout` core that produces both rendered rows and canonical byte/cell spans. Keep Neovim display measurement, floating-window lifecycle, highlighting, scrolling, and mouse coordinates in the existing `float_picker` adapter; every UI path consumes the pure model rather than recalculating positions.

**Tech Stack:** LuaJIT, Neovim Lua API, Plenary/Busted, Luacheck, Atlas traceability.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `facet_bar_layout.build` | `lua/parley/facet_bar_layout.lua` | new |
| `facet_bar_layout.hit` | `lua/parley/facet_bar_layout.lua` | new |
| `float_picker.compute_layout` | `lua/parley/float_picker.lua` | modified |

- **`facet_bar_layout.build`** — produces immutable rows and segments from ordered tags,
  a content width, and injected display-text operations.
  - **Relationships:** one layout owns 1:N rendered rows and 1:N segments; each
    segment belongs to one semantic button, while a split button may own several
    segments.
  - **DRY rationale:** buffer text, highlights, mouse hits, resize, and updates
    all consume one positional authority instead of maintaining parallel column
    calculations (`ARCH-DRY`, `ARCH-PURE`).
  - **Future extensions:** new action kinds or alternative group gaps widen the
    button input, not the window adapter.
- **`facet_bar_layout.hit`** — pure lookup from `(buffer_row0, content_cell0)` to the
  segment/button at that location.
  - **Relationships:** N:1 queries against one layout.
  - **DRY rationale:** every mouse mapping delegates to one lookup policy.
  - **Future extensions:** hover or context-menu dispatch can reuse it.
- **`float_picker.compute_layout`** — existing centered picker geometry extended from a
  boolean one-row facet flag to requested/visible facet content heights.
  - **Relationships:** one geometry result positions one results window, zero or
    one facet window, and one prompt window.
  - **DRY rationale:** `float_picker` resize/open/update and Review Menu retain
    the same shared geometry source.
  - **Future extensions:** another stacked auxiliary window can add explicit
    height without duplicating centering arithmetic.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `display_text_units` | `lua/parley/float_picker.lua` | new | Neovim display-width and grapheme APIs |
| `reflow_picker` | `lua/parley/float_picker.lua` | new | Neovim buffers, floats, highlights, and views |
| `tag_bar_mouse_position` | `lua/parley/float_picker.lua` | new | Neovim mouse screen coordinates and window views |
| `ui/pickers` traceability entry | `atlas/ui/pickers.md`, `atlas/traceability.yaml` | modified | user-facing architecture map and executable spec mapping |

- **`display_text_units`** — converts UTF-8 button text into Neovim-defined
  extended grapheme units via `strcharpart(..., skipcc=true)` and reports
  `strdisplaywidth` for each string.
  - **Injected into:** `facet_bar_layout.build`, keeping packing deterministic in tests.
  - **Future extensions:** ambiguous-width policy can change at this seam.
- **`reflow_picker`** — creates/removes the optional facet float, renders
  the layout, applies byte-span highlights, converts screen positions through
  the current `topline`, and clamps its restored view.
  - **Injected into:** no pure entity; it consumes `facet_bar_layout.build` at
    the UI boundary.
  - **Future extensions:** keyboard facet focus remains an adapter concern.
- **`tag_bar_mouse_position`** — converts a screen coordinate into the model's
  buffer-row/display-cell coordinate, accounting for borders and `topline`.
  - **Injected into:** click and wheel adapters before `facet_bar_layout.hit`.
  - **Future extensions:** hover and keyboard-generated positions can reuse it.
- **`ui/pickers` traceability entry** — records controlled wrapping behavior and maps
  both new test files to `ui/pickers`.
  - **Injected into:** repository verification through `make test-spec` and
    `make test-changed`.
  - **Future extensions:** none; it follows shipped behavior only.

## Chunk 1: Controlled facet layout and picker integration

### Task 1: Build the pure row-layout authority

**Files:**
- Create: `lua/parley/facet_bar_layout.lua`
- Create: `tests/unit/facet_bar_layout_spec.lua`

- [ ] **Step 1: Write failing tests for the canonical one-row model**

  Cover `ALL NONE  [alpha] [beta]` visible spacing, action/facet enabled state,
  zero-based end-exclusive byte/cell spans, hit lookup on each button, and
  whitespace misses. Use injected helpers shaped like:

  ```lua
  local ops = {
      width = function(text) return vim.fn.strdisplaywidth(text) end,
      units = function(text) return test_units(text) end,
  }
  local model = layout.build(tags, 40, ops)
  assert.same({ " ALL NONE  [alpha] [beta]" }, model.lines)
  assert.equals("alpha", layout.hit(model, 0, alpha_cell).label)
  ```

- [ ] **Step 2: Run the unit suite and confirm the new module is missing**

  Run: `make test-unit JOBS=1`

  Expected: FAIL in `tests/unit/facet_bar_layout_spec.lua` because
  `parley.facet_bar_layout` cannot be required; unrelated unit files pass.

- [ ] **Step 3: Implement the minimal one-row model and hit lookup**

  Export only the pure surface:

  ```lua
  layout.build(tags, content_width, text_ops) --> { lines, segments, height }
  layout.hit(model, row0, cell0)             --> segment|nil
  ```

  Build semantic action buttons followed by bracketed facet buttons on one row,
  record byte and cell offsets while appending, and never derive ranges from the
  rendered string afterward. Do not add wrapping yet.

- [ ] **Step 4: Run the canonical model tests and verify they pass**

  Run: `make test-unit JOBS=1`

  Expected: PASS for one-row text, semantic state, spans, hits, and whitespace.

- [ ] **Step 5: Add failing wrapping and Unicode boundary tests**

  Pin exact breaks for: a facet moving intact; a facet split across three rows;
  multibyte byte spans differing from display-cell spans; `e` plus a combining
  acute accent; `👩‍💻` ZWJ emoji; `🇺🇸` regional-indicator flag; `👍🏽` emoji
  modifier; `1️⃣` variation-selector/keycap sequence; and an Indic conjunct.
  Each fixture must arrive as one injected unit. Also cover an indivisible
  two-cell unit at a one-cell usable width consuming input and terminating.

- [ ] **Step 6: Run the wrapping tests and verify RED behavior**

  Run: `make test-unit JOBS=1`

  Expected: FAIL on the first exact wrapped-row assertion because the minimal
  model still emits one over-width row.

- [ ] **Step 7: Implement deterministic maximal non-empty unit packing**

  Normalize width to at least one cell. Apply the spec's indent and group-gap
  rules, then consume the injected `units(text)` list into the largest prefix
  that fits. When the first unit exceeds the empty row, emit it alone. Every
  continuation segment retains the original `{ kind, label, enabled, active }`
  identity and begins after only the next row's standard indent.

- [ ] **Step 8: Run focused unit verification**

  Run: `make test-unit JOBS=1`

  Expected: PASS, including exact rows, byte/cell spans, hits, every extended
  grapheme fixture, and forced-progress cases.

- [ ] **Step 9: Commit the pure core**

  ```bash
  git add lua/parley/facet_bar_layout.lua tests/unit/facet_bar_layout_spec.lua
  git commit -m "picker: #188 model wrapped facet rows"
  ```

### Task 2: Make picker geometry consume facet height

**Files:**
- Modify: `lua/parley/float_picker.lua:39-53,501-523`
- Create: `tests/unit/float_picker_tag_bar_spec.lua`
- Modify: `tests/integration/review_menu_spec.lua:17-24`

- [ ] **Step 1: Write failing geometry compatibility and height tests**

  Assert numeric facet heights add `height + 2` border rows, results shrink no
  lower than `MIN_H = 1`, prompt row follows visible facet height, excessive
  facet height is capped to the positive available region, and
  `compute_layout(..., false)` returns the exact existing Review Menu geometry.

- [ ] **Step 2: Run unit and integration tests to verify the old boolean contract fails**

  Run: `make test-unit JOBS=1 && make test-integration JOBS=1`

  Expected: the new numeric-height assertions FAIL; existing Review Menu tests
  remain green.

- [ ] **Step 3: Extend `compute_layout` without breaking boolean callers**

  Treat a number as requested facet content height, `true` as legacy height 1,
  and false/nil as zero. Return the visible facet height as a seventh value.
  Compute width first, cap facet content after reserving prompt overhead and one
  results row, then center the final valid stack. Keep the first six return
  values and non-faceted arithmetic compatible (`ARCH-DRY`).

- [ ] **Step 4: Run geometry regressions**

  Run: `make test-unit JOBS=1 && make test-integration JOBS=1`

  Expected: PASS with unchanged non-faceted geometry and bounded faceted stacks.

- [ ] **Step 5: Commit the geometry seam**

  ```bash
  git add lua/parley/float_picker.lua tests/unit/float_picker_tag_bar_spec.lua tests/integration/review_menu_spec.lua
  git commit -m "picker: #188 size stacked facet rows"
  ```

### Task 3: Render and reflow from one model

**Files:**
- Modify: `lua/parley/float_picker.lua:574-780,1434-1511`
- Modify: `tests/unit/float_picker_tag_bar_spec.lua`

- [ ] **Step 1: Write failing open/render/highlight tests**

  Open a narrow picker and assert the facet buffer contains every exact model
  row, its float height matches the visible layout height, multibyte highlights
  use model byte spans, and the prompt row is immediately after the facet
  border. Assert active/inactive `ALL`/`NONE` actions and enabled/disabled facets
  receive the correct highlight on ordinary wrapped rows and every split-button
  continuation. Through the real picker adapter, render combining, ZWJ, flag,
  modifier, keycap, and Indic labels at widths where splitting a cluster would
  produce a different row; assert every production `display_text_units` cluster
  remains intact. Pin a wide one-row picker as visually identical to the old bar.

- [ ] **Step 2: Run the picker test and observe one clipped row**

  Run: `make test-unit JOBS=1`

  Expected: new picker tag-bar cases FAIL because the current renderer writes
  one line and fixes the facet window height to one.

- [ ] **Step 3: Add the Neovim display-text adapter and shared reflow function**

  Use Neovim 0.11's `strcharpart(..., skipcc=true)` extended-cluster behavior
  and measure with `strdisplaywidth`; do not hand-roll a partial Unicode
  segmenter. Introduce local `display_text_units` and one `reflow_picker` path
  that:

  1. derives width and calls `facet_bar_layout.build`,
  2. computes bounded stack geometry,
  3. creates/removes/configures the facet window as active state changes,
  4. writes model lines and model byte-span highlights,
  5. restores the previous `topline` clamped to the new maximum.

  A newly activated facet window starts at `topline = 1`; resize or tag updates
  preserve the numeric topline and clamp it rather than resetting. Enabled-only
  updates therefore do not jump away from a scrolled facet.

- [ ] **Step 4: Write failing resize and empty/non-empty lifecycle tests**

  Fire `VimResized` after changing the test UI width and assert exact rewrapped
  rows, facet height, results height, prompt position, and preserved query.
  Exercise `non-empty → empty → non-empty`, asserting window removal/recreation,
  reclaimed geometry, retained callbacks, and a new window starting at top.
  Assert `picker.update(items)` with no tags argument retains current facets;
  assert a picker opened without `opts.tag_bar` ignores later tag input without
  creating a facet window.

  Close the picker and assert a later handle update is a no-op without errors.
  Separately invalidate the facet/results window externally, then fire update
  and resize paths and assert the existing cleanup/no-error contract rather than
  recreating orphaned windows.

- [ ] **Step 5: Route open, resize, and `picker.update` through reflow**

  Base capability on `opts.tag_bar ~= nil`, active content on `#tags > 0`, nil
  update tags on preservation, and `{}` on deactivation. Keep the existing
  selection/filter refresh order and never replace or rewrite the prompt buffer.

- [ ] **Step 6: Run picker and mapped regressions**

  Run: `make test-unit JOBS=1 && make test-spec SPEC=ui/pickers`

  Expected: PASS; resize/update reflow and sticky query behavior remain green.

- [ ] **Step 7: Commit rendering and lifecycle integration**

  ```bash
  git add lua/parley/float_picker.lua tests/unit/float_picker_tag_bar_spec.lua
  git commit -m "picker: #188 render wrapped facet bars"
  ```

### Task 4: Make capped rows reachable and clickable

**Files:**
- Modify: `lua/parley/float_picker.lua:1200-1295`
- Modify: `tests/unit/float_picker_tag_bar_spec.lua`

- [ ] **Step 1: Write failing viewport and wheel tests**

  Force more facet rows than the capped float height. Assert a mouse position
  maps to `buffer_row0 = topline - 1 + visible_row0`, clicking a segment on a
  scrolled row containing wide Unicode dispatches its label, and clicking
  whitespace only refocuses the prompt. Assert dispatch remains deferred by 50
  ms and fires once; double/triple-clicks on every visible facet row remain
  suppressed and never confirm a result. Assert wheel down increments `topline`
  by exactly one, wheel up decrements by one, and both clamp to
  `[1, #lines - visible_height + 1]`.

  Cover wheel mappings in prompt insert mode, prompt normal mode, and results
  normal mode. For a pointer outside the facet rectangle, assert the expression
  mapping returns the original wheel termcode and native scrolling still occurs
  instead of consuming the event.

- [ ] **Step 2: Run the picker test and verify hidden rows are unreachable**

  Run: `make test-unit JOBS=1`

  Expected: viewport and wheel cases FAIL because current mouse mapping assumes
  a single content row and has no facet scrolling path.

- [ ] **Step 3: Implement screen-to-model coordinates and wheel dispatch**

  Add `tag_bar_mouse_position` to convert the facet screen rectangle to
  `(visible_row0, content_cell0)`, add the current window `topline - 1`, and call
  `facet_bar_layout.hit`. Preserve the existing deferred single-click callback
  and double/triple-click guards while widening them from one content row to the
  full visible rectangle.

  Install expression mappings for `<ScrollWheelDown>`/`<ScrollWheelUp>` in
  prompt insert/normal mode and results normal mode. When the pointer is inside
  the facet content rectangle, set the view by one clamped row and return
  `<Ignore>`; otherwise return the original wheel termcode under a nonrecursive
  mapping so Neovim performs its native action without re-entering the adapter.

- [ ] **Step 4: Run unit and mapped picker regressions**

  Run: `make test-unit JOBS=1 && make test-spec SPEC=ui/pickers`

  Expected: PASS, including scrolled click dispatch and all existing mouse,
  selection, query, finder, and Review Menu behaviors.

- [ ] **Step 5: Commit viewport interaction**

  ```bash
  git add lua/parley/float_picker.lua tests/unit/float_picker_tag_bar_spec.lua
  git commit -m "picker: #188 scroll wrapped facet rows"
  ```

### Task 5: Document, trace, and verify the completed behavior

**Files:**
- Modify: `atlas/ui/pickers.md:19-34`
- Modify: `atlas/traceability.yaml:512-529`
- Modify: `workshop/issues/000188-wrap-facet-bar-lines.md`
- Modify: `workshop/plans/000188-wrap-facet-bar-lines-plan.md`

- [ ] **Step 1: Update the picker atlas and traceability map**

  Describe controlled multi-row layout, dynamic stacked geometry, capped-window
  scrolling, and the single model for render/highlight/hits. Add
  `lua/parley/facet_bar_layout.lua`, `tests/unit/facet_bar_layout_spec.lua`, and
  `tests/unit/float_picker_tag_bar_spec.lua` to `ui/pickers`.

- [ ] **Step 2: Run focused verification**

  Run: `make test-spec SPEC=ui/pickers`

  Expected: PASS for every test mapped to the picker spec.

- [ ] **Step 3: Run the full verification suite serially**

  Run: `make test JOBS=1`

  Expected: lint reports zero issues; all unit, integration, and architecture
  test files pass. Serial execution avoids the known shared-test-environment
  race in `tools_builtin_find_spec.lua`.

- [ ] **Step 4: Check the final diff and issue schema**

  Run: `git diff --check && sdlc issue validate --issue 188`

  Expected: no whitespace errors; issue #188 conforms.

- [ ] **Step 5: Record evidence and complete checkboxes**

  Tick each implemented issue/plan checkbox and append a dated `## Log` entry
  with focused/full verification evidence and any manual UI observation. Do not
  rewrite earlier log or revision entries.

- [ ] **Step 6: Commit documentation and completion evidence**

  ```bash
  git add atlas/ui/pickers.md atlas/traceability.yaml workshop/issues/000188-wrap-facet-bar-lines.md workshop/plans/000188-wrap-facet-bar-lines-plan.md
  git commit -m "docs: #188 map wrapped facet bars"
  ```

- [ ] **Step 7: Cross the single SDLC close boundary**

  Run `sdlc close --issue 188 --verified '<focused and full-suite evidence>'`
  without a milestone tag. Follow the gate's measured-actual and atlas guidance;
  resolve Critical/Important fresh-review findings before retrying.

## Revisions

### 2026-07-15 — fresh-context plan review

- Reason: review found ambiguous conceptual names and missing edge assertions.
- Delta: named greppable Lua symbols; expanded grapheme/highlight coverage; and
  specified insert/normal wheel fallthrough plus deferred multi-click behavior.

### 2026-07-15 — second review pass

- Reason: review found wrapping implementation preceded its RED assertion and
  several adapter/lifecycle contracts lacked direct regression tests.
- Delta: restored strict TDD ordering and added production grapheme rendering,
  omitted-tag/capability, closed-handle, and invalid-window cases.
