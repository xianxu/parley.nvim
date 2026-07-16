# Diagnostic Display Soft Wrap Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Parley diagnostic messages word-wrap consistently before display in Neovim virtual lines.

**Architecture:** Keep `diag_display` focused on toggling visibility, and move message wrapping to the shared diagnostic render boundary in `skill_render` (ARCH-DRY). The wrapping function remains pure; the current-window width lookup stays a thin IO helper used only when formatting diagnostics for display (ARCH-PURE). Define diagnostics must derive from the same helper as review diagnostics so the stated purpose covers every `parley_skill` consumer (ARCH-PURPOSE).

**Tech Stack:** Lua, Neovim diagnostics/virtual_lines, Plenary/Busted tests.

---

## Core Concepts

### Pure Entities

| Name | Lives in | Status |
|------|----------|--------|
| `DiagnosticMessageWrap` | `lua/parley/skill_render.lua` | modified |

- **DiagnosticMessageWrap** — word-wraps diagnostic text using the existing `skill_render.wrap` behavior.
  - **Relationships:** 1:N with Parley diagnostic producers; review and define diagnostics both use it before `vim.diagnostic.set`.
  - **DRY rationale:** One wrapping policy for all `parley_skill` virtual-line diagnostics.
  - **Future extensions:** Configurable width or indentation compensation can widen this helper without touching individual features.

### Integration Points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `ParleyDiagnosticFormatting` | `lua/parley/skill_render.lua` | modified | Neovim window width + diagnostics |
| `DefineDiagnosticFormatter` | `lua/parley/define.lua` | modified | shared diagnostic formatter |
| `DefineDiagnosticProducer` | `lua/parley/init.lua` | modified | `vim.diagnostic.set` |

- **ParleyDiagnosticFormatting** — applies `DiagnosticMessageWrap` using the current window's usable diagnostic width.
  - **Injected into:** `attach_diagnostics` and define rendering through a shared `skill_render` helper.
  - **Future extensions:** Other Parley diagnostic producers can call the same helper.
- **DefineDiagnosticFormatter** — composes the term/definition text and delegates display wrapping to `skill_render.format_diagnostic_message`.
  - **Injected into:** `DefineDiagnosticProducer`.
  - **Future extensions:** Alternate definition display formats still inherit the shared wrapping policy.
- **DefineDiagnosticProducer** — creates the define diagnostic for the selected term/reference span.
  - **Injected into:** The existing `render_definition` IO seam.
  - **Future extensions:** Multi-diagnostic define output would still format every message through `skill_render`.

## Chunk 1: Pin Wrapping Behavior

**Files:**
- Modify: `tests/unit/skill_render_spec.lua`
- Modify: `tests/integration/define_spec.lua`

- [x] **Step 1: Add failing unit coverage**

Add a test proving a new shared diagnostic message helper word-wraps a long
message at a supplied width. This should call real `skill_render` code and assert
every wrapped line fits the width except single long words.

- [x] **Step 2: Add failing define coverage**

Extend the define integration test with a long definition and a narrow window.
Assert the diagnostic message contains newline breaks and no wrapped line exceeds
the expected width except single long words.

- [x] **Step 3: Run red tests**

Run:
- `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"`
- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`

Expected: FAIL because define diagnostics still format with their own width path
and there is no shared diagnostic message helper.

## Chunk 2: Shared Diagnostic Message Formatting

**Files:**
- Modify: `lua/parley/skill_render.lua`
- Modify: `lua/parley/define.lua`
- Modify: `lua/parley/init.lua`

- [x] **Step 1: Add shared helper**

Add `skill_render.format_diagnostic_message(text, width)` that delegates to
`skill_render.wrap`. Add `skill_render.diagnostic_wrap_width()` or an equivalent
public helper if callers need the current usable diagnostic width.

- [x] **Step 2: Route review diagnostics through the helper**

Update `skill_render.attach_diagnostics` to use the shared helper instead of
calling `wrap` directly. Preserve existing behavior for fallback width and long
single words.

- [x] **Step 3: Route define diagnostics through the helper**

Update `render_definition` to pass `skill_render.diagnostic_wrap_width()` into
`define.format_definition`, and update `define.format_definition` to delegate
wrapping to `skill_render.format_diagnostic_message`. Keep the diagnostic
span/highlight behavior from #167 unchanged.

- [x] **Step 4: Run focused green tests**

Run:
- `nvim --headless -c "PlenaryBustedFile tests/unit/skill_render_spec.lua"`
- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`

Expected: PASS.

## Chunk 3: Final Verification

**Files:**
- Modify: `workshop/issues/000169-diagnostic-display-soft-wrap.md`
- Modify if docs change: `atlas/chat/inline_define.md`, `atlas/modes/review.md`, or related atlas pages

- [x] **Step 1: Update issue log and checkboxes**

Record red/green evidence and final verification commands.

- [x] **Step 2: Run final checks**

Run:
- `git diff --check -- lua/parley/skill_render.lua lua/parley/define.lua lua/parley/init.lua tests/unit/skill_render_spec.lua tests/integration/define_spec.lua atlas/chat/inline_define.md atlas/modes/review.md workshop/issues/000169-diagnostic-display-soft-wrap.md workshop/plans/000169-diagnostic-display-soft-wrap-plan.md`
- `make test`

Expected: all pass.
