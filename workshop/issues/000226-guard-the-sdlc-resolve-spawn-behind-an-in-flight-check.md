---
id: 000226
status: working
deps: []
github_issue:
created: 2026-09-08
updated: 2026-10-16
estimate_hours:
card_mirror: 'bf27426d92c7486f9c5ec276b96affd33c38ee31' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T00:18:48-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "20fd8599", done: "22a8182e"}
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

Since filing, #327 added `opts.is_current`: a caller-owned validity check that
drops a stale scheduled result or picker selection and consumes each callback
once. Only the reference-navigation fallback passes it, so `gf` and the project
jump (`ResolveRefProject`) still have neither staleness nor in-flight dedup.

Decision: the second press supersedes; it is never queued.
- **Key:** the ref, the resolve kind and the repo cwd, which together name the
  question asked of `sdlc`. A press with the SAME key while one is in flight is a
  no-op that says `parley: still resolving <ref>`, because a second spawn would
  only answer the same question twice. A press with a DIFFERENT key is a change
  of mind: it kills the outstanding process and marks it superseded, so its
  completion is dropped even if it already exited.
- **Staleness, by default:** the resolve records its origin buffer and window.
  The result is dispatched (and a picker selection opened) only while the user
  is still there and the resolve is still the latest. A caller's
  `opts.is_current` narrows this further and never widens it.
- **No timeout:** `sdlc` may rebuild itself on a call, so a slow resolve is
  legitimate. The record clears when the process exits; a different ref still
  supersedes a hung one.

## Core concepts

| Concept | Meaning |
|---|---|
| `inflight` | the one outstanding resolve: its key, process handle and token |
| `_reset_inflight` | test seam: forget the outstanding resolve |

## Done when

- [x] Two rapid presses on the same ref produce one spawn and one open.
- [x] A press on a different ref kills the outstanding resolve, and only the second result dispatches.
- [x] A resolve that lands after the user moved to another buffer or window does not navigate, with no `is_current` from the caller.
- [x] Asserted through the `runner` seam (`goto_ref_at_cursor(opts.runner)`), never by spawning `sdlc`.

## Plan

- [x] `run_resolve` returns the runner's handle (vim.system's), so a superseding press can kill it.
- [x] `goto_ref_at_cursor`: an in-flight record keyed on the ref, kind and cwd; a same-key no-op with a notice; a different key supersedes; the default origin check is combined with `opts.is_current`.
- [x] Red-first tests through the runner seam: same ref twice gives one spawn and one open; a different ref kills the first, and the first's late completion is dropped; leaving the buffer drops the result; the record clears on completion, so a later press spawns again.
- [x] Atlas: `context/artifact_refs.md` gains the in-flight rule.

## Log

### 2026-09-08

Filed out of #225's close review rather than folded into it — the key move
(`<M-o>`) is what made a pre-existing looseness matter, but fixing it properly
needs the supersede-vs-queue decision above.

### 2026-10-16

- Taken by parley.nvim:3. The Spec's open questions are now decided (see Revisions). #327's `opts.is_current` already covers the
  caller-owned half, so this issue adds the in-flight record and the default
  origin check that `gf` and the project jump lack.

- Red first: 4 of the 6 new runner-seam cases failed on main's code (same ref twice, supersede, left the buffer, left the window). The
  other two (forget on finish, key on kind) guard the new record. Green: 38/38,
  luacheck clean.
- Added in review of my own diff: a spawn that raises releases the key, or
  every later press on that ref would say "still resolving". A mutation
  dropping the release fails the new case.

## Revisions

- 2026-10-16: the open Spec and the undecided Plan are replaced by the decision
  (supersede, never queue; same key is a no-op with a notice; default origin
  staleness; no timeout) and the Plan that follows from it.
