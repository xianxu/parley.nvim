---
id: 000234
status: open
created: 2026-09-10
updated: 2026-09-10
estimate_hours:
github_issue:
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
