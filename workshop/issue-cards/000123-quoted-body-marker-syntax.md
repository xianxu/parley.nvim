---
id: '000123'
status: done
created: 2026-05-07
updated: 2026-05-09
actual_hours: 8.5
---

# 🤖 marker: add `<quoted text>` slot for precise drill-in / quoting

## Problem

The current marker syntax has an ambiguity. `🤖{X}` can mean two different
things depending on whether it was authored by drill-in (visual-mode
`<C-g>q` / `<M-q>`) or by a review skill / user-typed annotation:

- Drill-in writes `🤖{T}[Q]` where `{T}` is the **text being quoted** (the
  visual selection) and `[Q]` is the human's question about it.
- Review writes `🤖{A}` where `{A}` is the **agent's commentary** on the
  surrounding text (no explicit quote).

A reader (human or parser) can't distinguish "this `{...}` is the quoted
body" from "this `{...}` is an agent turn" without out-of-band context.
That ambiguity propagates into the chat-respond strip rule, which has to
infer intent from shape (`{T}[Q]` ≅ "drill-in"; `{A}` alone ≅ "annotation").

Fix: introduce a third bracket type `<...>` exclusively for the quoted
text, and use it everywhere a precise quote is meant. `[]` and `{}` keep
their existing meanings (human and agent turns, alternating in any order).
