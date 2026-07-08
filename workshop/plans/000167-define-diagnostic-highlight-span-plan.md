# Define Diagnostic Highlight Span Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make visual definition decorations visibly target the selected text plus `[^footnote]` reference instead of highlighting the whole paragraph line.

**Architecture:** Keep the span math in the existing pure `define.apply_definition_footnote` result (ARCH-PURE), and extend `skill_render`'s decoration snapshot to preserve column spans for undo/redo projection (ARCH-DRY). `render_definition` remains the thin IO shell that applies the span highlight and diagnostic.

**Tech Stack:** Lua, Neovim diagnostics/extmarks, Plenary/Busted tests.

---

## Core Concepts

### Pure Entities

| Name | Kind | Lives in | Status |
|------|------|----------|--------|
| `DefinitionDiagnosticSpan` | PURE | `lua/parley/define.lua` | reused |

- **DefinitionDiagnosticSpan** — the selected term plus immediate `[^id]` reference range returned by `apply_definition_footnote`.
  - **Relationships:** 1:1 with a definition render; consumed by `render_definition` for both diagnostic and highlight boundaries.
  - **DRY rationale:** The diagnostic and highlight should derive from the same span, not parallel column math.
  - **Future extensions:** Multi-line selections can widen the same span shape without changing the render caller.

### Integration Points

| Name | Kind | Lives in | Status | Wraps |
|------|------|----------|--------|-------|
| `SkillRenderSpanHighlight` | INTEGRATION | `lua/parley/skill_render.lua` | modified | Neovim extmarks |
| `DefineRenderDecorations` | INTEGRATION | `lua/parley/init.lua` | modified | Neovim diagnostics/projection |

- **SkillRenderSpanHighlight** — adds a column-scoped DiffChange extmark and snapshots/restores its exact range.
  - **Injected into:** `DefineRenderDecorations`.
  - **Future extensions:** Review edits can later opt into exact spans without changing projection storage again.
- **DefineRenderDecorations** — applies define highlights using the same span as the diagnostic.
  - **Injected into:** `define_visual`'s `on_done`.
  - **Future extensions:** If diagnostics get a dedicated namespace, this is the seam.

## Chunk 1: Pin the Regression

**Files:**
- Modify: `tests/unit/skill_render_spec.lua`
- Modify: `tests/integration/define_spec.lua`

- [x] **Step 1: Write failing tests**

Add tests showing:
- `skill_render.snapshot` and `apply_snapshot` preserve highlight columns.
- `skill_render.snapshot` and `apply_snapshot` preserve diagnostic `col` and
  `end_col`.
- visual define creates a highlight extmark spanning only `ASIN[^asin]`, not the full paragraph.
- visual define undo/redo restores both the highlight and diagnostic to the
  `ASIN[^asin]` span.

Run:
- `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"`
- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`

Expected: FAIL because define currently uses `highlight_line` and snapshots restore highlights as full-line.

## Chunk 2: Use Span Highlights for Define

**Files:**
- Modify: `lua/parley/skill_render.lua`
- Modify: `lua/parley/init.lua`

- [x] **Step 1: Add span highlight support**

Add a `skill_render.highlight_span(buf, lnum0, col_start, col_end)` helper that writes a `DiffChange` extmark on the existing highlight namespace.

- [x] **Step 2: Preserve highlight spans through projection**

Extend `snapshot` to capture extmark end columns and diagnostic `col`/`end_col`,
and `apply_snapshot` to restore them. Preserve backward compatibility for
existing whole-line highlights and older line-only diagnostic snapshots.

- [x] **Step 3: Wire define rendering to the diagnostic span**

Replace `highlight_line` calls in `render_definition` with `highlight_span` using `e.diagnostic_span`.

- [x] **Step 4: Verify focused tests**

Run:
- `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"`
- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`

Expected: PASS.

## Chunk 3: Final Verification

**Files:**
- Modify: `workshop/issues/000167-define-diagnostic-highlight-span.md`

- [x] **Step 1: Update issue log**

Record red/green evidence and mark the plan complete.

- [x] **Step 2: Run final checks**

Run:
- `git diff --check -- lua/parley/skill_render.lua lua/parley/init.lua tests/unit/skill_render_spec.lua tests/integration/define_spec.lua workshop/issues/000167-define-diagnostic-highlight-span.md workshop/plans/000167-define-diagnostic-highlight-span-plan.md`
- `make test`

Expected: all pass.
