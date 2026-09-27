---
id: '000124'
status: done
created: 2026-05-23
updated: 2026-05-24
actual_hours: 10
---

# Align marker grammar and bindings with review-convention target

## Problem

The canonical review-convention spec now lives at
`../ariadne/workshop/targets/review-convention.md`. Parley.nvim is the
human-side marking surface for that convention but its current
implementation diverges in three places:

1. **No `~X~` family.** The spec defines `🤖~D~`, `🤖~D~{N}`, `🤖~D~[N]` for
   deletion / replacement. Parser, drill_in, and highlighter have no
   notion of strikethrough markers today.

2. **No accept/reject split.** Spec §5 distinguishes `<M-a>` (accept) from
   `<M-r>` (reject) with a 10-row resolution table where the two gestures
   have asymmetric outcomes for the `~D~` family. Today's `<M-r>` is a
   single bulk "accept-ish resolve" — no reject path, no per-marker
   accept.

3. **Inconsistent `<M-q>` insertion.** Drill-in produces `🤖<sel>[]`
   (empty `[]`). The review skill's separate `<C-g>vi` produces
   `🤖[selected]` (no `<>` ref, selection inside `[]`). Spec wants one
   canonical form: `🤖<sel>[ ]` on selection, `🤖[ ]` without.

Per operator direction (this session): no backwards-compatibility for the
`<M-r>` semantic shift; bulk-resolve gets dropped entirely; redundant
review-skill insertion bindings (`<C-g>vi`, `<C-g>vr`) get retired in
favor of `<M-q>` as the single insertion path.
