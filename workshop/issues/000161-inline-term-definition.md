---
id: 000161
status: codecomplete
deps: []
github_issue:
created: 2026-07-06
updated: 2026-07-07
estimate_hours: 2.85
started: 2026-07-06T17:53:46-07:00
actual_hours: 6.42
---

# Inline term definition on visual selection

## Problem

While reading a parley chat, the user hits jargon they don't know (e.g. "ASIN"
in an ad-tech reply). Getting a definition today means either breaking flow to
search elsewhere, or the two existing in-chat moves — both of which are
heavier than the need:

- **Branch ref** (`<C-g>i`, `init.lua:1899`) spawns a *child chat file* whose
  topic is `what is "<phrase>"`. Answers in a separate buffer — a full detour.
- **Drill-in** (`<M-q>`, `init.lua:1537`) wraps the selection as `🤖<T>[]` and
  gathers it into the **next full turn** on respond — a whole conversational
  turn, not a scoped lookup.

There is no lightweight "define this phrase, inline, right here" gesture. The
want is: select a phrase → one keystroke → a concise definition appears
attached to the phrase, without touching the transcript or spending a turn.

## Spec

**Behavior.** In a chat buffer, visually select a phrase and press `<M-CR>`. A
headless one-shot LLM call returns a concise (1–3 sentence) definition of the
phrase *as used in its surrounding context*, rendered as grey `virtual_lines`
under the phrase's line(s). The definition is **ephemeral** — a `vim.diagnostic`
entry, never written into the chat file. It auto-shows when the cursor is on the
phrase's line(s) (the existing `diag_display` cursor-region behavior) and
auto-hides otherwise; the next lookup clears it (no explicit dismiss binding in
v1 — see Conscious v1 limitations).

**Knowledge source.** The call is unforced (`tool_choice = auto`), so when the
global `:ToggleWebSearch` state is on the model may use the Anthropic
server-side `web_search` tool for unfamiliar/fresh terms before answering;
otherwise it answers from model knowledge (fast). This "define honors the
existing global web toggle" is zero new wiring — the anthropic adapter already
injects the server web tools gated on `parley._state.web_search`
(`providers.lua:446`) and the dispatcher appends them without clobbering client
tools (`dispatcher.lua:118`).

### Design decisions

- **Output = ephemeral diagnostic**, not persisted text. Chosen over a
  persisted `🤖<T>{def}` marker or a blockquote note: keeps the transcript
  clean; the need is transient (read, understand, move on). Reuses the review
  skill's inline `virtual_lines` render (`diag_display.lua:21`).
- **Trigger = visual `<M-CR>`, via a registry restructure (not a free rebind).**
  `chat_shortcut_respond` is a *single* registry entry binding both
  `<C-g><C-g>` and `<M-CR>` across `{n,i,v,x}` to one per-*mode* callback
  (`keybinding_registry.lua:470-479`, `1065-1091`; `make_respond_cb`,
  `init.lua:1865-1882`) — there is **no per-(mode,key) dispatch**, so visual
  `<M-CR>` cannot be split off inside that entry. The structural change:
  **(a)** drop `<M-CR>` from `chat_shortcut_respond`'s key list (leaving
  `{ "<C-g><C-g>" }`); **(b)** add a **new** registry entry
  `chat_shortcut_define` bound to `<M-CR>` across `{n,i,v,x}` with a per-mode
  callback table `{ n = respond, i = respond, v = define_visual, x =
  define_visual }`. Result: visual `<C-g><C-g>` stays respond (the line-scoped
  resubmit, `chat_respond.lua:1238`, is **preserved**); normal/insert `<M-CR>`
  stays respond; only visual `<M-CR>` routes to `define_visual`. The Plan and
  Done-when own this restructure.
- **Do not reuse the respond `'<,'>` range path.** That path passes only a
  *line range* (`init.lua:1867`) and discards the character selection; a
  mid-sentence phrase needs the characters. A dedicated visual callback reads
  `getpos("'<"/"'>")` and extracts the substring, mirroring `drill_in_visual`
  (`init.lua:1537-1564`).
