---
id: 000298
status: working
deps: []
github_issue:
created: 2026-09-28
updated: 2026-09-28
estimate_hours:
card_mirror: '523eab2eb98860887ee54b4991e8ec183480b3be' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-28T21:04:00-07:00
---

# Preserve empty tool input objects

## Problem

After `./parley_app --nuke` then `--demo`, the first question invokes
`parley_help` successfully but its continuation fails HTTP 400:
`messages.3.content.0.tool_use.input: Input should be an object`.

## Spec

Preserve an empty JSON object when the Anthropic stream completes a tool call
without argument deltas. The decoder currently creates a plain Lua table,
which encodes as `[]`; explicit `{}` deltas retain their object metatable.
Fix the decoder's default rather than adding another downstream coercion
(ARCH-DRY, ARCH-PURE). Keep nonempty arguments and nested arrays unchanged.
This is a bounded representation fix: no new IO, state transitions, durable
artifacts, or resource budgets (ARCH-ORDER, ARCH-FUNERAL, ARCH-CONSTRAINTS).
The existing fallback behavior for malformed JSON is retained; it produces an
empty object, not an array (ARCH-SECURE). No new abstraction is needed.

## Done when

- A no-argument Anthropic tool call encodes its input as `{}` with absent,
  empty, or explicit `{}` argument deltas.
- The production tool-round continuation and transcript replay both preserve
  that object representation; nonempty inputs keep nested object/array types.
- Provider tool-use regression tests and lint pass.

## Plan

- [ ] Reproduce the wrong JSON type in decoder and production round tests.
- [ ] Correct the decoder default and run provider tool-use tests and lint.
- [ ] Record boundary review and close.

## Log

### 2026-09-28

- Neovim confirms `vim.json.encode({})` is `[]`, while decoded `{}` and
  `vim.empty_dict()` survive `vim.deepcopy` as `{}`. Replay already coerces
  empty input; the frozen continuation correctly copies what the decoder emits.
