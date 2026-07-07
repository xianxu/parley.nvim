# Inline Term Definition

Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
concise, context-aware definition appears as an **ephemeral inline diagnostic**
(grey `virtual_lines`) under the phrase. The term is wrapped in a `[term]`
reference bracket + highlighted (review's `DiffChange`); the **definition text
is never written to the file**, only the brackets. The whole annotation is
**undoable** — `u` reverts the bracket and clears both decorations (see Undo
below). For jargon you don't know (e.g. `ASIN`), it's a one-keystroke lookup.
Added in [#161](../../workshop/issues/000161-inline-term-definition.md) (R1
added the bracket/highlight/undo).

## Flow

1. **`define_visual(buf)`** (`lua/parley/init.lua`) reads the visual selection
   (`getpos`), extracts the phrase (`define.slice_selection`), guards
   empty/whitespace, and computes a **bounded context** = the *enclosing
   exchange* of the selection (`define.context_for_selection` over `parse_chat`
   + `find_exchange_at_line`), falling back to the whole buffer.
2. It fires a headless **`define` skill** turn via `skill_invoke.invoke` with
   `opts.document = context`, `opts.no_reload = true`, and an `on_done`.
3. The `define` skill (`lua/parley/skills/define/init.lua`) is **unforced** (no
   `force_tool`) so the server-side `web_search` tool can run when the global
   `:ToggleWebSearch` is on; its `source(ctx)` folds the phrase into the system
   prompt and asks the model to call `emit_definition({term, definition})`.
4. **`render_definition`** (`on_done`), on a successful lookup: re-verifies the
   selection still holds the phrase (else skips — the buffer changed under the
   in-flight call), then **(a)** wraps the term in `[term]` via one
   `nvim_buf_set_lines` (`define.bracket_edit` plans it) — a single undo entry
   that anchors everything; **(b)** highlights the line(s) whole-line
   `DiffChange` (`skill_render.highlight_line`); **(c)** sets one INFO
   `vim.diagnostic` (`define.format_definition` → `skill_render.wrap`) on the
   `parley_skill` namespace; **(d)** records the undo/redo projection states.
   `diag_display`'s `virtual_lines{current_line=true}` reveals the diagnostic
   (cursor parked on the term's line). A no-`emit_definition` response leaves no
   bracket.

## Undo (`u`) — reuses review's projection

Native `u` reverts *text*, not decorations. The `[term]` bracket is the one
text change, so `u` reverts it; the decorations are cleared/restored by review's
**projection watcher** (`skills/review/projection.lua`, #133 M5), which define
reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
(pre-bracket hash → empty snapshot), `record(buf)` (bracketed hash → the
highlight + diagnostic), `ensure_watch(buf)`. Undoing the bracket lands on the
pre-bracket content-hash → the empty snapshot renders → both decorations clear;
`<C-r>` re-renders. The highlight must be **whole-line** because
`skill_render.snapshot`/`apply_snapshot` are line-granular. `set_applying`
brackets the edit so a prior define's watcher doesn't mistake it for a user edit.

## Pure core vs IO shell (ARCH-PURE)

- **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
  wrap as a set_lines edit).
- **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`.
- **External service** (Anthropic) exercised via the process-level fake reused
  from `skill_invoke_spec` (SSE tool-call injection).

## Keybinding

`<M-CR>` was split out of `chat_shortcut_respond` into its own `chat_define`
registry entry (a single registry entry maps every key×mode to one per-mode
callback, so the split can't live inside `chat_respond`). The `chat_define`
per-mode callback is `{ n=respond, i=respond, v=define_visual, x=define_visual }`
— visual `<M-CR>` defines; normal/insert `<M-CR>` still responds; visual
`<C-g><C-g>` keeps the line-scoped resubmit. The v/x callbacks `<Esc>`-commit
the `'<`/`'>` marks before reading `getpos`.

## Read-only invoke seam (`opts.no_reload`)

`skill_invoke.invoke` normally writes the buffer before the turn and `:edit!`-
reloads it after (for `propose_edits`). A read-only lookup passes
`opts.no_reload = true` to skip both, so an in-progress prompt is never
persisted. `opts.document` lets the caller send a bounded context instead of the
whole buffer. Both default to prior behavior when absent.

## Structured output tool

`emit_definition` (`lua/parley/tools/builtin/emit_definition.lua`, in
`BUILTIN_NAMES`) is an **output-only** tool: `{term, definition}` schema,
`self_paginates = true` (no pager params), no-op `handler`. The value rides the
tool-call args (`result.calls[1].input`), read in `on_done`.

## v1 limitations

- One definition visible at a time (`invoke` resets the `parley_skill` namespace
  each turn); line-granular highlight (whole-line, required for the projection
  round-trip). Dismissal is via `u` (R1) — reverting the bracket clears it; the
  diagnostic also auto-hides when the cursor leaves the line. The `[term]`
  brackets persist in the file if saved (the minimal-footprint tradeoff; the
  definition text never is). Shared `parley_skill` namespace/projection with
  review still applies (rare on chat buffers).

## Key files

- `lua/parley/define.lua` — pure core (slice / context / format).
- `lua/parley/init.lua` — `define_visual`, `render_definition`, `chat_define` wiring.
- `lua/parley/skills/define/init.lua` — the unforced `define` skill.
- `lua/parley/tools/builtin/emit_definition.lua` — output-only structured tool.
- `lua/parley/skill_invoke.lua` — `opts.no_reload` / `opts.document` seams.
- `lua/parley/config.lua`, `lua/parley/keybinding_registry.lua` — the `<M-CR>` split.
- `tests/unit/define_spec.lua`, `tests/integration/define_spec.lua` — coverage.

## Related

- [Drill-In Markers](drill_in.md) — the heavier "gather into the next turn"
  sibling; shares `define.slice_selection` for the visual-selection extraction.
- [Document Review](../modes/review.md) — the skill/`skill_invoke`/`diag_display`
  machinery this reuses.
