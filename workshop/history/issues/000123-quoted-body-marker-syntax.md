---
id: 000123
status: done
deps: []
created: 2026-05-07
updated: 2026-05-09
actual_hours: 8.5
---

# 🤖 marker: add `<quoted text>` slot for precise drill-in / quoting

The current marker syntax has an ambiguity. `🤖{X}` can mean two different
things depending on whether it was authored by drill-in (visual-mode
`<C-g>q` / `<M-q>`) or by a review skill / user-typed annotation:

- Drill-in writes `🤖{T}[Q]` where `{T}` is the **text being quoted** (the
  visual selection) and `[Q]` is the human's question about it.
- Review writes `🤖{A}` where `{A}` is the **agent's commentary** on the
  surrounding text (no explicit quote).

A reader (human or parser) can't distinguish "this `{...}` is the quoted
body" from "this `{...}` is an agent turn" without out-of-band context.
That ambiguity propagates into the chat-respond strip rule, which has to
infer intent from shape (`{T}[Q]` ≅ "drill-in"; `{A}` alone ≅ "annotation").

Fix: introduce a third bracket type `<...>` exclusively for the quoted
text, and use it everywhere a precise quote is meant. `[]` and `{}` keep
their existing meanings (human and agent turns, alternating in any order).

## Done when

- All four marker shapes parse and behave as specified below.
- Visual-mode drill-in keymap (`<C-g>q` / `<M-q>`) wraps selections as
  `🤖<T>[]` (was `🤖{T}[]`) and drops cursor inside the empty `[]`.
- Chat-respond gather-and-strip rule (used by `:ParleyChatRespond`) handles
  the new shapes per the strip rules below; markers without a final
  non-empty `[U]` are left inline.
- `<C-g>r` (resolve drill-in chain) strips any marker with `<T>` body back
  to plain `T`, regardless of chain state.
- Highlighter renders `<T>` segments distinctly from `[]` / `{}`.
- All existing markers in the wild (`🤖[U]`, `🤖{A}`, `🤖[U]{A}[U]…`) keep
  working unchanged. No migration required.
- Old in-the-wild `🤖{T}[Q]` (drill-in form pre-change) is no longer treated
  as drill-in: it parses as plain review syntax (`{T}` = agent turn,
  `[Q]` = human turn). This is a deliberate cutover; the previous
  drill-in shape is rare and only lives in active chat buffers.
- Tests cover all four shapes plus chain replay (with and without `<>`).
- `lua/parley/skills/review/SKILL.md` is updated so the review agent
  knows about `<...>`.
- Atlas entry mentioning marker grammar updated.

## Spec

### Marker grammar

```
marker      ::= 🤖 quoted? section*
quoted      ::= "<" TEXT ">"
section     ::= human | agent
human       ::= "[" TEXT "]"
agent       ::= "{" TEXT "}"
```

- `<...>` is **optional and at most one**, only as the first slot
  immediately after 🤖. If present, its content is the *quoted body* —
  the specific text the marker refers to.
