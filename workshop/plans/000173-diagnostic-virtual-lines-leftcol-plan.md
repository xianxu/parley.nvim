# Diagnostic Virtual Lines Left Column Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Parley's inline diagnostic display visible on long wrapped markdown lines by rendering diagnostic virtual lines from the left column.

**Architecture:** Keep diagnostic data unchanged: spans stay anchored to selected text and footnote references. Replace only Parley's namespace display shell in `diag_display.lua`, so global/LSP diagnostics still use Neovim defaults. This follows ARCH-DRY by keeping one Parley display controller and ARCH-PURE by avoiding parser/data changes.

**Tech Stack:** Lua, Neovim diagnostics, extmarks, Plenary/Busted tests.

---

## Core Concepts

### Pure Entities

| Name | Lives in | Status |
|------|----------|--------|
| `ParleyDiagnosticMessageLines` | `lua/parley/skills/review/diag_display.lua` | new |

- **ParleyDiagnosticMessageLines** — deterministic conversion from a diagnostic message string into visible virtual-line rows with a `Diagnostics:` header.
  - **Relationships:** 1:N from one diagnostic message to display rows.
  - **DRY rationale:** Both review diagnostics and footnote diagnostics consume the same Parley namespace display.
  - **Future extensions:** If Parley later adds source-specific labels, this formatter is the one place to widen.

### Integration Points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `ParleyDiagnosticVirtualLines` | `lua/parley/skills/review/diag_display.lua` | modified | Neovim extmarks |

- **ParleyDiagnosticVirtualLines** — Parley-owned inline diagnostic renderer scoped to `skill_render.diag_namespace()`.
  - **Injected into:** `diag_display.set(on)`; toggling still owns all inline display setup.
  - **Future extensions:** Can add color overrides without changing diagnostic producers.

## Chunk 1: Left-Column Renderer

**Files:**
- Modify: `lua/parley/skills/review/diag_display.lua`
- Modify: `tests/integration/review_diag_display_spec.lua`
- Modify: `atlas/modes/review.md`
- Modify: `atlas/chat/inline_define.md`
- Modify: `workshop/issues/000173-diagnostic-virtual-lines-leftcol.md`

- [x] **Step 1: Write failing tests**

Add integration coverage that:
- Sets a Parley diagnostic at a high column on a long line.
- Enables `diag_display`.
- Asserts the generated display extmark has `virt_lines_leftcol = true`.
- Asserts the first virtual-line chunk is `Diagnostics:` instead of leading spaces.
- Asserts `dd.set(false)` clears the Parley display extmark while leaving the diagnostic data intact.

Run:

```bash
nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
```

Expected: FAIL because the stock diagnostic handler emits leading-space virtual lines and `diag_display` has no custom extmark namespace.

- [x] **Step 2: Implement the renderer**

In `lua/parley/skills/review/diag_display.lua`:
- Add a private display namespace.
- Add a private function that clears Parley diagnostic virtual-line extmarks.
- Add a private render function that reads diagnostics from `skill_render.diag_namespace()`, filters to the current cursor line, and writes `virt_lines` with `virt_lines_leftcol = true`.
- Configure Neovim diagnostics for the Parley namespace with `virtual_lines = false`, `virtual_text = false`, and existing signs/underline behavior.
- Register a buffer-local `CursorMoved` autocmd for visible Parley buffers so current-line behavior keeps updating.

- [x] **Step 3: Run green focused tests**

Run:

```bash
nvim --headless -c "PlenaryBustedFile tests/integration/review_diag_display_spec.lua"
```

Expected: PASS.

- [x] **Step 4: Update docs and issue log**

Update atlas text that says Parley uses built-in diagnostic `virtual_lines` so it instead describes the Parley-owned left-column inline renderer. Record red/green evidence in the issue log and tick plan items.

- [x] **Step 5: Final verification**

Run:

```bash
git diff --check -- lua/parley/skills/review/diag_display.lua tests/integration/review_diag_display_spec.lua atlas/modes/review.md atlas/chat/inline_define.md workshop/issues/000173-diagnostic-virtual-lines-leftcol.md workshop/plans/000173-diagnostic-virtual-lines-leftcol-plan.md
make test
```

Expected: all pass.
