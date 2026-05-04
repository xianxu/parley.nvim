---
id: 000047
status: done
deps: []
created: 2026-04-01
updated: 2026-05-04
---

# allow multi-line thinking (🧠) blocks

## Problem

The chat system prompt forces the `🧠:` thinking line to be a single
plaintext line with no newlines (`lua/parley/defaults.lua:6`). Models
fight this constraint in two failure modes:

1. They compress reasoning into one comma-spliced sentence that is hard
   to read and not actually reflective.
2. They give up on the constraint and trail reasoning into the answer
   body, defeating the separation that 🧠: was meant to provide.

The original framing of this issue (#47) proposed a full structured
output schema with XML/JSON wrappers around `<reply>/<thinking>/
<answer>/<summary>`. That has been rejected — provider parity is bad
(Anthropic has no native JSON schema; tool-call workarounds conflict
with free-form answer; OpenAI/Gemini have it but Copilot/Ollama vary),
streaming partial JSON is painful, and the visible 🧠/📝/👂 markers
are part of the on-disk chat format and are wired into folds, finder,
exporter, highlights, and memory. Replacing them is a large migration
for marginal correctness gain.

The narrow form of the original concern is: **let thinking span
multiple lines.** That is what this issue now covers.

## Spec

### Format change

The thinking block opens with a line that starts with `🧠:` (unchanged
visible marker) and continues across as many lines as the model needs.
The block ends at the first **blank line**. The blank-line terminator
is already required by the system prompt today ("Leaving an empty line
between thinking line (🧠:), main answer, and summary line (📝:)") —
this issue extends the *interior* of the block from one line to many.

```
🧠: First line of reasoning.
Second line, more detail.
Third line, plan.

(blank line ends the block; what follows is the answer)
```

### Constraints

- The block always opens with a line whose first non-whitespace token
  is `🧠:`. Continuation lines have no prefix.
- Blank line is the only terminator. If the model emits two thinking
  paragraphs, the second paragraph is treated as answer content. (We
  accept this trade-off; it keeps the rule simple and the model can
  comfortably fit reasoning in one paragraph or compact bullets.)
- `📝:` and `👂:` remain single-line prefixed lines, unchanged.
- Inside the thinking block, `🔧:` / `📎:` / `📝:` / `👂:` lines are
  not interpreted as their usual constructs. The whole block is opaque
  text until the blank-line terminator.

### Storage and replay

`exchange.reasoning.content` becomes a multi-line string. All thinking
lines (the opener after the prefix, plus continuations) are also fed
into `content_parts` and `cb_append_line` so subsequent turns replay
the model's own prior reasoning — same behavior as today, just longer.

### Folding and highlight

`tool_folds.lua` currently folds a single `🧠:` line. Extend the fold
to cover the whole thinking block (open line + continuations, up to
but not including the terminating blank line). Highlight namespace
(`thinking` group, currently linked to `Comment`) applies to every
line in the block.

### System prompt revisions (`lua/parley/defaults.lua`)

- Line 6: replace "single plaintext line without any newline" with
  "thinking block, may span multiple lines, terminated by a blank line".
- Line 29: keep the blank-line-between-sections rule — it is now the
  load-bearing terminator.
- Line 37: keep the "always generate 🧠: at the beginning, 📝: at the
  end" rule.
- Re-read the whole prompt once and make sure no other clause
  contradicts the multi-line thinking allowance.

## Non-goals

- No XML/JSON schema. Plain-text prefix format stays.
- No change to `📝:` or `👂:` (still single line each).
- No change to providers, payload format, or streaming pipeline.
- No on-disk chat format change beyond allowing more lines in a region
  the parser already recognizes — old chats remain valid.
- Memory subsystem behavior unchanged (it consumes
  `exchange.reasoning.content`; the value just gets longer).

## Done when

- `lua/parley/defaults.lua` updated to permit multi-line thinking.
- `lua/parley/chat_parser.lua` parses thinking until blank line and
  stores the multi-line content in `exchange.reasoning.content`.
- `lua/parley/tool_folds.lua` folds the entire thinking block.
- Highlight applies to all thinking lines.
- Existing single-line thinking fixtures still parse identically.
- New fixtures cover: 2-line, 5-line, with markdown bullets in body.
- All existing tests pass; new tests added for multi-line cases.
- Manual: respond to a question, observe multi-line 🧠 in the buffer
  with a single fold and consistent highlight.

## Plan

- [x] Audit consumers of `current_exchange.reasoning` — content is
      a string passed through to memory and replay; multi-line is
      transparent.
- [x] Update `chat_parser.lua` reasoning branch to enter a multi-line
      accumulation mode, exit on blank line OR structural marker
      (📝/🔧/📎/💬/🤖/🌿/🔒). Lenient termination preserves
      backward compat with chats authored under the previous
      single-line convention.
- [x] Update `defaults.lua` system prompt: lines 6, 29, 37 revised to
      describe the multi-line block and blank-line terminator.
- [x] `tool_folds.lua` — no change needed; `🧠:` is not in `FOLDABLE`
      today, and the foldtext line-count math already handles
      multi-line if folding gets wired later.
- [x] Update `lua/parley/highlighter.lua` to track `in_reasoning_block`
      state in both the per-line loop and the bootstrap walk so
      continuation lines render with `ParleyThinking`.
- [x] Refresh `tests/fixtures/golden_payloads/*.json` — system prompt
      change shifted the embedded text. Added
      `scripts/refresh_goldens.lua` for future refreshes.
- [x] Add `parse_chat_spec.lua` cases: multi-line thinking with
      blank-line terminator, 📝 termination without blank, 🔧
      termination, single-line back-compat, indentation preservation.
- [x] Update atlas docs (`atlas/chat/format.md`, `atlas/chat/parsing.md`).

## Log

### 2026-04-01

Original framing — convert generation to use output schema with
`<reply><thinking><answer><summary>` wrappers.

### 2026-05-04

Follow-up: blank-line termination proved unreliable in practice — Claude
strongly prefers blank-line paragraph breaks inside reasoning, even when
the prompt forbids it. Two changes:

1. Prompt now teaches an explicit `🧠:[END]` closer with a fenced example
   (the `:` overload — literal prefix vs English colon — was disambiguated
   in the same revision).
2. Parser decides termination mode per-block via lookahead: if `🧠:[END]`
   appears before the next structural marker, blank lines inside the
   block are content and only `[END]` / structural markers terminate
   (explicit-end mode). Otherwise the first blank line terminates
   (legacy mode). Highlighter mirrors the same per-block decision.

Tests added for both `[END]` modes (in-block and stray); existing
blank-line and structural-marker tests still pass unchanged.

Highlighter regression fix (post-stream): the per-block-mode lookahead
was slice-based (`prefix_lines` for bootstrap, `lines` for main loop).
When the viewport top fell between `🧠:` and `🧠:[END]`, neither slice
contained both the opener and the terminator — so the lookahead
returned false → legacy mode → the model's blank-line paragraph break
inside the thinking region terminated dimming, and continuation lines
below the blank rendered in default color. Symptom: clicking a line
"fixed" it because the viewport shifted and the new lookahead horizon
happened to include `[END]`. Replaced with a buffer-aware lookahead
(`reasoning_block_has_end_marker(buf, from_line, patterns)`) capped at
500 lines that scans the live buffer regardless of viewport.

Highlighter fix (during-stream): `🧠:[END]` does not exist in the
buffer until the model emits it, so the lookahead can never find it
mid-stream. Fix: when `tasker.is_busy(buf)` reports an active stream
for the buffer, the highlighter optimistically assumes explicit-end
mode — blank-line paragraph breaks inside the in-progress reasoning
keep their dim highlight. After the stream completes, normal
lookahead resumes; legacy single-line `🧠:` chats (without `[END]`,
common in archives authored before this feature) are unaffected
because they're not streaming. Considered "drop legacy mode entirely"
as a simpler alternative but rejected: 8 of 9 chats in
`workshop/parley/` are legacy and would have their answer body
absorbed into reasoning until `📝:`, dimming the entire body.

Integration tests: `dims thinking-block continuation lines when
viewport top falls between 🧠: and 🧠:[END]` (post-stream); `dims
streaming thinking-block continuation lines before 🧠:[END] is
emitted` (during-stream, stubs `tasker.is_busy → true`).

Also fixed a pre-existing bug where multiple `🧠:` blocks in one answer
(plan → tool round → reflect → final answer) overwrote the first
block's content. Parser now appends subsequent block content to
`reasoning.content` separated by a blank line; `reasoning.line` stays
anchored to the first opener as the block-start reference. No
downstream consumer reads `.reasoning` outside the parser/tests, so
the shape contract is unchanged (still `{ line, content }` with content
as a string). New test:
`multiple 🧠: blocks within one answer accumulate into reasoning.content`.

### 2026-05-03

Re-scoped. Schema/XML approach rejected on provider parity, streaming
complexity, and on-disk format churn. Narrowed to multi-line thinking
only — the single concrete pain the structured form was trying to fix.
Spec, plan, and done-when rewritten accordingly.

Implementation landed:

- `lua/parley/chat_parser.lua` — `in_reasoning_block` state, opens on
  `🧠:`, closes on blank line OR structural marker. Lenient
  termination on 📝/🔧/📎 in addition to the canonical blank-line
  rule, for backward compat with existing single-line chats and
  defense against models that omit the terminator.
- `lua/parley/defaults.lua` — system prompt updated.
- `lua/parley/highlighter.lua` — `in_reasoning_block` mirrored in
  both the per-line loop and the bootstrap walk; continuation lines
  highlight as `ParleyThinking`.
- `tests/unit/parse_chat_spec.lua` — 5 new cases (multi-line +
  blank terminator, 📝 backward-compat termination, 🔧 termination,
  single-line preservation, indentation).
- `tests/fixtures/golden_payloads/*.json` regenerated; added
  `scripts/refresh_goldens.lua` helper.
- Atlas updated: `atlas/chat/format.md`, `atlas/chat/parsing.md`.

All tests pass (`make test`); lint clean (`make lint`).

One implementation note: I considered strict spec-only termination
(blank line is the *only* terminator). Rejected because the existing
test fixture in `chat_parser_tools_spec.lua:283` and almost certainly
many real saved chats lack the blank line between `🧠:` and the
following `📝:`. Strict mode would have absorbed `📝:` into reasoning.
Lenient termination on structural markers is more robust at no cost
to the well-formed case.