- **Agent path = a `define` skill through `skill_invoke`**, not a bespoke
  dispatcher call — consistent with how `review` runs; reuses the progress bar,
  agent resolution, and tool-use plumbing that `skill_invoke.invoke` owns.
- **Structured output via an unforced `emit_definition` tool.** Forcing a tool
  would preclude web search in the same turn (`tool_choice` forces one action).
  Unforced + a firm system prompt is reliable for a one-field tool; a re-trigger
  is cheap, and a text-reply fallback can be added later if ever needed.
- **Bounded context, not the whole buffer.** `skill_invoke` defaults the user
  message to the *entire* buffer (`skill_invoke.lua:~152` → `build_invocation`,
  `skill_assembly.lua:43`). For a quick lookup that is wasteful and cuts against
  "quickly"; we send the phrase's **enclosing exchange** (pinned in Component 1)
  via the `opts.document` override, falling back to the whole buffer.

### Components

1. **`define_visual(buf)`** (in `init.lua`, wired like `drill_in_visual`) —
   reads the visual selection via `getpos`, extracts the phrase substring, and
   **guards an empty/whitespace-only selection** (mirror `drill_in_visual`,
   `init.lua:1566-1569`). It then computes a **bounded context window** and
   calls `skill_invoke.invoke(buf, define_manifest, {phrase=…},
   {document=context, on_done=render, no_reload=true})`.
   - **Context window is pinned (not "paragraph/exchange"):** the *enclosing
     exchange* of the selection, sliced from the existing chat parse
     (`parse_chat` + `find_exchange_at_line`) — question + answer lines of the
     exchange the selection sits in. Fallback to the **whole buffer** when the
     selection isn't inside a parsed exchange (e.g. the chat header). The pure
     helper is `(parsed_chat, sel_line) → context_lines` (unit-tested); it
     reuses tested parsing rather than a new fuzzy paragraph rule.
2. **`define` skill** — `lua/parley/skills/define/init.lua` (+ `SKILL.md`).
   Auto-discovered by the disk provider (`skill_providers.lua:95`); no registry
   edit. Manifest: `name/description/scope/activation`, `tools =
   {"emit_definition"}`, **no `force_tool`**, `source(ctx)` folds
   `ctx.args.phrase` into the system prompt (concise definition; use web_search
   if unsure; always call `emit_definition`).
3. **`emit_definition` tool** — `lua/parley/tools/builtin/emit_definition.lua`
   + an entry in `BUILTIN_NAMES` (`tools/init.lua`). Schema `{term: string,
   definition: string}`; **`self_paginates = true`** (honest for an output-only
   tool) so the pager `offset`/`limit` params are *not* injected (`is_pageable`,
   `tools/init.lua:35-66`; `kind="write"` also suppresses them but mislabels it
   a writer); no-op
   `execute` (the value is carried in the tool-call args for `on_done`). This is
   the one central-list edit; registration is **mandatory** — `tools_registry.
   select` *raises* on an unknown name (`tools/init.lua:147`), so a forgotten
   registration hard-errors every define invoke at payload build (covered by a
   registration test).
