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
phrase's line(s) (the existing `diag_display` cursor-region behavior) and is
dismissed via the existing `skill_render.dismiss`.

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
- **Trigger = visual `<M-CR>` only.** Rebinds *only* the visual-mode branch of
  `chat_shortcut_respond`. Visual `<C-g><C-g>` is left as respond, which
  **preserves** the line-scoped-resubmit that visual `<M-CR>` did today
  (`chat_respond.lua:1238`) — so no capability is lost. Normal/insert `<M-CR>`
  is unchanged.
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
- **Bounded context, not the whole buffer.** `skill_invoke` assembles the user
  message as the *entire* buffer (`skill_assembly.lua:41`). For a quick lookup
  that is wasteful and cuts against "quickly"; we send the phrase's enclosing
  paragraph/exchange via a small `opts.document` override.

### Components

1. **`define_visual(buf)`** (in `init.lua`, wired like `drill_in_visual`) —
   reads the visual selection, extracts the phrase + a **bounded context
   window**, calls `skill_invoke.invoke(buf, define_manifest, {phrase=…},
   {document=context, on_done=render})`. The context-window computation is a
   **pure** helper `(lines, sel_span) → context_text` (unit-tested).
2. **`define` skill** — `lua/parley/skills/define/init.lua` (+ `SKILL.md`).
   Auto-discovered by the disk provider (`skill_providers.lua:95`); no registry
   edit. Manifest: `name/description/scope/activation`, `tools =
   {"emit_definition"}`, **no `force_tool`**, `source(ctx)` folds
   `ctx.args.phrase` into the system prompt (concise definition; use web_search
   if unsure; always call `emit_definition`).
3. **`emit_definition` tool** — `lua/parley/tools/builtin/emit_definition.lua`
   + an entry in `BUILTIN_NAMES` (`tools/init.lua`). Schema `{term: string,
   definition: string}`; no-op `execute` (the value is carried in the tool-call
   args for `on_done`). This is the one central-list edit.
4. **Render (`on_done`)** — reads `result.calls[1].input = {term, definition}`
   (`skill_invoke.lua:254`), formats `TERM — definition` (wrapped via
   `skill_render.wrap`), and places one INFO `vim.diagnostic` on the
   `parley_skill` namespace (`skill_render.diag_namespace()`) at the selection's
   line range. `diag_display` shows it under the phrase.
5. **`opts.document` override** — small generalization (~3 lines) to
   `skill_invoke.invoke` / `skill_assembly.build_invocation` so a caller can
   supply the user-message document instead of the whole buffer. Default
   behavior (buffer text) unchanged when the override is absent.

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

### Testing

- **Unit** (pure): the context-window extractor (`(lines, span) → context`);
  the render formatter (`{term, definition} → wrapped message`).
- **Integration**: a process-level fake exchange (à la
  `tests/integration/skill_invoke_review_spec.lua`) that returns an
  `emit_definition` tool-call → assert the INFO diagnostic lands on the
  selection's line range on the `parley_skill` namespace.
- **Manual**: select `ASIN` in a chat → `<M-CR>` → concise definition appears
  below the line; `:ToggleWebSearch` on + an obscure term → web-sourced
  definition; visual `<C-g><C-g>` still line-scopes a resubmit.

## Done when

- Visually selecting a phrase in a chat buffer and pressing `<M-CR>` renders a
  concise, context-aware definition as an ephemeral inline `virtual_lines`
  diagnostic under the phrase, written nowhere in the chat file.
- With `:ToggleWebSearch` on, an unfamiliar term is defined using a server-side
  `web_search`; with it off, the definition comes from model knowledge.
- Visual `<C-g><C-g>` still performs the line-scoped resubmit (nothing lost);
  normal/insert `<M-CR>` is unchanged.
- The `define` skill is auto-discovered (no registry edit) and the
  `emit_definition` tool is registered.
- Unit tests cover the pure context-extractor and render formatter; an
  integration test with a faked `emit_definition` exchange asserts correct
  diagnostic placement. `make test` green.

## Plan

- [ ]

## Log

### 2026-07-06
