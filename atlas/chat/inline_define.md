# Inline Term Definition

Select a phrase in a chat transcript, press **`<M-CR>`** (visual mode), and a
concise, context-aware definition appears as an inline diagnostic under the
phrase. The selected text stays in place and gets a markdown footnote reference
(`ASIN[^asin]`), while the definition is stored in a managed footnote footer at
the end of the chat transcript. Persisted managed footnotes are rehydrated into
diagnostics when any markdown buffer is entered or refreshed. The whole new
annotation is **undoable** — `u` reverts the footnote edit and clears both
decorations (see Undo below). For jargon you don't know (e.g. `ASIN`), it's a
one-keystroke lookup. Added in
[#161](../../workshop/issues/000161-inline-term-definition.md) (R1 added the
highlight/undo); [#166](../../workshop/issues/000166-visual-selection-definition-system-manages-footnote.md)
made the definition durable as a managed footnote; [#167](../../workshop/issues/000167-define-diagnostic-highlight-span.md)
narrowed the visible decoration to the selected term plus footnote reference;
[#172](../../workshop/issues/000172-markdown-footnote-diagnostics.md)
rehydrates persisted managed footnotes in all markdown buffers.

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
   in-flight call), then **(a)** adds a `[^id]` reference after the selected term
   and inserts/updates a final managed footnote footer via one buffer rewrite
   (`define.apply_definition_footnote`) — a single undo entry that anchors
   everything; **(b)** highlights the selected term/reference span with
   `DiffChange` (`skill_render.highlight_span`); **(c)** refreshes persisted
   footnote diagnostics (`skill_render.refresh_footnote_diagnostics`), which
   parses the managed footer and sets INFO `vim.diagnostic` entries on matching
   inline `term[^id]` spans (`define.format_definition` →
   `skill_render.format_diagnostic_message`) on the `parley_skill` namespace;
   **(d)** records the undo/redo projection states.
   `diag_display` opens a centered, non-focusable diagnostic float when the
   cursor is on the term/footnote anchor span. A no-`emit_definition` response
   leaves no footnote reference/footer.

## Undo (`u`) — reuses review's projection

Native `u` reverts *text*, not decorations. The footnote reference/footer rewrite
is the one text change, so `u` reverts it; the decorations are cleared/restored by review's
**projection watcher** (`skills/review/projection.lua`, #133 M5), which define
reuses: `render_definition` calls `projection.record_empty_for(buf, original)`
(pre-footnote hash → empty snapshot), `record(buf)` (footnoted hash → the
highlight + diagnostic), `ensure_watch(buf)`. Undoing the footnote edit lands on
the pre-footnote content-hash → the empty snapshot renders → both decorations clear;
`<C-r>` re-renders. `skill_render.snapshot`/`apply_snapshot` preserve span
highlights (`hl_spans`) and diagnostic `col`/`end_col`, while still accepting
legacy whole-line `hl_lines`. `set_applying` guards the edit so a prior define's
watcher doesn't mistake it for a user edit.

## Pure core vs IO shell (ARCH-PURE)

- **Pure** (`lua/parley/define.lua`, unit-tested with plain tables): `slice_selection`,
  `context_for_selection`, `format_definition`, `bracket_edit` (plans the `[term]`
  wrap as a legacy set_lines edit), `diagnostic_span_after_bracket` (legacy range
  mapping), `apply_definition_footnote` (durable footer transform), and
  `strip_definition_footnote_footer` / `footnote_diagnostics` (treat the first
  markdown footnote definition line as the managed footer boundary).
- **IO shell** (`lua/parley/init.lua`): `define_visual`, `render_definition`;
  `lua/parley/buffer_edit.lua` owns the full-buffer footnote rewrite;
  `lua/parley/skill_render.lua` publishes footnote diagnostics; and
  `lua/parley/highlighter.lua` refreshes them from chat and markdown lifecycle
  hooks.
- **External service** (Anthropic) exercised via the process-level fake reused
  from `skill_invoke_spec` (SSE tool-call injection).

## Managed Footnote Footer

The footer begins at the first markdown footnote definition line:

```markdown
[^asin]: Amazon Standard Identification Number.
```

Older define edits may include a standalone `---` separator immediately before
that first footnote definition; the stripper removes that optional separator
along with the footer, but the canonical boundary is the `[^id]: ...` line.
`chat_respond.build_messages` strips this managed footer from message strings
before LLM submission, so durable definitions do not become prompt context.
`define.footnote_diagnostics` uses the same footer detector to scan inline
references before the footer and produce diagnostics for each matching `[^id]`.

For persisted multi-word anchors, a footnote definition may start with a quoted
or backquoted display term:

```markdown
Advertising Cost of Sales[^acos]

[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.
```

On reload, `define.footnote_diagnostics` uses that leading display term to find
the nearest matching phrase before `[^acos]`; the resulting span drives both the
floating definition trigger and the rehydrated inline highlight. If the phrase is
not present before the reference, the diagnostic falls back to the historical
single-token span immediately before `[^id]`.

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

## Notes

- The fresh define highlight spans the selected text plus immediate `[^id]`
  reference; rehydrated diagnostics do not recreate the DiffChange highlight.
- `skill_render.refresh_footnote_diagnostics` owns only diagnostics tagged
  `parley-footnote` and preserves other `parley_skill` diagnostics, so review
  diagnostics are not cleared by markdown footnote refresh.
- A footnote diagnostic's Parley float auto-hides when the cursor leaves its
  term/footnote anchor span. The footnote persists in the file if saved.

## Key files

- `lua/parley/define.lua` — pure core (slice / context / format / footnote footer / diagnostics).
- `lua/parley/init.lua` — `define_visual`, `render_definition`, `chat_define` wiring.
- `lua/parley/highlighter.lua` — chat/markdown buffer lifecycle refresh hooks.
- `lua/parley/skill_render.lua` — footnote diagnostic refresh in the shared namespace.
- `lua/parley/chat_respond.lua` — strips managed footnote footer from LLM messages.
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