4. **Render (`on_done`)** — **guards `#calls == 0`** first: because the call is
   unforced, "no tool call" is a live path (`skill_invoke` still fires `on_done`
   with `calls = {}`, `skill_invoke.lua:243-263`), so the render must no-op (or
   flash "no definition") rather than deref `calls[1]`. Otherwise it reads
   `result.calls[1].input = {term, definition}`, formats `TERM — definition`
   (wrapped via `skill_render.wrap`), and places one INFO diagnostic at the
   selection's line range by calling `vim.diagnostic.set(skill_render.
   diag_namespace(), …)` **directly** — `attach_diagnostics` is byte-offset/
   edit-shaped (`skill_render.lua:98-123`) and can't take an explicit line
   range, so a small line-range setter is net-new (a thin `skill_render`
   helper or an inline `vim.diagnostic.set`). Since `diag_display` only shows
   the entry when the cursor is on the phrase's line(s)
   (`virtual_lines{current_line=true}`), `define_visual` **places the cursor on
   the selection's first line** after render so it shows immediately. Watch-item:
   `on_done` runs async (`vim.schedule`) and sets the diagnostic *after* the
   cursor is parked, so no `CursorMoved` fires — the render may need to nudge
   `diag_display`/redraw to reveal it; exercise this in the integration test.
5. **`skill_invoke` generalizations (two small seams):**
   - **`opts.no_reload` (net-new, the important one):** `invoke` writes a
     *modified* buffer before the query (`skill_invoke.lua:133-137`, gated only
     on `vim.bo.modified`) and does an **unconditional** `:edit!` reload on exit
     (`skill_invoke.lua:230`). For a read-only lookup that would persist the
     user's in-progress prompt and force a reload. Since the pre-query write
     runs *before* any tool call exists, gate **both** halves purely on the
     caller's `opts.no_reload` flag (not on inspecting `calls`), which
     `define_visual` passes. Default behavior unchanged when the flag is absent.
   - **`opts.document` (already supported):** `build_invocation` already uses
     `opts.document` for the user message (`skill_assembly.lua:43`); the only
     thread needed is `document = opts.document or original` at the invoke call
     site (`skill_invoke.lua:~152`) — no `build_invocation` edit.

### Conscious v1 limitations

- **One definition at a time.** `invoke` resets the whole `parley_skill`
  namespace at the start of each exchange (`skill_invoke.lua:177`), so a new
  lookup clears the previous one. Acceptable for read-and-move-on; a dedicated
  namespace for stacking is a possible v2.
- **Line-granular anchor**, not a word-exact underline — reuses the existing
  render. A char-span extmark render is a possible v2.
- **Shared-namespace coexistence.** If *review* is ever run on the same chat
  buffer, it shares the `parley_skill` namespace and its projection watcher
  would capture the define diagnostic. Rare for chat buffers; a dedicated
  namespace resolves it if it ever bites.
- **Dismissal is implicit.** No dedicated dismiss binding in v1: the diagnostic
  auto-hides when the cursor leaves the phrase's line(s), and the next lookup
  clears it (namespace reset). `skill_render.dismiss` remains available if we
  later want an explicit key.

### Testing

- **Unit** (pure): the context extractor (`(parsed_chat, sel_line) →
  context_lines`, incl. the whole-buffer fallback); the render formatter
  (`{term, definition} → wrapped message`).
- **Integration**:
  - A process-level fake exchange (à la
    `tests/integration/skill_invoke_review_spec.lua`) returning an
    `emit_definition` tool-call → assert the INFO diagnostic lands on the
    selection's line range on the `parley_skill` namespace.
  - The **no-tool-call** path (fake exchange returns `calls = {}`) → render
    no-ops, no error.
  - **No-write assertion**: a define invoke on a dirty buffer does **not**
    write the file or `:edit!`-reload it (`opts.no_reload`).
  - **`emit_definition` registration**: the tool is in `BUILTIN_NAMES` and
    `tools_registry.select({"emit_definition"})` resolves without raising.
  - **Web-toggle payload** (deterministic, per I4): with
    `parley._state.web_search = true` the assembled anthropic payload contains
    the `web_search` server tool; with it false it does not.
- **Manual**: select `ASIN` in a chat → `<M-CR>` → concise definition appears
  below the line; `:ToggleWebSearch` on + an obscure term → definition (model
  may cite a web source); visual `<C-g><C-g>` still line-scopes a resubmit.

## Done when

- Visually selecting a phrase in a chat buffer and pressing `<M-CR>` renders a
  concise, context-aware definition as an ephemeral inline `virtual_lines`
  diagnostic under the phrase, written nowhere in the chat file; the cursor is
  placed so it shows immediately. An empty/whitespace-only selection is a no-op.
- The define invoke does **not** save or `:edit!`-reload the chat buffer (no
  side effects on an in-progress prompt).
- A returned response with no `emit_definition` call is handled gracefully (no
  error; no stale diagnostic).
- **Web availability tracks the global toggle:** with `:ToggleWebSearch` on the
  define payload carries the server `web_search` tool (so the model *can* search
  unfamiliar terms); with it off it does not (model knowledge only).
- **Keybinding restructure landed:** `<M-CR>` split into its own registry entry;
  visual `<C-g><C-g>` still performs the line-scoped resubmit (nothing lost);
  normal/insert `<M-CR>` is unchanged.
- The `define` skill is auto-discovered (no registry edit) and `emit_definition`
  is registered in `BUILTIN_NAMES`.
- Unit + integration tests per the Testing section pass; `make test` green.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim            design=1.0 impl=0.36
item: skill-or-dispatcher   design=0.3 impl=0.12
item: atlas-docs            design=0.1 impl=0.04
item: milestone-review      design=0.0 impl=0.12
item: lua-neovim            design=0.3 impl=0.25
design-buffer: 0.15
total: 2.85
```

