# Inline Term Definition

Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
concise, context-aware definition appears as an **ephemeral inline diagnostic**
(grey `virtual_lines`) under the phrase — nothing is written to the chat file.
For jargon you don't know (e.g. `ASIN`), it's a one-keystroke lookup that keeps
the transcript clean. Added in [#161](../../workshop/issues/000161-inline-term-definition.md).

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
4. **`render_definition`** (`on_done`) reads `result.calls[1].input`, formats
   it (`define.format_definition` → `skill_render.wrap`), and sets one INFO
   `vim.diagnostic` on the shared `parley_skill` namespace at the selection's
   line(s). `diag_display`'s `virtual_lines{current_line=true}` reveals it (the
   cursor is parked on the selection's first line).

## Pure core vs IO shell (ARCH-PURE)

- **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
  `context_for_selection`, `format_definition`.
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
  each turn); line-granular anchor (not a word-exact underline); implicit
  dismissal (cursor-region auto-hide + next-lookup clear).

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
