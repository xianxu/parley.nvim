---
id: '000160'
status: done
started: 2026-07-03T23:39:29-07:00
created: 2026-07-03
updated: 2026-07-05
estimate_hours: 1.8
actual_hours: 2.0
---

# navigate ariadne artifact references

## Problem

ariadne artifacts (issues, plans, review sidecars, targets) refer to each other
and across peer repos with **symbolic** refs — `ariadne#11`, `#15 M4`, `pair#84` —
but there's no fast way for a human in the editor to *jump* from a ref to the file
it names, especially across sibling repos. Navigation is manual (grep, guess the
path, `:e`).

This grew from **ariadne#144**, which originally framed the fix as files carrying
**stored cross-links** (e.g. `[ariadne#11](../ariadne/workshop/issues/000011-…md)`).
We rejected that premise: the issue *number* is immutable but the *path* is not —
slugs get renamed, and files move `issues/ → history/` on close/merge (ariadne#160
made that move happen on every merge). Stored links rot on archive. The fix is
**read-time resolution**.

The feature splits across two repos: **ariadne#144** is the resolver (`sdlc
resolve`, base-layer Go — reframed off the stored-link premise); **this issue** is
the parley editor UX that consumes it. `deps: [ariadne#144]`.