(The second `lua-neovim` item is the R1 delta — highlight + bracket-anchored
undo; see `## Revisions`.)

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*

Decomposition: the core is a single focused **`lua-neovim`** feature (pure
`define.lua` trio + `define_visual`/render IO shell + the keybinding-registry
restructure + the `skill_invoke` `no_reload`/`document` seams); the `define`
skill + `emit_definition` tool are one **`skill-or-dispatcher`**; plus
**`atlas-docs`** and one close-boundary **`milestone-review`**. Impl written at
40% of the v2 ranges (v3.1) and picked lower-end — recent parley Lua closes
(#144, #147) landed ~0.6× their v3.1 estimate. Design carries a +15% buffer
(thorough plan doc exists).

## Plan

- [x] Implement per `workshop/plans/000161-inline-term-definition-plan.md`
      (Tasks 1–10; single-pass, plain checkboxes — one review boundary at close).

## Log


- 2026-07-07: closed — R1 (highlight + bracket-anchored undo): make test green — lint 0/0 (244 files), all unit+integration+ARCH pass. define_spec unit: bracket_edit (single/multi-line/clamp). define_spec integration: brackets the term ([ASIN]) + whole-line DiffChange highlight + diagnostic on the line; u reverts the bracket and clears both decorations (projection), C-r restores them; a no-emit_definition response leaves no bracket; plus the prior 12 (registration, discovery, no_reload, document, web-toggle, keybinding real prep_chat wiring). ARCH buffer_mutation green (bracket via nvim_buf_set_lines, not set_text). Undo/redo reuses review projection (record_empty_for + record + ensure_watch). Live-LLM/web manual check still deferred (no API key); wiring covered by faked-exchange + payload tests.; review verdict: FIX-THEN-SHIP
### 2026-07-06
- 2026-07-06: closed — make test green: lint 0/0 (244 files), all unit+integration pass. tests/unit/define_spec.lua (slice/context/format pure). tests/integration/define_spec.lua: emit_definition registration+no-pager; define skill discovery+source; skill_invoke no_reload + document override; web_search in payload iff :ToggleWebSearch; define_visual end-to-end via faked emit_definition SSE -> INFO diagnostic at selection line; no-tool + whitespace no-ops; keybinding split (visual <M-CR>->define, <C-g><C-g>->respond, n/i->respond, no double-bind). drill_in_spec(108)+chat_respond_spec(29) green after ARCH-DRY slice refactor. Anthropic via process-level SSE fake; live-LLM/web manual check deferred (needs API key), wiring covered by payload+faked-exchange tests.; review verdict: FIX-THEN-SHIP

- Brainstorm → spec (2 fresh-eyes review passes, Approved) → durable plan
  `workshop/plans/000161-inline-term-definition-plan.md` (2 fresh-eyes review
  passes, Approved). Estimate 2.25h via estimate-logic-v3.1 (Method A).
- Design decisions locked with the operator: ephemeral diagnostic output;
  visual `<M-CR>` (keybinding-registry split, visual `<C-g><C-g>` keeps
  scoped-resubmit); `define` skill via `skill_invoke` with an **unforced**
  `emit_definition` tool so the server-side `web_search` (honoring the existing
  `:ToggleWebSearch`) can run; `opts.no_reload` so the read-only lookup doesn't
  save/reload the chat buffer.
- `sdlc change-code` plan-quality judge: **executable as-written**, ARCH-textbook
  (PURE/DRY/PURPOSE all met); 3 INFO findings, all non-blocking. #1 (cursor-reveal
  timing) folded into Task 7 (test asserts visibility; explicit reveal fallback).
  #2 (estimate optimism) = acknowledged derived-estimate risk, not a defect.
  #3 (drill_in DRY refactor) = already guarded as a droppable side-quest.
  Re-entered via `--no-judge` (judge already ran; structural + estimate gates
  still enforced).
