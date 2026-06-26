---
id: 000141
status: done
deps: []
created: 2026-06-25
updated: 2026-06-25
started: 2026-06-25T18:34:47-07:00
estimate_hours: 1.5
actual_hours: 1.5
---

# better quoting support

we allow alt+q for user to directly quote in chat buffer and ask follow up questions. here are some improvements I want to make to that. some fresh: 🤖<quoted text>[question] is translated into next turn as question from user:

> quoted text
question

and the original quoted text is decorated as [quoted text] in original location. 

improvements:

1. add a newline between quoted text and question, and also use [quoted text]
> [quoted text]

question

2. allow the * search inside [] to match the whole string including []. this way, when user press * or # inside the anchor, they will jump likely to the referenced text.



## Done when

- The next-turn quote block reads `> [quoted text]`, a blank line, then the
  question (today: `> quoted text` immediately followed by the question).
- In a chat buffer, `*`/`#` (and `g*`/`g#`) with the cursor inside any `[...]`
  search the whole bracketed string, so the cursor on a `[quoted text]` jumps to
  its twin (the `[T]` reference bracket left at the source by #127). Outside any
  bracket, the builtin motion is unchanged.
- Full `make test` green for the change (`format_block`/`bracket_at` unit +
  `chat_respond_spec` integration); `parley_harness_golden` is a pre-existing
  failure unrelated to this change.

## Spec

Two improvements to the drill-in quote feature (`atlas/chat/drill_in.md`):

1. **Format** — `drill_in.format_block` wraps the quoted body in `[…]` (`[` on
   the first quoted line, `]` on the last) and emits a blank line before the
   final (unprefixed) prompt. This makes the next-turn quote match the `[T]`
   reference bracket #127 already leaves at the source, which is what part 2
   jumps between. Pure function → unit-tested; `format_blocks`/`append_blocks`
   cascade (their expectations updated).

2. **`*`/`#` over `[...]`** — net-new (no prior `*`/`#` customization). Pure
   `drill_in.bracket_at(line, col)` returns the `[…]` pair covering the cursor;
   buffer-local `*`/`#`/`g*`/`g#` maps in `prep_chat` (chat buffers only — the
   operator's chosen scope) set the search register to the escaped literal
   (`\V[…]`) and jump (fwd / back); the user's own `hlsearch` governs highlight
   (not forced). Outside a bracket they fall through to the builtin via
   `normal!`. Not a configurable shortcut, so wired
   directly rather than through the keybinding registry.

## Plan

- [x] `format_block`: bracket the quoted body + blank line before the prompt.
- [x] Pure `bracket_at(line, col)` + unit tests.
- [x] Chat-buffer `*`/`#`/`g*`/`g#` maps in `prep_chat` (fall through outside `[]`).
- [x] Update `format_block`/`format_blocks`/`append_blocks` specs to the new layout.
- [x] Update `atlas/chat/drill_in.md` (format + the `*`/`#` anchor jump).
- [x] Verify: full `make test` (drill_in 108/108, chat_respond 29/29) + runtime
  jump glue + keymap path (`parley_harness_golden` 7/7 is pre-existing).

## Revisions

### 2026-06-25 — boundary review (REWORK) addressed
- Part 1's format change also broke two integration assertions in
  `tests/integration/chat_respond_spec.lua` (`> RedShift…` / `> Term…`) — not in
  the original Plan's test-update list. Updated both to `> [X]` + blank +
  question; they now also pin the inline-`[X]` ↔ block-`[X]` twin invariant.
- Dropped the forced global `hlsearch = true` in `bracket_jump` (it mutated user
  config and diverged from the fall-through path); the user's setting governs.
- The first close's "drill_in_spec green" understated the §5 gate (unit only).
  Re-verified with the full `make test`; this surfaced `parley_harness_golden`
  failing 7/7, confirmed **pre-existing** (fails identically on clean `main`),
  unrelated to #141.
- Documented the single-line `bracket_at` boundary in `atlas/chat/drill_in.md`.

## Log

### 2026-06-25
- 2026-06-25: closed — Re-close after addressing boundary REWORK. Full make test: drill_in_spec 108/108, chat_respond_spec 29/29 (the 2 flagged assertions fixed → now pin the [X] twin invariant). parley_harness_golden 7/7 fails PRE-EXISTING (confirmed identical on a clean main worktree, outside the #141 window). Dropped the forced global hlsearch (Important). Atlas: single-line bracket_at boundary documented. luacheck clean. Interactive * in a live chat for operator confirmation. Actual labeled — active-time found no measurable window.; review verdict: SHIP

- Implemented both parts. Part 1 in `drill_in.format_block` (pure); part 2 =
  pure `bracket_at` + buffer-local `*`/`#`/`g*`/`g#` in `prep_chat`.
- Verified: `drill_in_spec` 108/108 (incl. new `format_block`/`bracket_at` cases
  + cascaded `append_blocks`/`format_blocks` expectations), luacheck clean.
  Headless: the search glue jumps to the matching `[…]` and sets `@/=\V[…]`.
  Keymap install confirmed by-construction — `prep_chat` sets my maps on the same
  path as the existing `<M-q>` map (both absent in lockstep when `prep_chat`
  early-returns on a non-chat buffer); end-to-end `*` in a live chat is for
  operator confirmation.

