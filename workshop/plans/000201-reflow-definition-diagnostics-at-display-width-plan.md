# Display-Width Diagnostic Reflow Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Parley diagnostic payloads width-independent and reflow definition floats and review virtual lines to the width of their actual display surface.

**Architecture:** `define.lua` canonicalizes generated definitions into one persisted paragraph, while a focused `diagnostic_text.lua` pure module converts semantic messages into display-cell-bounded rows. `skill_render.lua` publishes canonical diagnostic messages without presentation newlines. `diag_display.lua` is the thin UI shell: it measures visible windows/float geometry, injects Neovim's display-width function into the pure wrapper, and rerenders through one global lifecycle after width-changing window events. No external-service behavior changes.

**Tech Stack:** Lua, Neovim diagnostic/extmark/float APIs, Plenary/Busted tests, luacheck.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| Definition canonicalizer | `lua/parley/define.lua` | modified |
| Diagnostic row wrapper | `lua/parley/diagnostic_text.lua` | new |

- **Definition canonicalizer** — converts model output into one stable Markdown-footnote paragraph by trimming and collapsing every whitespace run to one ASCII space.
  - **Relationships:** N:1 from fresh tool output and rehydrated footer text to the canonical definition string used by both storage and diagnostics.
  - **DRY rationale:** `format_footnote_line`, `format_definition`, and `apply_definition_footnote` currently normalize independently; one function prevents stored and displayed definitions from diverging (`ARCH-DRY`).
  - **Future extensions:** Definition-specific escaping or length policy belongs at this boundary, not in renderers.
- **Diagnostic row wrapper** — transforms semantic text plus an effective display-cell width and injected measurement function into width-bounded rows, preserving explicit newline rows while normalizing horizontal display whitespace.
  - **Relationships:** 1:N from one diagnostic payload to rendered rows; both inline virtual lines and definition floats consume it.
  - **DRY rationale:** It is the sole wrapping algorithm for both display surfaces (`ARCH-DRY`, `ARCH-PURE`).
  - **Future extensions:** Hyphenation or alternative break policy widens this pure API without changing diagnostic storage.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| Diagnostic publication | `lua/parley/skill_render.lua` | modified | Neovim diagnostic state |
| Diagnostic display controller | `lua/parley/skills/review/diag_display.lua` | modified | Neovim windows, extmarks, floats, and autocmds |

- **Diagnostic publication** — publishes canonical definition/review messages without width-dependent newlines.
  - **Injected into:** The diagnostic row wrapper is not called here; renderers consume published messages later.
  - **Future extensions:** Other diagnostic consumers automatically receive semantic payloads.
- **Diagnostic display controller** — measures the narrowest usable text width for buffer-scoped virtual lines and the actual float content width, renders rows, and refreshes on cursor/window events.
  - **Injected into:** It supplies `vim.fn.strdisplaywidth` to the pure wrapper and owns all UI side effects (`ARCH-PURE`).
  - **Future extensions:** A per-window decoration provider could replace narrowest-window sharing if Neovim gains a simpler window-local virtual-line seam.

`ARCH-PURPOSE`: the plan covers the custom inline renderer, centered definition float, persisted footnote, and Neovim built-in diagnostic float. `ARCH-MOCK`: there is no new external dependency; the existing definition provider fake is unchanged.

### Non-goals

- Do not change definition prompting/provider behavior, footnote grammar, or diagnostic anchor spans.
- Do not introduce per-window decoration providers; buffer-scoped virtual lines deliberately use the narrowest visible width.
- Do not replace or customize Neovim's built-in diagnostic float.

## Chunk 1: Canonical payloads and shared wrapping

### Task 1: Canonicalize definitions

**Files:** `lua/parley/define.lua`, `tests/unit/define_spec.lua`, `tests/integration/define_spec.lua`

- [x] Test `define.normalize_definition`, `format_definition`, `apply_definition_footnote`, and `footnote_diagnostics`: arbitrary fresh/rehydrated whitespace forms → canonical idempotent one-paragraph messages and one-line footnotes.
- [x] Run the define unit and integration specs; expect RED from the missing shared canonicalizer and width-dependent formatter.
- [x] Implement `normalize_definition` ownership across the named definition functions.
- [x] Rerun both specs; expect GREEN.
- [x] Commit `diagnostics: #201 canonicalize definition payloads` with only the named code/tests.

### Task 2: Add pure display-cell wrapping

**Files:** `lua/parley/diagnostic_text.lua`, `tests/unit/diagnostic_text_spec.lua`

- [x] Test `diagnostic_text.wrap_rows`: arbitrary semantic-row structure and valid UTF-8 tokens under injected display widths → preserve input bytes/semantic rows and bound every rendered row without separating combining sequences.
- [x] Run the new unit spec; expect RED because the module is absent.
- [x] Implement `wrap_rows` and its private accumulated-width UTF-8 token splitter.
- [x] Rerun the unit spec; expect GREEN.
- [x] Commit `diagnostics: #201 wrap semantic text by display cells` with only the new module/spec.

## Chunk 2: Render-time reflow and lifecycle

### Task 3: Publish semantic messages

**Files:** `lua/parley/skill_render.lua`, `tests/unit/skill_render_spec.lua`, `tests/integration/define_spec.lua`

- [x] Test `skill_render.attach_diagnostics` and `refresh_footnote_diagnostics`: long semantic payloads under arbitrary creation widths → preserve semantic newlines and add no presentation newlines.
- [x] Run the skill-render spec; expect RED from creation-time wrapping.
- [x] Make the named publishers width-independent and remove obsolete creation-time formatting APIs.
- [x] Rerun focused specs and shadow-search obsolete APIs; expect GREEN/no consumers.
- [x] Commit `diagnostics: #201 publish semantic messages` with only the named code/tests.

