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

Written to the open Spec: the first row is the decision, and the rest follow
from it. Not costed yet — `sdlc change-code` derives the estimate once the
supersede-vs-queue question is settled.

- [ ] Decide supersede vs queue vs drop for a second press, and record the
      choice in the Spec with its reason. A second press on the SAME ref is a
      no-op; on a DIFFERENT ref it is a change of mind and should win
- [ ] Add the in-flight record to `artifact_ref` — keyed per the decision
      above — and make `goto_ref_at_cursor` consult it before spawning
- [ ] Staleness check at dispatch: drop the result if the buffer/cursor the
      resolve started from is gone. This is the cheaper half and fixes the
      "yanked the window" symptom even without cancellation
- [ ] Kill the outstanding `vim.system` handle when a press supersedes, if the
      decision says supersede
- [ ] Tests through the `runner` seam (`goto_ref_at_cursor(opts.runner)`,
      threaded in #225): two rapid presses on one ref → one spawn, one open;
      two presses on different refs → the second wins; a result landing after
      the origin buffer is gone → no navigation
- [ ] Atlas: `context/artifact_refs.md` gains the in-flight rule

## Log

### 2026-09-08

Filed out of #225's close review rather than folded into it — the key move
(`<M-o>`) is what made a pre-existing looseness matter, but fixing it properly
needs the supersede-vs-queue decision above.
