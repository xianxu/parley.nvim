# Timezone Diagnostics Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show local-time diagnostics for strict UTC timestamp strings in Parley chat and markdown buffers without editing buffer text.

**Architecture:** Add a pure timestamp diagnostic builder that scans lines for strict `YYYY-MM-DDTHH:MM:SSZ` tokens and returns diagnostic-shaped data. The pure builder takes an injected localizer (`to_local(epoch) -> table`) so conversion tests do not depend on the machine timezone; the Neovim publisher computes the real local table with `os.date("*t", epoch)` and injects it. Keep Neovim interaction in an autocmd-driven publisher wired into `highlighter.setup_buf_handler`, mirroring `interview.highlight_timestamps` and `skill_render.lua` namespace ownership. This follows `ARCH-PURE`, reuses Neovim diagnostics for `ARCH-DRY`, and delivers the actual diagnostic display requested by `ARCH-PURPOSE`.

**Tech Stack:** Lua, Neovim diagnostics API, Plenary headless tests.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `TimezoneTimestamp` | `lua/parley/timezone_diagnostics.lua` | new |
| `TimezoneDiagnostic` | `lua/parley/timezone_diagnostics.lua` | new |
| `TimezoneLocalizer` | `lua/parley/timezone_diagnostics.lua` | new |

- **TimezoneTimestamp** - A strict UTC ISO token with parsed numeric date/time fields and source range.
  - **Relationships:** 1:N from a buffer line to timestamp tokens; each token owns its own range and original text.
  - **DRY rationale:** Centralizes timestamp grammar and validity checks so UI refresh, tests, and future display variants do not each parse dates.
  - **Future extensions:** Offset timestamps (`+05:30`), configurable display formats, broader artifact types.

- **TimezoneDiagnostic** - Pure diagnostic data derived from a `TimezoneTimestamp`.
  - **Relationships:** 1:1 with each valid timestamp token; converted by the UI boundary into Neovim diagnostic records.
  - **DRY rationale:** Keeps local-time formatting and message text in one testable helper.
  - **Future extensions:** Severity/config knobs, custom message templates, virtual text-only display.

- **TimezoneLocalizer** - Injected function that maps a UTC epoch to local date/time fields.
  - **Relationships:** 1:N from detector call to all timestamps in that scan; the same localizer is reused for every token.
  - **DRY rationale:** Keeps UTC parsing deterministic while leaving real timezone lookup at the IO boundary.
  - **Future extensions:** Configurable target timezone, test fixtures for daylight-saving transitions.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `TimezoneDiagnosticPublisher` | `lua/parley/timezone_diagnostics.lua` | new | `vim.diagnostic` |
| `ParleyBufferRefresh` | `lua/parley/highlighter.lua` | modified | `BufEnter`, `WinEnter`, text-change autocmds |

- **TimezoneDiagnosticPublisher** - Reads buffer lines, calls the pure builder, and writes diagnostics to a Parley-owned namespace.
  - **Injected into:** Existing buffer-handler callbacks call the publisher; pure detection receives plain lines and the injected localizer.
  - **Future extensions:** Debounce for very large buffers if needed.

- **ParleyBufferRefresh** - Existing highlighter buffer lifecycle, extended to refresh timezone diagnostics for chat and markdown buffers.
  - **Injected into:** No pure entity; it is the IO shell that identifies managed buffers and delegates to the publisher.
  - **Future extensions:** Share a generic "refresh managed buffer decorations" helper if more diagnostic surfaces appear.

## Chunk 1: Pure Detector

### Task 1: Write failing pure tests

**Files:**
- Create: `tests/unit/timezone_diagnostics_spec.lua`
- Create: `lua/parley/timezone_diagnostics.lua`

- [x] Add tests for:
  - `2026-04-18T00:00:00Z` produces one diagnostic whose range covers only the token and whose message includes the UTC token and fake-local time.
  - `2026-04-18T00:00:00Z` passes exact epoch `1776470400` to the injected localizer, proving UTC epoch derivation is timezone-independent.
  - conversion uses the injected localizer, not ambient `os.date("*t")`.
  - invalid dates such as `2026-02-30T00:00:00Z` produce none.
  - non-UTC strings such as `2026-04-18T00:00:00+02:00` produce none.
  - diagnostic range columns cover only the timestamp token.

- [x] Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/timezone_diagnostics_spec.lua" -c "qa!"`

Expected: fails because the module/functions do not exist.

### Task 2: Implement pure detector and formatter

**Files:**
- Modify: `lua/parley/timezone_diagnostics.lua`
- Test: `tests/unit/timezone_diagnostics_spec.lua`

- [x] Implement strict token matching, UTC-consistent date validation, timezone-independent UTC epoch derivation, injected local-time formatting, and pure diagnostic records. Do not derive the UTC epoch with bare `os.time(table)`, because that treats the table as local time.
- [x] Run the unit spec until it passes.

## Chunk 2: Neovim Diagnostic Integration

### Task 3: Write failing integration tests

**Files:**
- Modify: `tests/integration/highlighting_spec.lua`
- Modify: `lua/parley/timezone_diagnostics.lua`

- [x] Add tests proving the publisher sets diagnostics on a chat buffer and clears stale diagnostics after the timestamp is removed.
- [x] Add a markdown-buffer case or direct publisher case proving the same namespace is independent from LSP diagnostics.
- [x] Assert diagnostics use a separate timestamp namespace exposed by `timezone_diagnostics.diag_namespace()`, mirroring `skill_render.diag_namespace()`.
- [x] Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/highlighting_spec.lua" -c "qa!"`

Expected: fails because diagnostics are not published yet.

### Task 4: Wire publisher into buffer refresh

**Files:**
- Modify: `lua/parley/highlighter.lua`
- Modify: `lua/parley/timezone_diagnostics.lua`
- Test: `tests/integration/highlighting_spec.lua`

- [x] Add `refresh_buffer(buf)` and namespace helper in `timezone_diagnostics.lua`.
- [x] Call refresh from chat and markdown `BufEnter`/`WinEnter` handling, next to `interview.highlight_timestamps(buf)`.
- [x] Add `TextChanged`, `TextChangedI`, and `BufWritePost` autocmd refresh for registered Parley buffers.
- [x] Do not publish diagnostics from the decoration provider (`on_win`/`on_line`); that path is for ephemeral extmarks only.
- [x] Run the integration spec until it passes.

## Chunk 3: Docs And Verification

### Task 5: Update atlas

**Files:**
- Modify: `atlas/modes/raw_mode.md` or a more specific existing atlas page if discovery shows a better fit.
- Modify: `atlas/index.md` if a new page is added.
- Modify: `atlas/traceability.yaml`

- [x] Document the timezone diagnostic surface and key files.
- [x] Prefer updating an existing diagnostics/highlighting page over creating a new page.

### Task 6: Final verification

- [x] Run: `sdlc issue validate workshop/issues/000108-create-diagosis-display-for-timezone-string-in-local-timezone.md`
- [x] Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/timezone_diagnostics_spec.lua" -c "qa!"`
- [x] Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/highlighting_spec.lua" -c "qa!"`
- [x] Run: `make test`
- [x] Run: `make lint`
