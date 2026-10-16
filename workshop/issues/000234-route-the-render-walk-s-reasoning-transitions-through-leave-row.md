---
id: 000234
status: working
deps: []
github_issue:
created: 2026-09-10
updated: 2026-10-16
estimate_hours:
card_mirror: 'b41dca02e8322b6e60b93823a2b18b778b1707d6' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T06:21:11-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "11cbd01d", done: "4dd4399e"}
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

## Core concepts

| Entity | Status | Where | What |
|---|---|---|---|
| `enter_row` | changed | lua/parley/highlight_structure.lua | Now exported: the PRE-snapshot half of a row's step (footer and partition resets). The redraw walk calls it per row. |
| `leave_row` | changed | lua/parley/highlight_structure.lua | Now exported: the row's own transition (`advance` plus reasoning: `🧠:[END]`, `🧠:` with its lookahead verdict, the blank terminator). The redraw walk calls it per row. |

## Plan

Read 2026-10-16:
- `lexical.advance` already owns the structural termination of reasoning (💬/🤖/🔒/🌿/📝/🔧/📎 clear `in_reasoning`), plus question, code and tool state.
- The render walk runs `advance` on a copy but keeps only code and tool from it. It then re-derives question and reasoning by hand: the structural-kind termination, `🧠:[END]` (which clears only `in_reasoning`, the drift the issue names), `🧠:` + lookahead, and the blank terminator.
- `chat_parser` is a parser, not a state walk. It scopes reasoning to the answer component and accumulates content.

- [x] `highlight_structure` exports `enter_row` and `leave_row` (the step `derive` already uses).
- [x] The render walk keeps ONE state table:
  - `enter_row` → the state it paints from (and reports through a test seam);
  - paint decisions read that state plus a post-`advance` copy (code, tool, reasoning after structural termination);
  - `leave_row` carries the state to the next row.
  Kept local as render-time inputs, not transition rules: painting, the `🧠:` `explicit` verdict (from the structure's lookahead, or `streaming`), and the streaming overlay.
- [x] Parity property test: over random documents (#227's vocabulary), the state the render walk paints each row from equals `build`'s `state_before`.
- [x] `chat_parser`: documented as intentionally different (answer-scoped reasoning and content accumulation), with a test pinning the difference: a `🧠:` outside an answer opens no parsed reasoning, but it does dim.
- [x] Every existing highlighter spec unchanged and green; doc-block placement scan.

## Log

### 2026-09-10

Filed from the #227 boundary review (BR-7, Minor, ARCH-DRY), deferred as a
separable render-path refactor.

### 2026-10-16 (parley.nvim:4)

- Built as planned. `compute_chat_highlights` holds one `state` table. `enter_row` gives the state it paints from (`M._observe_render_state` is the test seam). Painting reads that state plus a post-`advance` copy, and `leave_row` carries the next row. Deleted from the walk: the hand-written structural-kind termination, the `🧠:[END]` / `🧠:` / blank transitions (the `[END]` drift named in the Problem), and the question-state assignments.
- **The parity test found a real divergence on its first run.** The walk computed the `🧠:` lookahead verdict only inside its non-footer paint branch, so a `🧠:` row in the footer carried a stale `reasoning_explicit_end` into the next row. The verdict is a transition INPUT, so it is now taken for every `🧠:` row before painting.
- `tests/integration/render_walk_parity_spec.lua`, seed 234: 300 random documents, 3881 rows, 182 inside reasoning. The non-vacuity bound is 100; my first guess of 200 was above the measured count. Mutation: dropping the verdict fails it.
- `chat_parser`: documented as intentionally different (answer-scoped reasoning, accumulated as content). Pinned in `chat_parser_tools_spec`: a `🧠:` in a question is question text to the parser but dims in the highlight walk; in an answer both agree.
- The 30 highlight/render/parser-related specs are unchanged and green.
- Process slip: my plan message to the hub carried a commit hash I typed instead of reading it from `git rev-parse`; I sent a correction with the real one (69f44a95…).

