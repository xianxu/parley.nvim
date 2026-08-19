---
id: 000201
status: working
deps: []
github_issue:
created: 2026-08-18
updated: 2026-08-18
estimate_hours:
started: 2026-08-18T17:17:25-07:00
---

# Reflow definition diagnostics at display width

## Problem

Definition diagnostics are hard-wrapped when they are created, using the
current editor window's width. The resulting newline characters become part of
the persisted diagnostic message. When the same message is later shown in the
centered diagnostic float, whose width differs from the editor window, those
stale breaks cannot reflow: short fragments and uneven line lengths remain even
though the float has more or less room. The managed footnote itself is one
logical Markdown line and soft-wraps correctly, so storage and popup presentation
currently have inconsistent width semantics.

## Spec

- Diagnostic payloads are semantic text, not a snapshot of one presentation
  width. No editor-width hard wrapping is stored in `diagnostic.message`.
- Definition output is canonical single-paragraph prose: leading/trailing
  whitespace is removed and every internal whitespace run (spaces, tabs,
  single newlines, and blank lines from `emit_definition`) becomes one ASCII
  space before both footnote storage and diagnostic publication. This keeps the
  managed Markdown footnote on one physical line and makes that persisted line
  the diagnostic's reconstructable source of truth.
- Review explanations are not persisted as Markdown footnotes. Their explicit
  newline boundaries remain semantic display boundaries; wrapping operates
  independently within each newline-delimited row and does not merge rows.
- Each display consumer wraps at render time using its own available width:
  - Parley's inline virtual-line renderer wraps review explanations to the
    current window's usable text-column width. Because extmarks are
    buffer-scoped, when the same buffer is visible in multiple windows the
    narrowest usable width among those windows is the shared safe width.
  - The centered definition float wraps definitions to its actual inner width
    and derives its height from the resulting display rows, so the whole message
    is visible without stale short lines or clipped soft-wrapped rows when the
    rows fit the parent window.
- The pure wrapper accepts canonical text, a positive display-cell width, and
  an injected display-width function. It greedily wraps at word boundaries,
  preserves explicit empty/newline-delimited rows, and splits an individual
  token when necessary so every emitted nonempty row is width-bounded. Production
  uses Neovim's display-width semantics, covering tabs and wide Unicode rather
  than Lua byte length.
- Width is remeasured and visible diagnostics are rerendered on initial display,
  cursor-driven refresh, window entry, and `WinResized`. Explicit option changes
  that alter gutters take effect on the next existing diagnostic refresh or
  cursor movement; no width is cached in the diagnostic record.
- Float width is measured before wrapping. Its content rows are the
  `Diagnostics:` header plus every wrapped diagnostic row, including preserved
  blank rows. Float height is the lesser of that row count and the available
  parent-window height after border space. If unusually long content exceeds
  the screen capacity, the buffer retains all rows while the float clips to the
  available height; ordinary concise definitions must show every row.
- Managed definition footnotes remain one logical Markdown definition line.
  Width-dependent line breaks are presentation only and are never written into
  the document.
- The pure wrapping helper remains the single implementation used by both
  renderers (`ARCH-DRY`, `ARCH-PURE`). The Neovim window measurement and buffer
  rendering stay in the thin diagnostic-display shell.
- This change introduces no external dependency or service seam
  (`ARCH-MOCK`). It covers every Parley consumer of the shared diagnostic
  message rather than fixing only the definition float (`ARCH-PURPOSE`). Neovim's
  built-in diagnostic float (`<C-W>d`) receives the same canonical unwrapped
  message and keeps using Neovim's own width-aware rendering.

## Done when

- A long definition generated in one window width is displayed with balanced
  wrapping in a differently sized diagnostic float.
- Narrower and wider diagnostic floats reflow from the same canonical message,
  and their height accounts for every rendered row.
- An already visible definition float and inline review display reflow after a
  window resize without requiring diagnostic recreation.
- Review virtual-line explanations remain width-bounded after diagnostic
  messages stop carrying creation-time hard breaks.
- Managed footnotes remain single physical Markdown lines; generated definition
  whitespace is canonicalized consistently for fresh and rehydrated diagnostics.
- Wide Unicode, tabs, and overlong tokens obey display-cell width bounds, and
  Neovim's built-in diagnostic float receives canonical unwrapped text.
- Focused unit/integration regressions, lint, and the full test suite pass.

## Plan

- [ ]

## Log

### 2026-08-18

- Root cause traced through `define.format_definition` →
  `skill_render.format_diagnostic_message` → `diag_display`: messages are
  hard-wrapped at diagnostic creation using the current editor width, then the
  float preserves those embedded newlines at its different width. Design keeps
  messages canonical and moves width-dependent wrapping to the renderers
  (`ARCH-DRY`, `ARCH-PURE`, `ARCH-PURPOSE`).

## Revisions

### 2026-08-18 — resolve first spec-review findings

- Defined generated definitions as canonical single-paragraph footnote text and
  distinguished them from newline-preserving review explanations.
- Defined wrapping in display cells, long-token splitting, multi-window width
  ownership, resize refresh triggers, float row/height accounting, overflow,
  and compatibility with Neovim's built-in diagnostic float.