### Task 4: Reflow custom displays

**Files:** `lua/parley/skills/review/diag_display.lua`, `tests/integration/review_diag_display_spec.lua`

- [x] Test `diagnostic_message_lines`, float geometry/rendering, and display lifecycle: adversarial text geometry plus same/different-buffer window-event sequences → target-width rows, border-safe placement, narrowest-visible virtual width, immutable payloads, and exactly one leak-free global lifecycle.
- [x] Run the diagnostic-display integration spec; expect RED from stale rows/geometry/lifecycle.
- [x] Implement the named render-time width, geometry, and global cursor/window lifecycle surfaces using `diagnostic_text.wrap_rows`.
- [x] Rerun the integration spec; expect GREEN.
- [x] Commit `diagnostics: #201 reflow at render width` with only the named code/tests.

### Task 5: Verify the built-in consumer

**Files:** `tests/integration/review_diag_display_spec.lua`

- [x] Test `vim.diagnostic.open_float`: one canonical payload across arbitrary float widths → Neovim owns wrapping while the underlying message stays unchanged and returned float objects are cleaned up.
- [x] Run the diagnostic-display integration spec; expect GREEN because Tasks 1–4 established the contract.
- [x] Commit `test: #201 cover built-in diagnostic reflow`.

## Chunk 3: Documentation and verification

### Task 6: Update the codebase map and issue evidence

**Files:**
- Modify: `atlas/chat/inline_define.md`
- Modify: `workshop/issues/000201-reflow-definition-diagnostics-at-display-width.md`

- [x] **Step 1: Update the inline-definition flow map**

Document that the managed footnote and diagnostic payload are canonical single-paragraph text, while `diag_display` performs display-cell wrapping at actual float/virtual-line width and refreshes on window resize. Remove the stale statement that `define.format_definition` calls creation-time `skill_render.format_diagnostic_message`.

- [x] **Step 2: Run atlas traceability verification**

Run `make test-changed`. Expected: the inline-definition traceability mapping and mapped specs PASS.

- [x] **Step 3: Run focused tests and lint**

```bash
for spec in tests/unit/define_spec.lua tests/unit/diagnostic_text_spec.lua tests/unit/skill_render_spec.lua tests/integration/define_spec.lua tests/integration/review_diag_display_spec.lua; do
  nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile $spec" -c "qa!" || exit 1
done
make lint
git diff --check
```

Expected: all focused specs PASS, lint reports zero warnings/errors, and `git diff --check` is silent.

- [x] **Step 4: Run the full suite in the repository's pinned ripgrep environment**

```bash
env PATH=/opt/homebrew/Cellar/ripgrep/15.1.0/bin:/Users/xianxu/.luarocks/bin:/opt/homebrew/bin:/usr/bin:/bin make test
```

Expected: all lint, unit, architecture, and integration checks PASS.

- [x] **Step 5: Record verified implementation evidence**

Only after Steps 2–4 succeed, tick each existing issue-plan summary checkbox without changing its wording. Append a dated `## Log` entry with the exact RED/GREEN commands, focused/full verification, root-cause confirmation, all display consumers covered, and `ARCH-DRY`/`ARCH-PURE`/`ARCH-PURPOSE` outcomes. Preserve all prior log and revision text.

Run `git diff --check` again after these issue/atlas edits. Expected: silent, so the final committed state—not only the pre-log code state—is whitespace-clean.

- [x] **Step 6: Commit docs and verified issue evidence**

```bash
git add atlas/chat/inline_define.md workshop/issues/000201-reflow-definition-diagnostics-at-display-width.md
git commit -m "docs: #201 map display-time diagnostic reflow"
```

- [ ] **Step 7: Close through the SDLC gate**

Run `sdlc actual --issue 201`, inspect its attribution, then run:

```bash
sdlc close --issue 201 --verified 'Focused define/diagnostic-text/skill-render/diagnostic-display specs pass; real narrow/wide/two-window/WinEnter/WinResized/built-in-float regressions pass; make test-changed, make lint, pinned-ripgrep full make test, and git diff --check pass.'
```

Do not hand-enter actual hours or bypass the atlas gate: the explicit atlas update must satisfy it. The close command owns the fresh-context boundary review and does not commit. On SHIP, run `git diff --check` over its generated mutations, then commit those #201 issue/review artifacts. On FIX-THEN-SHIP, implement every Critical/Important finding before committing (add a failing regression first for behavior changes), rerun affected focused/full verification, update `## Log`, run `git diff --check`, and bundle fixes plus close-generated issue/bookkeeping mutations into one commit; do **not** rerun close. Only if fixes must land after that close commit should `sdlc close` be rerun to review the new delta and advance the anchor. Preserve unrelated user-owned working-tree files in every commit.

## Revisions

### 2026-08-18 — resolve chunk plan reviews

- Moved wrapping into focused pure `diagnostic_text.lua`, added exact fresh and
  rehydrated normalization tests, and changed combining-mark handling to
  context-sensitive accumulated display-width measurement.
- Defined one deduplicated global display lifecycle, non-current resize and
  `WinEnter` coverage, exact border-aware geometry, tiny-parent behavior, and
  complete window/buffer cleanup.
- Moved issue checkbox/log finalization after verification, added
  `make test-changed`, made close evidence concrete, and specified post-verdict
  fix/commit handling without atlas bypass.

### 2026-08-18 — resolve plan-quality gate PQ-1

- Compressed enumerated fixtures and procedural diff descriptions into named
  function surfaces with adversarial input classes and mechanical invariants.
- Added explicit non-goals for provider behavior, footnote grammar, per-window
  decoration ownership, and Neovim's built-in float.