- After the optional `<>`, any number of `[]` and `{}` sections in any
  order (no required alternation; matches today's review behavior).
- TEXT can span multiple lines and supports nested matching brackets of
  the same kind (existing `find_matching_bracket` semantics extended to
  `<>`).

### Marker shape semantics (chat-respond)

Let "ready" mean: the marker's last section is a non-empty `[U]`.

| Shape                       | On chat-respond                                                  | Inline after            |
|-----------------------------|------------------------------------------------------------------|-------------------------|
| `🤖{A}`                      | keep inline (annotation only)                                    | unchanged               |
| `🤖[U]`                      | strip; gather as `U` (bare, no quote prefix)                     | marker removed entirely |
| `🤖<Q>[U]`                   | strip; gather as `> Q` / `U`                                     | replaced by plain `Q`   |
| `🤖<>{A}` / `🤖<Q>{A}`        | keep inline (no human turn yet)                                  | unchanged               |
| `🤖[U1]{A1}[U2]` (chain)     | strip; gather as `> User: U1` / `> Agent: A1` / `U2`             | marker removed entirely |
| `🤖<Q>[U1]{A1}[U2]` (chain)  | strip; gather as `> Q` / `> User: U1` / `> Agent: A1` / `U2`     | replaced by plain `Q`   |

A marker is processed iff its **last section is a non-empty `[]`**.
Markers ending in `{}` (empty or non-empty) stay inline.

No surrounding-text heuristic: when a ready marker has no `<Q>` body,
the gathered block has no `>` quote line for the surrounding context.
Only the chain (if any) and the final user turn are sent.

### Resolve-drill-in (`<C-g>r`)

Strips every marker that has a `<T>` body back to plain `T`, regardless
of ready / pending / chain state. Markers without `<T>` are left alone
(they're plain review markers / annotations, not drill-ins).

### Highlighter

Three section types now: `<...>`, `[...]`, `{...}`. Each gets a
distinguishable highlight. Suggested colors:

- `<>` — quoted body, treat like a soft blockquote color (similar to `>`).
- `[]` — human turn (existing color).
- `{}` — agent turn (existing color).

### Backward compatibility

- Pre-change drill-in markers `🤖{T}[Q]` in active buffers will now be
  parsed as plain review syntax: `{T}` = agent turn, `[Q]` = ready human
  turn. Chat-respond will strip these as just `Q` (no quote prefix),
  losing `T`. This is intentional — affected markers are short-lived,
  only present in current open chats. No migration script.
- All other existing forms (`🤖[U]`, `🤖{A}`, chains without `<>`) keep
  identical parser behavior, **but** `🤖[U]` and `🤖[U1]{A1}[U2]` are
  now stripped on chat-respond (today they're left inline as review
  markers). Capture in the change log: review-only annotations should
  use `🤖{A}` (kept inline). Markers ending in `[]` are sent.

## Plan

### M1 — Parser support for `<>`

- Extend `parse_marker_sections` in `lua/parley/skills/review/init.lua`
  to recognize `<` as a third opener at the *first* slot only, producing
  a `quoted` section: `{ type = "quoted", text = ..., byte_start, byte_end }`.
- After consuming an optional `<>`, the existing `[`/`{` loop runs
  unchanged.
- Add `marker.quoted` convenience field on parsed markers (nil if absent).
- Tests: `tests/unit/review_spec.lua` — add cases for `🤖<Q>[U]`,
  `🤖<Q>[U]{A}`, `🤖<>[U]`, `🤖<>` (no sections), `🤖<Q>` (no sections),
  rejection of `<>` after `[]`/`{}`.

### M2 — Drill-in `wrap` and parse update

- `lua/parley/drill_in.lua`:
  - `wrap(text)` → `🤖<text>[]`.
  - `parse(text)` reads `has_quoted_body` from `marker.quoted ~= nil`
    instead of `sections[1].type == "agent"`.
  - `gather_and_strip` and `resolve_all` use `marker.quoted.text` instead
    of `sections[1].text`.
- Update tests in `tests/unit/drill_in_spec.lua` to use the new syntax
  end-to-end.
- Update `lua/parley/init.lua` cursor-placement logic for `wrap()` —
  cursor still lands inside the trailing `[]`. Verify byte offsets
  (`<>` adds 2 chars vs `{}` 2 chars — same length, no offset change).

### M3 — Chain gather format

- New helper `format_chain_block(quoted_or_nil, sections)` in
  `drill_in.lua` that renders:
  - If `quoted` present: first line is `> Q`.
  - For each section pair after the first `[]`, emit
    `> User: ...` / `> Agent: ...` lines (in document order).
  - Last user turn (the "ready" `[]`) emitted unprefixed at the end.
  - No surrounding-text fallback when `quoted` is absent — the gathered
    block omits the leading `>` line entirely.
- `gather_and_strip` keeps its current signature `(text) -> blocks, new_text`
  since no buffer-line context is needed any more.
- Tests: simple shapes (`<Q>[U]`, `[U]`), chains with and without `<>`,
  pending markers untouched, multiple markers in document order.

### M4 — Highlighter

- `lua/parley/highlighter.lua` — extend the marker highlight pass to
  handle `<...>` as a third span type. Pick a highlight group (start
  with `Comment`-ish or reuse an existing blockquote group; iterate).
- Test: `tests/integration/highlighting_spec.lua` covers `<>` span.

### M5 — Review SKILL.md, atlas, comments

- `lua/parley/skills/review/SKILL.md` — describe the four marker shapes,
  with the explicit note: `<>` = quoted text, `[]` = human turn,
  `{}` = agent turn.
- `lua/parley/keybinding_registry.lua` — update `desc` strings for
  `chat_drill_in` and `chat_resolve_drill_in`.
- `lua/parley/init.lua`, `lua/parley/chat_respond.lua` — comment refresh.
- Atlas: update whichever atlas file documents marker grammar (will scan
  during M5).

### M6 — Verification

- `make test` green.
- Manual: open a chat, select text, hit `<C-g>q`, type a question,
  `<C-g><C-g>` (chat respond), confirm `> Q` + question reaches the
  agent and the inline marker collapses to `Q`.
- Manual: type `🤖[U]` standalone, hit chat respond, confirm `U` is sent
  bare (no `>` quote prefix) and the inline marker is removed.
- Manual: type a chain `🤖<Q>[U1]{A1}[U2]`, hit chat respond, confirm
  chain-replay format.
- Manual: type `🤖{A}`, hit chat respond, confirm it stays inline.

## Log


- 2026-05-09: closed — user manually tested all 4 marker shapes (🤖<Q>[U], 🤖[U], 🤖{A}, chain) end-to-end
(empty — to be filled during implementation)
