# Drill-In Markers

Inline drill-in lets a user select text inside a chat transcript, wrap it as a marker `🤖<T>[Q]`, and have it resolved into a quote-and-question block prepended to the next user turn on the next chat-respond cycle.

The marker syntax is the same one the [review skill](../modes/review.md) uses on non-chat markdown. The parser is shared (`lua/parley/skills/review/init.lua` → `_parse_marker_sections`). Drill-in is the chat-buffer–side downstream of that syntax.

## Marker shape

```
🤖<T>[Q]            — drill-in: human picks T from earlier text, types Q
🤖<T>[Q]{A}[Q2]…    — discussion chain about T (alternating)
🤖[Q]               — bare human turn, no quoted body
🤖[Q1]{A1}[Q2]…     — chain without a quoted body
🤖{A}               — agent annotation, no quoted body, no human turn
🤖~D~               — proposed deletion of D
🤖~D~{N}            — proposed replacement of D with N (agent-authored)
🤖~D~[N]            — proposed replacement of D with N (human-authored)
```

- **Has quoted body** = `<T>` is present (the first slot, immediately after 🤖). Optional and at most one. Drill-in's resolve-chain command only touches markers with `<T>`.
- **Has strike** = `~D~` is present (same slot as `<T>` — mutually exclusive). Strike markers are *proposals* (deletion or replacement), not questions to the agent.
- **Ready** = last section is a non-empty `[]` (matches the review-skill ready definition). Markers ending in `{}` are *pending* and stay inline as agent annotations. Strike markers are *never* ready (even with trailing `[]`, since they're proposals not questions).

The chat-respond pipeline gathers every ready marker (with or without `<T>`) — the difference is in how the marker collapses inline (see Lifecycle step 3). Strike markers are skipped entirely.

See [#123](../../workshop/issues/000123-quoted-body-marker-syntax.md) for the rationale behind `<T>`. See [#124](../../workshop/issues/000124-review-convention-alignment.md) and the canonical [review-convention target](../../../ariadne/workshop/targets/review-convention.md) for the strike family and the broader convention parley.nvim implements.

Accept and reject for `~X~` and the full §5 table are wired via `<M-a>` / `<M-r>` (#124 M2 — see the keybinding table below).

## Lifecycle

1. **Create** — visual-mode `<C-g>q` (or `<M-q>`) wraps the selection as `🤖<T>[]` and drops the cursor inside the empty `[]` in insert mode.
2. **Compose** — user types the question (multi-line allowed).
3. **Submit** — `<C-g>g` (chat respond) processes ready markers. Two paths:

   - **Branch path** (cursor on a past exchange that contains ready markers): treats them as follow-up questions for that exchange. Strips them in place inside the exchange and **inserts a new user turn after that exchange's answer**, populated with the gathered quote+question blocks. The original Q/A is preserved (no resubmit). Pipeline `end_index` is capped at the inserted new turn, so subsequent (now stale) exchanges below stay in the buffer but are out of context for this turn.
   - **End-append path** (cursor on the unanswered last question or at end of buffer): gathers every ready marker buffer-wide and appends the gathered blocks to the next user turn slot at the end. Markers are stripped in place. If the user already typed text in the next turn, exactly one blank line separates the user's text from the first block. Multiple blocks are stacked with one blank line between them.

   Inline collapse rule for stripped markers:
   - Marker with `<T>` body → inline replaced by plain `T`.
   - Marker without `<T>` body → marker removed entirely (whitespace not normalized).

4. **Resolve** — `<M-a>` accepts the marker at cursor and `<M-r>` rejects it, per the §5 table. Bulk-resolve was dropped in #124 M2 — operators resolve markers one at a time, or ask an agent to walk the chains (agentic resolution, §6 of the canonical target).

## Resubmit interaction

Cursor on a past exchange (Q has an answer, or cursor on an answer) is normally a *resubmit* — old answer deleted and re-generated. Drill-in detection runs **before** resubmit handling: if the cursor's exchange contains ready markers, the branch path takes over and the resubmit path is skipped. The original answer is preserved.

If `params.range == 2` (explicit range), drill-in handling is skipped entirely; range request takes precedence.

## Quote block format

For a marker `🤖<T>[Q]`:

```
> T-line-1
> T-line-2
Q-line-1
Q-line-2
```

For a chain `🤖<T>[U1]{A1}[U2]`:

```
> T-line-1
> User: U1
> Agent: A1
U2
```

Continuation lines inside chain sections (multi-line `U1`/`A1`) stay inside the blockquote with `> ` (no per-line `User:`/`Agent:` prefix).

For a no-quote marker `🤖[Q]`, only `Q` is emitted (no leading `>` line). For a no-quote chain `🤖[U1]{A1}[U2]`, the chain lines are emitted without the leading `> T-…` block. Between adjacent gathered blocks, one blank line.

## Cross-tool consistency

Both parley and ariadne (`/fix` skill) parse this marker family identically. The on-disk shape is the canonical interchange format — there is no separate "drill-in" syntax.

## Key files

- `lua/parley/drill_in.lua` — pure-function module (`parse`, `gather_and_strip`, `resolve`, `accept_at`, `reject_at`, `format_block`, `format_blocks`, `wrap`, `append_blocks`).
- `lua/parley/chat_respond.lua` — pre-processing hook before message build (gates on resubmit detection).
- `lua/parley/init.lua` — `<M-q>` (insert), `<M-a>` (accept), `<M-r>` (reject) wiring inside `prep_chat` / `setup_markdown_keymaps`.
- `lua/parley/skills/review/init.lua` — shared section parser (`_parse_marker_sections`).
- `lua/parley/buffer_edit.lua` — `replace_all_lines` helper used to write the rewritten buffer in one shot.
- `tests/unit/drill_in_spec.lua` — unit specs for the pure module.
- `tests/integration/chat_respond_spec.lua` — integration specs for the chat-respond hook.

## Keybindings (parley_buffer scope, buffer-local)

The marker keymaps are wired into the shared `parley_buffer` scope so
they work in both chat buffers and plain markdown buffers (notes, issues,
parley files outside configured chat roots — anywhere `prep_md` runs).
Register-side: `M.prep_chat` and `M.setup_markdown_keymaps` both pass the
same `drill_in_callbacks(buf)` table to `register_buffer`.

| Binding              | Mode | Action                                               |
|----------------------|------|------------------------------------------------------|
| `<C-g>q` / `<M-q>`   | v/x  | Wrap selection as `🤖<T>[]`, cursor inside `[]` |
| `<C-g>q` / `<M-q>`   | i, n | Insert bare `🤖[]` at cursor, cursor inside `[]` |
| `<M-a>`              | n    | Accept the marker at cursor per review-convention §5 |
| `<M-r>`              | n    | Reject the marker at cursor per review-convention §5 |

Accept/reject semantics (the full table) live in the canonical [review-convention target](../../../ariadne/workshop/targets/review-convention.md) §5. In summary:

- `<X>` anchor → X preserved (both modes)
- `~D~` anchor → accept removes D (or splices in the first `{N}`/`[N]` after the strike); reject restores D
- Bare `🤖{R}` → accept splices R; reject removes the marker
- Everything else with no anchor (pure commentary chains) → empty (both modes)