- **Implemented** Tasks 1–10 (TDD, per-task commits). `make test` green (lint
  0/0 in 244 files; all unit + integration incl. `tests/{unit,integration}/
  define_spec.lua`). ARCH-PURE: pure `define.lua` trio unit-tested with plain
  tables; thin `define_visual`/`render_definition` IO shell; Anthropic exercised
  via the process-level SSE fake. ARCH-DRY: `slice_selection` shared with
  `drill_in_visual`. ARCH-PURPOSE: web path delivered (asserted at payload level).
- Discoveries (plan sketches were starting pointers): `skill_registry.current()`
  returns a **registry object** `{get,names,all}`, not a list; `parse_chat` reads
  live `M.config` so the integration spec calls `parley.setup()` (like
  `chat_respond_spec`); Vim **normalizes `'<`/`'>` ordering**, so the empty-
  selection test uses a real whitespace selection, not reversed marks;
  `prepare_payload` short-circuits on a **string** model, so the web-toggle test
  passes a model **table** `{model=…}`; tool contract is `input_schema`/`handler`
  with `self_paginates=true`.
- Pre-existing flakiness (NOT this change): `chat_respond_spec`'s "redo drift"
  test flakes under parallel load (passes 3/3 in isolation); an `E739` mkdir
  race on the shared `.test-xdg` under `JOBS=8` was triggered by a leftover test
  dir — cleaned (the dirs are gitignored). A fresh `make test` is green.
- **Boundary review: `FIX-THEN-SHIP`** (high confidence; no Critical, no
  correctness bugs; ARCH all pass; sidecar
  `workshop/plans/000161-inline-term-definition-close-review.md`). Addressed
  before ship: **(Important)** README updated with the visual `<M-CR>` define
  gesture; **(Important)** added a **real `prep_chat` wiring** test
  (`nvim_buf_get_keymap`/`maparg` on a real chat buffer) so a `chat_define`
  id/key mismatch can't silently no-op — the hand-mirrored test alone didn't
  guard it; **(Minor)** `make_respond_cb("ChatRespond")` now built once and
  shared by `chat_respond` + `chat_define`. Visibility gate: `virtual_lines`
  reveal relies on `diag_display.set(true)` at `setup()` (`init.lua:776`); the
  real-wiring + faked-exchange tests cover the path — a **live** LLM/web-search
  smoke test is deferred (no API key in CI; drive it post-merge: select a term
  → `<M-CR>`). Deferred v2 (noted by review): a dedicated `parley_define`
  namespace to allow stacking multiple definitions + isolate from review.

## Revisions

### R1 — 2026-07-07 — highlight + undoable via bracket anchor

**Reason.** Operator smoke-test feedback: (1) the selected term should be
**highlighted** with review's scheme when `<M-CR>` fires; (2) the highlight +
diagnostic should be **undoable** (`u`).

**Delta — refines the "ephemeral / nothing written" decision.** Native `u`
reverts *text*, not decorations (`projection.lua` header). Review's decorations
are undoable only because a review round edits text and a `TextChanged`
projection watcher re-renders them per content-hash. Define changed no text, so
`u` had nothing to grab. Resolution (operator chose the minimal-footprint
option): on a successful lookup, `<M-CR>` wraps the selected phrase in a
reference bracket `[term]` — one small text change that (a) anchors the
highlight and (b) gives `u` a real edit to revert. The **definition text stays
ephemeral** (diagnostic only, never saved).

