---
id: 000226
status: open
created: 2026-09-08
updated: 2026-09-08
estimate_hours:
github_issue:
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
