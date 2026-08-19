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
  width. Definition and review diagnostic records must retain only intentional
  paragraph breaks; no editor-width hard wrapping is stored in
  `diagnostic.message`.
- Each display consumer wraps at render time using its own available width:
  - Parley's inline virtual-line renderer wraps review explanations to the
    current text-column width.
  - The centered definition float wraps definitions to its actual inner width
    and derives its height from the resulting display rows, so the whole message
    is visible without stale short lines or clipped soft-wrapped rows.
- Managed definition footnotes remain one logical Markdown definition line.
  Width-dependent line breaks are presentation only and are never written into
  the document.
- Existing intentional newline/paragraph boundaries remain boundaries. Each
  paragraph reflows independently; display wrapping must not merge semantic
  paragraphs.
- The pure wrapping helper remains the single implementation used by both
  renderers (`ARCH-DRY`, `ARCH-PURE`). The Neovim window measurement and buffer
  rendering stay in the thin diagnostic-display shell.
- This change introduces no external dependency or service seam
  (`ARCH-MOCK`). It covers every Parley consumer of the shared diagnostic
  message rather than fixing only the definition float (`ARCH-PURPOSE`).

## Done when

- A long definition generated in one window width is displayed with balanced
  wrapping in a differently sized diagnostic float.
- Narrower and wider diagnostic floats reflow from the same canonical message,
  and their height accounts for every rendered row.
- Review virtual-line explanations remain width-bounded after diagnostic
  messages stop carrying creation-time hard breaks.
- Managed footnotes remain single logical Markdown lines and intentional
  paragraph boundaries remain intact.
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