**Mechanism (reuses review machinery, ARCH-DRY):**
- **Bracket in `on_done`, not up front.** `skill_invoke.invoke` clears the
  decoration namespaces at exchange start (`skill_invoke.lua:181`), so the
  highlight must be set *after* the turn. Also, bracketing only on success means
  no orphan bracket when the model returns no `emit_definition`. Flow: fire the
  read-only turn (progress bar = feedback) → in `on_done`, if a definition came
  back, capture `original` (pre-bracket content), apply the bracket as **one**
  `nvim_buf_set_text` (single undo entry), set the highlight + diagnostic, then
  record the projection states.
- **Highlight = whole-line `DiffChange`** on `skill_render`'s `parley_skill_hl`
  namespace (a new `skill_render.highlight_line(buf, lnum0)` helper). It must be
  whole-line: `skill_render.snapshot` captures highlights **line-granular**
  (`hl_lines` = line numbers) and `apply_snapshot` redraws whole-line — a
  column-precise span would not round-trip through undo/redo. Whole-line
  `DiffChange` is exactly review's scheme.
- **Undo coherence via `projection`** (`skills/review/projection.lua`): in
  `on_done`, `record_empty_for(buf, original)` (pre-bracket hash → empty),
  `record(buf)` (bracketed hash → highlight+diagnostic), `ensure_watch(buf)`.
  `u` reverts the bracket → watcher `project()` lands on `hash(original)` →
  `apply_snapshot(empty)` → highlight + diagnostic clear. `<C-r>` re-renders.
  Define already uses the same `parley_skill` / `parley_skill_hl` namespaces, so
  `snapshot` captures both decorations.
- **Guards:** if the buffer changed under the in-flight call (the stored span no
  longer holds the phrase), skip bracketing + notify (no mis-placed bracket).
  Bracket edit uses `no_reload` still (buffer edit, not a file write) so it
  stays a dirty, undoable change the operator can save or `u` away.

**New pure helper (ARCH-PURE):** `define.bracket_edit(lines, l1, c1, l2, c2) →
{srow, scol, erow, ecol, text}` — the `nvim_buf_set_text` coords (0-based) +
replacement text `"[" .. selected .. "]"`. Unit-tested; the IO (`set_text`,
highlight, projection) stays in the `on_done` shell.

**Tests (delta):** unit for `bracket_edit`; integration — after a faked
`emit_definition`, the line shows `[term]` + an hl-namespace highlight on that
line + the diagnostic; `u` restores `term` and clears both; `<C-r>` restores
them; a no-definition response leaves no bracket.

**Note:** the Spec's "never written into the chat file" / "nothing written"
lines above are superseded by R1 for the **bracket** (the definition text itself
is still never written). The atlas note is updated to match.

**Estimate delta:** +0.6h (one `lua-neovim` extension: pure `bracket_edit` +
`on_done` rework + projection wiring + `highlight_line` helper + tests). New
total 2.85h; see the updated `## Estimate` block. **Actual came in at 6.42h**
(ratio 0.4×) — the projection integration + an arch-guard detour (`nvim_buf_set_text`
is confined to `buffer_edit`, so the bracket routes through `nvim_buf_set_lines`
like `drill_in_visual`) cost more than the +0.6h estimate. Calibration data point.

**R1 boundary review: `FIX-THEN-SHIP`** (high confidence; no Critical, ARCH all
pass; sidecar updated). Addressed: **(Important)** added a real-`parse_chat`
regression guard for `context_for_selection`'s field access (was only tested
against a synthetic `parsed_chat` → a parser field rename would have silently
degraded define to whole-buffer context); **(Minor)** `render_definition` now
warns "no definition returned" instead of a silent no-op when the model omits
`emit_definition`; **(Minor)** `tools/init.lua` added to the traceability code
list. Deferred (cosmetic): `apply_snapshot` re-emits the diagnostic `source` as
`parley-skill` after a redo. Live LLM/web smoke test still pending the operator
(no API key in CI).
