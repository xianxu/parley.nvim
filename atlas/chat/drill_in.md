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
3. **Submit** — `<C-g>g` (chat respond) gathers all ready drill-ins buffer-wide, in document order, and:
   - Strips each marker in place back to plain `T` (transcript reads naturally).
   - Appends a blockquote-of-T followed by `Q` to the next user turn slot, separated from any user-typed text by exactly one blank line. Multiple drill-ins are stacked with one blank line between blocks.
4. **Resolve** — `<C-g>r` (normal mode) buffer-wide strips every `🤖{T}[..](..)*` to plain `T` ("resolve discussion chain"). Plain review markers (no `{T}` body) are left alone.

## Skipped paths

Drill-in pre-processing only fires on the *new turn* path of `chat_respond`. It is **not** triggered when:

- `params.range == 2` (explicit range respond).
- Cursor sits on an existing answer.
- Cursor sits on a past question that already has an answer (resubmit).

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
