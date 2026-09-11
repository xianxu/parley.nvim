---
id: 000234
status: open
deps: []
github_issue:
created: 2026-09-10
updated: 2026-09-10
estimate_hours:
---

# Route the render walk's reasoning transitions through leave_row

## Problem

#227 lifted the structure build's per-row step into shared helpers
(`enter_row` / `leave_row` in `lua/parley/highlight_structure.lua`), so a splice
and a full build cannot disagree. The redraw walk in
`lua/parley/highlighter.lua` `compute_chat_highlights` still hand-writes its own
copy of the reasoning rules: structural-marker termination, `🧠:[END]`, `🧠:` +
lookahead, and the blank-line terminator. It shares only `advance` /
`reset_partition` (the #218 fence rule).

The copies already differ: the render walk's `🧠:[END]` branch clears
`in_reasoning` but not the explicit-end flag, which `leave_row` clears. That is
unobservable today, since the flag only matters inside a reasoning block, but it
is the same drift shape #218 fixed for the fence toggle. The next rule added to
one copy will silently miss the other. The #227 close review raised it as a
Minor ARCH-DRY finding (BR-7); it was deferred here because the render walk's
phases differ per field. Code and tool state advance *before* a row paints,
while question and reasoning state change *after*. Changing that is a render-path
refactor, not part of fixing the blank-while-typing bug.

## Spec

The render walk derives every state transition from `highlight_structure`'s
shared step functions and keeps only the *painting* decisions local, so there
is one definition of how a row changes question, code, reasoning and tool
state. Sweep for other copies at the same time (#227's lesson: fix the class):
`chat_parser`'s lenient reasoning termination is a candidate third one. Either
route it through the same helpers or record why its semantics must differ.

## Done when

- `compute_chat_highlights` computes state only through exported
  `highlight_structure` step functions; no reasoning transition is hand-written
  in `highlighter.lua`.
- A parity test drives the render walk and `build` over the same random
  documents, as #227's property test does for `replace`, and asserts that the
  state each paints from equals `state_before`.
- Every existing highlighting spec is unchanged and green.
- `chat_parser`'s reasoning termination is either on the shared helpers or
  documented as intentionally different, with a test pinning the difference.

## Plan

- [ ] Export the per-row step (or a painting-friendly split of it) from `highlight_structure`.
- [ ] Rewrite the render walk's state handling on it; keep painting local.
- [ ] Parity property test: render-walk state vs `state_before`.
- [ ] Sweep `chat_parser` (and any other reasoning walker) for the same rules.

## Log

### 2026-09-10

Filed from the #227 boundary review (BR-7, Minor, ARCH-DRY), deferred as a
separable render-path refactor.
