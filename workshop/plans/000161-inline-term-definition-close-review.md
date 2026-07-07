# Boundary Review — parley.nvim#161 (whole-issue close)

| field | value |
|-------|-------|
| issue | 161 — Inline term definition on visual selection |
| repo | parley.nvim |
| issue file | workshop/issues/000161-inline-term-definition.md |
| boundary | whole-issue close |
| milestone | — |
| window | ca6aac8cb09132a0a121dc1259af19311ff6e06d..HEAD |
| command | sdlc close --issue 161 |
| reviewer | claude |
| timestamp | 2026-07-06T23:14:16-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I have enough to finalize. I traced the DRY refactor line-by-line, verified every Core-concepts row against the code, confirmed the visibility mechanism (`diag_display.set(true)` at setup, `init.lua:776`), and independently ran the specs: define unit (10), define integration (11), drill_in (108), keybindings (20), chat_respond (29) — all green — plus luacheck clean on all 7 changed files.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The #161 inline-term-definition boundary is correct, well-factored, and independently test-verified — pure core in `define.lua` cleanly split from the `define_visual`/`render_definition` IO shell, the `slice_selection` DRY refactor of `drill_in_visual` is byte-faithful (I traced every branch and the 108 drill_in tests stay green), and the web-search path is genuinely wired (unforced `emit_definition` + honored `:ToggleWebSearch`, asserted at the payload level). No correctness bugs, no silent error-swallowing, no Core-concepts/table drift. The only thing standing between this and a clean SHIP is a documentation gate: the new user-facing visual `<M-CR>` gesture isn't reflected in README.md. That's non-blocking at the gate, so FIX-THEN-SHIP.

### 1. Strengths (confirmed-good ground)

- **ARCH-DRY refactor is faithful, not just plausible.** `drill_in_visual` now calls `define.slice_selection(lines_in_range, 1, sc-1, er-sr+1, ec-1)` (`init.lua:1557`). I traced single-line and multi-line branches against the original inline logic (including the retained `ec` clamp at `init.lua:1549`) — behavior is identical, and `tests/unit/drill_in_spec.lua` (108 cases) passes. One slice implementation shared by two callers.
- **ARCH-PURE textbook.** `slice_selection`/`context_for_selection`/`format_definition` (`define.lua`) are deterministic table/string functions, unit-tested with synthetic `parsed_chat` + injected finder — no buffer, no exec. The Anthropic seam is exercised via the process-level SSE fake (`define_spec.lua`), not function mocks.
- **`emit_definition` uses `self_paginates = true`, not the `kind="write"` shortcut.** This correctly suppresses pager `offset/limit` injection (`is_pageable`, `types.lua:98`) *without* mislabeling an output tool as a writer — the honest choice, and it's pinned by the "does not advertise pager params" test.
- **`skill_invoke` seams are minimal and backward-safe.** `opts.no_reload` gates both the pre-query `silent write` (`skill_invoke.lua:135`) and the on-exit reload (`:234`); `opts.document or original` (`:156`) defaults to prior behavior when absent. The no-write-on-dirty-buffer test is a real behavioral assertion (file bytes unchanged + `&modified` still true), exactly the kind that catches a draft-persistence regression.
- **Web-toggle test hits the real dispatcher** (`prepare_payload(..., {"emit_definition"})` with `_state.web_search` on/off), so ARCH-PURPOSE is verified against production code, not a restated constant.

### 2. Critical findings

None.

### 3. Important findings

- **README.md not updated for the new visual `<M-CR>` define gesture** (Docs update gate). `README.md:112–125` curates chat shortcuts (`<C-g><C-g>` respond, `<C-g>i` fork, …) but has no entry for "visual-select + `<M-CR>` → inline definition," nor its `:ToggleWebSearch` interaction. atlas *is* updated (`atlas/chat/inline_define.md` + index + traceability), so this is the lone doc gap. *Fix:* add one bullet in the keybindings list, e.g. `` - `<M-CR>` (visual) inline term definition — grey pop-under, honors `:ToggleWebSearch` ``. (Noted: the README list is already non-exhaustive — it also omits `<M-q>` drill-in — but the gate flags new keybinding surface specifically.)

- **The keybinding-split test hand-mirrors the callback table instead of exercising the real `prep_chat` wiring** (`tests/integration/define_spec.lua:279–329`). It builds a local `callbacks = { chat_define = { v=define, … } }` and feeds it to `register_buffer`, so it verifies the config split (real: `<M-CR>` only in `chat_shortcut_define`, `<C-g><C-g>` only in `chat_shortcut_respond`) and `register_buffer`'s per-mode dispatch — but **not** that the production IIFE at `init.lua:2054` actually returns `{ n=respond, i=respond, v=define_v, x=define_v }` keyed under id `"chat_define"`. The plan's own implementer note warns a key/id mismatch "silently no-ops the binding"; that exact failure mode is invisible to this test. Wiring is in fact correct (I verified id/config_key/`callbacks[entry.id]` all agree), but the regression guard is weaker than it reads. *Fix (cheap):* assert `nvim_buf_get_keymap` after a real `prep_chat`, or at minimum pull the real callback table out of the prep path rather than re-declaring it.

### 4. Minor findings

- `make_respond_cb("ChatRespond")` is constructed twice — once for `chat_respond` (`init.lua:2052`) and again inside the `chat_define` IIFE (`:2055`). Reuse one instance for both to avoid the parallel closure set.
- `render_definition` anchors the diagnostic only to the selection's first line (`end_lnum = sel_line0`, `init.lua:1619`) even for multi-line selections. Consistent with the documented "line-granular anchor" v1 limitation, not a bug.
- The plan's Task 10 Step 4 manual-acceptance steps (visible pop-under, web-cited obscure term, draft-not-written) aren't recorded in `## Log`. The visibility mechanism is reliable — `diag_display.set(true)` runs at `setup()` (`init.lua:776`), applying `virtual_lines{current_line=true}` to the `parley_skill` namespace session-wide — but the record is missing.

### 5. Test coverage notes

- Coverage is strong on the risk surface: pure core (unit, no IO), no-reload/no-write, document-override, no-tool-call graceful no-op, empty/whitespace no-op, registration, and the web-toggle payload all have real assertions. Independently re-ran: define unit 10/0/0, define integration 11/0/0, drill_in 108/0/0, keybindings 20/0/0, chat_respond 29/0/0.
- Gaps: (a) the prep_chat binding wiring itself (Important #2 above); (b) actual *visibility* of the rendered `virtual_lines` extmark — the integration test asserts diagnostic *presence*, not that it renders (a deliberate, documented downgrade), which shifts the true visibility gate to the un-recorded manual step.

### 6. Architectural notes for upcoming work

- **ARCH-DRY / ARCH-PURE / ARCH-PURPOSE all pass.** For v2 (stacking multiple definitions), the shared `parley_skill` namespace + `clear_decorations` reset on every `invoke` (`skill_invoke.lua:181`) is the constraint to lift first — a dedicated `parley_define` namespace also resolves the documented review/define coexistence risk in one move.
- Two `find_exchange_at_line` implementations coexist (`chat_parser.lua:144` returns `idx`; `init.lua:3156` returns `idx, component`). `context_for_selection` uses only the first value so it's safe with either, but this pre-existing duplication is a latent DRY item for a future consolidation — not introduced here.

### 7. Plan revision recommendations

None required — the plan still matches the code (Core concepts table, component list, and seams are all delivered as written). Optionally, when README is updated, tick the closing that the Docs gate is satisfied; and record the Task 10 Step 4 manual-acceptance outcome in `## Log` so the visibility gate has a durable record.
