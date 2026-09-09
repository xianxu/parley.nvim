---
id: 000226
status: open
deps: []
github_issue:
created: 2026-09-08
updated: 2026-09-08
estimate_hours:
---

# Guard the sdlc resolve spawn behind an in-flight check

## Problem

`artifact_ref.goto_ref_at_cursor` shells to `sdlc resolve --json` with no
in-flight guard and no cancellation. Two presses before the first returns start
two subprocesses; both complete, both `vim.schedule` a dispatch, and you get two
`open_buf` calls or two family pickers.

This has always been true of `gf` (`resolve_ref_gf`), where it was tolerable
because `gf` on a ref is occasional. #225 put the same path behind **`<M-o>`**,
the key the operator presses most while navigating a forked transcript, which is
exactly the usage that produces a double-press. Raised as a Minor in #225's
close review and deliberately not folded in: cancellation semantics are a design
question, not a keybinding fix.

There is a second, related extent (#225 review, ARCH-ORDER): nothing cancels the
`run_resolve` → `vim.schedule` → `open_buf` chain if the user leaves the buffer
mid-flight, so a slow resolve can yank the window out from under whatever they
moved to.

## Spec

Open. The shape to decide:

- **Dedup key** — per (ref, buffer)? per invocation? A second press on the *same*
  ref is a no-op; a second press on a *different* ref is a legitimate change of
  mind and should supersede, not queue.
- **Cancellation** — `vim.system` returns a handle with `kill`. Superseding could
  kill the outstanding one rather than letting it land.
- **Staleness** — even without cancellation, the dispatch could check that the
  cursor/buffer is still where the resolve started and drop the result if not.
  Cheaper than cancellation and fixes the "yanked the window" half.

## Done when

- Two rapid `<M-o>` presses on the same ref produce one spawn and one open
- A resolve that lands after the user has moved away does not steal the window
- Asserted through the `runner` seam (`goto_ref_at_cursor(opts.runner)`, threaded
  in #225) rather than by spawning `sdlc`

## Plan

- [ ]

## Log

### 2026-09-08

Filed out of #225's close review rather than folded into it — the key move
(`<M-o>`) is what made a pre-existing looseness matter, but fixing it properly
needs the supersede-vs-queue decision above.
