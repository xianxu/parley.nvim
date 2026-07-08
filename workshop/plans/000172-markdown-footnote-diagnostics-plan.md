# Markdown Footnote Diagnostics Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rehydrate persisted managed markdown footnotes into Parley diagnostics whenever chat or markdown buffers are entered or refreshed.

**Architecture:** Add pure extraction in `define.lua` that derives diagnostic records from the existing final managed-footer shape (ARCH-PURE). Add a thin Neovim integration in `skill_render.lua` that publishes those records in Parley's diagnostic namespace using the shared diagnostic formatter (ARCH-DRY). Wire both chat and non-chat markdown lifecycle hooks so persisted footnotes display after reopen/reenter, not only immediately after define writes them (ARCH-PURPOSE).

**Tech Stack:** Lua, Neovim diagnostics, markdown buffers, Plenary/Busted tests.

---

## Core Concepts

### Pure Entities

| Name | Lives in | Status |
|------|----------|--------|
| `MarkdownFootnoteDiagnostic` | `lua/parley/define.lua` | new |
| `ManagedFootnoteFooter` | `lua/parley/define.lua` | modified |

- **MarkdownFootnoteDiagnostic** — pure diagnostic data derived from inline `[^id]` references and final managed footer definitions.
  - **Relationships:** N:1 with a markdown buffer; one managed footer can define many IDs, and each ID can produce many inline-reference diagnostics.
  - **DRY rationale:** The define write path and reopen/reenter path both use the same persisted markdown shape.
  - **Future extensions:** If Parley later supports non-final or multi-line footnotes, this extractor is the one place to widen.
- **ManagedFootnoteFooter** — existing conservative footer detector reused for diagnostics.
  - **Relationships:** 1:1 with the final managed footer in a buffer.
  - **DRY rationale:** Do not invent a second definition of "managed footer".
  - **Future extensions:** Can expose parsed footer lines for chat submission stripping and diagnostics.

### Integration Points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `FootnoteDiagnosticRefresh` | `lua/parley/skill_render.lua` | new | `vim.diagnostic.set` |
| `MarkdownBufferLifecycle` | `lua/parley/highlighter.lua` | modified | BufEnter/WinEnter/TextChanged/BufWritePost |

- **FootnoteDiagnosticRefresh** — reads buffer lines, calls `define.footnote_diagnostics`, formats messages, and publishes diagnostics in `parley_skill`.
  - **Injected into:** `MarkdownBufferLifecycle` and define render after the text write.
  - **Future extensions:** Could later merge with highlights for rehydrated definitions if desired.
- **MarkdownBufferLifecycle** — existing buffer handler that already refreshes timezone diagnostics for chat and markdown buffers.
  - **Injected into:** Neovim autocmds in `setup_buf_handler`.
  - **Future extensions:** Additional persisted markdown diagnostics can use the same refresh call.

## Chunk 1: Pure Extraction

**Files:**
- Modify: `lua/parley/define.lua`
- Modify: `tests/unit/define_spec.lua`

- [x] **Step 1: Write failing pure tests**

Add tests for `define.footnote_diagnostics(lines)` showing:
- `here is ASIN[^asin] in context` plus final `[^asin]: ...` yields one diagnostic spanning `ASIN[^asin]` or at minimum the `[^asin]` reference span with the definition message.
- Multiple inline references to the same ID produce multiple diagnostics.
- Ordinary horizontal-rule content and non-final footnotes are ignored.

- [x] **Step 2: Run red unit test**

Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`

Expected: FAIL because `footnote_diagnostics` does not exist.

- [x] **Step 3: Implement extractor**

Expose a pure `define.footnote_diagnostics(lines)` that:
- Finds the existing final managed footer.
- Parses footer lines as `{ id, definition }`.
- Scans body lines before the footer for inline `[^id]` references.
- Expands each diagnostic start column left over the adjacent term token when possible, so diagnostics match define's term/reference span for simple `term[^id]` cases.

- [x] **Step 4: Run green unit test**

Run: `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`

Expected: PASS.

## Chunk 2: Diagnostic Refresh Integration

**Files:**
- Modify: `lua/parley/skill_render.lua`
- Modify: `lua/parley/highlighter.lua`
- Modify: `lua/parley/init.lua`
- Modify: `tests/integration/highlighting_spec.lua`
- Modify: `tests/integration/define_spec.lua`

- [x] **Step 1: Write failing integration coverage**

Add coverage that:
- Calls the refresh function on a scratch markdown buffer and sees `parley_skill` diagnostics for persisted footnotes.
- Drives the buffer handler/autocmd path for a markdown file so `BufEnter` or `TextChanged` refreshes stale diagnostics.
- Confirms the existing define immediate path still displays diagnostics.

- [x] **Step 2: Run red focused tests**

Run:
- `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`
- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`

Expected: FAIL because no persisted-footnote refresh exists.

- [x] **Step 3: Implement refresh integration**

Add `skill_render.refresh_footnote_diagnostics(buf)`:
- Keep review/define diagnostics in the same namespace.
- Prefer preserving non-footnote diagnostics from the same namespace when possible, or document/reuse the existing "one Parley diagnostic surface" behavior if replacement is intentional.
- Format messages with `format_diagnostic_message`.

Wire the function in `highlighter.setup_buf_handler` for both chat and markdown branches on `BufEnter`, `WinEnter`, and text/write refresh. Call it from `render_definition` after the managed footnote write so the immediate path and rehydrated path use the same diagnostic creation.

- [x] **Step 4: Run green focused tests**

Run:
- `nvim --headless -c "PlenaryBustedFile tests/unit/define_spec.lua"`
- `nvim --headless -c "PlenaryBustedFile tests/integration/highlighting_spec.lua"`
- `nvim --headless -c "PlenaryBustedFile tests/integration/define_spec.lua"`

Expected: PASS.

## Chunk 3: Docs and Final Verification

**Files:**
- Modify: `atlas/chat/inline_define.md`
- Modify: `workshop/issues/000172-markdown-footnote-diagnostics.md`

- [x] **Step 1: Update docs and issue log**

Update the inline define atlas page to say persisted managed footnotes are rehydrated into diagnostics for markdown buffers. Record red/green evidence in the issue log and tick checkboxes.

- [x] **Step 2: Run final checks**

Run:
- `git diff --check -- lua/parley/define.lua lua/parley/skill_render.lua lua/parley/highlighter.lua lua/parley/init.lua tests/unit/define_spec.lua tests/integration/highlighting_spec.lua tests/integration/define_spec.lua atlas/chat/inline_define.md workshop/issues/000172-markdown-footnote-diagnostics.md workshop/plans/000172-markdown-footnote-diagnostics-plan.md`
- `make test`

Expected: all pass.
