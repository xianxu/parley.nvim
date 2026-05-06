# Drill-In Markers

Inline drill-in lets a user select text inside a chat transcript, wrap it as a marker `🤖{T}[Q]`, and have it resolved into a quote-and-question block prepended to the next user turn on the next chat-respond cycle.

The marker syntax is the same one the [review skill](../modes/review.md) uses on non-chat markdown. The parser is shared (`lua/parley/skills/review/init.lua` → `_parse_marker_sections`). Drill-in is the chat-buffer–side downstream of that syntax.

## Marker shape

```
🤖{T}[Q]            — drill-in: human picks T from earlier text, types Q
🤖{T}[Q]{A}[Q2]…    — discussion chain on T (alternating)
🤖[only Q]          — plain review marker (no quoted body) — drill-in ignores this
```

- **Has quoted body** = first section is a non-empty `{T}`. Drill-in operates only on these.
- **Ready** = last section is a non-empty `[]` (matches the existing review-skill ready definition).

Drill-in's "needs machine attention" criterion is exactly `marker.ready and marker.has_quoted_body`.

## Lifecycle

1. **Create** — visual-mode `<C-g>q` wraps the selection as `🤖{T}[]` and drops the cursor inside the empty `[]` in insert mode.
2. **Compose** — user types the question (multi-line allowed).
3. **Submit** — `<C-g>g` (chat respond) processes drill-ins. Two paths:

   - **Branch path** (cursor on a past exchange that contains ready drill-ins): treats the drill-ins as a follow-up question for that exchange. Strips them in place inside the exchange and **inserts a new user turn after that exchange's answer**, populated with the gathered `> T` / `Q` blocks. The original Q/A is preserved (no resubmit). Pipeline `end_index` is capped at the inserted new turn, so subsequent (now stale) exchanges below stay in the buffer but are out of context for this turn.
   - **End-append path** (cursor on the unanswered last question or at end of buffer): gathers every ready drill-in buffer-wide and appends the `> T` / `Q` blocks to the next user turn slot at the end. Markers are stripped in place. If the user already typed text in the next turn, exactly one blank line separates the user's text from the first block. Multiple blocks are stacked with one blank line between them.

4. **Resolve** — `<C-g>r` (normal mode) buffer-wide strips every `🤖{T}[..](..)*` to plain `T` ("resolve discussion chain"). Plain review markers (no `{T}` body) are left alone.

## Resubmit interaction

Cursor on a past exchange (Q has an answer, or cursor on an answer) is normally a *resubmit* — old answer deleted and re-generated. Drill-in detection runs **before** resubmit handling: if the cursor's exchange contains ready drill-in markers, the branch path takes over and the resubmit path is skipped. The original answer is preserved.

If `params.range == 2` (explicit range), drill-in handling is skipped entirely; range request takes precedence.

## Quote block format

```
> T-line-1
> T-line-2
Q-line-1
Q-line-2
```

Multi-line `T` becomes multiple `> ` lines. Multi-line `Q` is preserved verbatim. Between adjacent gathered blocks, one blank line.

## Cross-tool consistency

Both parley and ariadne (`/fix` skill) parse this marker family identically. The on-disk shape is the canonical interchange format — there is no separate "drill-in" syntax.

## Key files

- `lua/parley/drill_in.lua` — pure-function module (`parse`, `gather_and_strip`, `resolve_all`, `format_block`, `format_blocks`, `wrap`, `append_blocks`).
- `lua/parley/chat_respond.lua` — pre-processing hook before message build (gates on resubmit detection).
- `lua/parley/init.lua` — `<C-g>q` (visual) and `<C-g>r` (normal) wiring inside `prep_chat`.
- `lua/parley/skills/review/init.lua` — shared section parser (`_parse_marker_sections`).
- `lua/parley/buffer_edit.lua` — `replace_all_lines` helper used to write the rewritten buffer in one shot.
- `tests/unit/drill_in_spec.lua` — unit specs for the pure module.
- `tests/integration/chat_respond_spec.lua` — integration specs for the chat-respond hook.

## Keybindings (chat scope, buffer-local)

| Binding   | Mode | Action                                               |
|-----------|------|------------------------------------------------------|
| `<C-g>q`  | v/x  | Wrap selection as `🤖{T}[]`, cursor inside `[]`     |
| `<C-g>r`  | n    | Resolve discussion chain: strip every `🤖{T}[..]..` to `T` |

The `<C-g>r` slot was previously bound to `chat_toggle_raw_request` (and `<C-g>R` to `chat_toggle_raw_response`); both were removed. The underlying `:ToggleRawRequest` / `:ToggleRawResponse` commands stay reachable.
