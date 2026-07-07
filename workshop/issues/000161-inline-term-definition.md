---
id: 000161
status: working
deps: []
github_issue:
created: 2026-07-06
updated: 2026-07-06
estimate_hours:
started: 2026-07-06T17:53:46-07:00
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
   definition: string}`; **`kind = "write"`** so the pager `offset`/`limit`
   params are *not* injected (`is_pageable`, `tools/init.lua:35-66`); no-op
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
   the selection's first line** after render so it shows immediately.
5. **`skill_invoke` generalizations (two small seams):**
   - **`opts.no_reload` (net-new, the important one):** `invoke` currently does
     a `silent write` of an unsaved buffer (`skill_invoke.lua:133-137`) and an
     unconditional `:edit!` reload on exit (`skill_invoke.lua:230`). For a
     read-only lookup that would persist the user's in-progress prompt and force
     a reload. Gate write+reload on an actual edit having occurred (skip when
     no `propose_edits` in `calls`), exposed as `opts.no_reload` (or
     `opts.readonly`). Default behavior unchanged.
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

## Plan

- [ ]

## Log

### 2026-07-06
