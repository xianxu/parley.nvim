# Document Review

Headless LLM-powered review workflow for markdown files. Users annotate
documents with `🤖[comment]` markers, then an agent rewrites the document
to address the comments — or run a **mode** (see Review Modes below) for a
whole-document pass that needs no markers at all.

**Run flow.** A *mode* run always proceeds, even with zero markers
(the no-marker general review). A legacy no-mode run still needs ≥1 ready `[]`
marker. Pending `{}` markers no longer **block** submission — ready markers are
processed, `{}` ones skipped, and pending markers surface via the **on-save**
quickfix (`BufWritePost`), not at submission. The resubmit loop re-runs only
while a *ready* marker remains and the ready count shrank, so a whole-doc mode
round is effectively one-shot (inserting `{}` findings is not "stuck"). Applied
edits are oriented by `DiffChange` highlights + INFO gutter diagnostics that
**ride** subsequent edits until the next round or an explicit dismiss; pure
deletions show only the gutter "why" (no highlight).

The same marker family is also used inside chat buffers for
[drill-in discussions](../chat/drill_in.md) (different keybindings + a chat-
side gather/strip on respond). The section parser is shared.

## Marker Syntax

Single marker `🤖`. Three section types:

- `<>` = quoted body (optional, at most one, must be the first slot)
- `[]` = human turns
- `{}` = agent turns

After an optional `<>`, `[]` and `{}` may appear in any order.

```
🤖[human comment]{agent question}[human reply]...
🤖{agent finding}[human response]{agent follow-up}...
🤖<the exact phrase>[fix this]
🤖<paragraph snippet>{suggested rewrite}
```

- Ready for agent = last section is `[]` (human spoke last)
- Pending (quickfix) = last section is non-empty `{}` (agent asked, needs human reply)
- Markers inside fenced code blocks are ignored
- `<text>` disambiguates "which text the marker refers to" — use it whenever the surrounding-text rule would be ambiguous (added in #123)
- `<>`/`[]`/`{}` sections may span **multiple lines**, each bounded to ~50 lines (per-section budget) so a stray opener can't swallow the document; `~D~` strike stays single-line (added in #125). `parse_markers` parses over the whole buffer joined (offset→line/col map) rather than line-by-line; `find_matching_bracket` takes an optional `{budget, is_excluded}` so the shared `_parse_marker_sections` (highlighter, drill_in) keeps its single-text behavior. Unterminated openers fall back to silent non-recognition.

## Keybindings (non-chat markdown only)

| Binding         | Action                                                          |
|-----------------|-----------------------------------------------------------------|
| `<M-q>` / `<C-g>q` | Insert `🤖<sel>[]` (visual) or `🤖[]` (normal/insert). Shared with chat — see [drill-in](../chat/drill_in.md). |
| `<M-a>`         | Accept the marker at cursor (rules below) |
| `<M-r>`         | Reject the marker at cursor (rules below)            |
| `<C-g>ve`       | Run the review skill (agent edits per ready markers, legacy no-mode) |
| `<C-g>vf`       | Open the review finder (jump to files with pending markers)     |
| `<M-s>`         | Open the **skill picker** (review is one of the skills) |
| `<M-CR>`        | Open the **review-mode menu** (mode selector + instruction editor; sticky-preselected) |

## Accepting and rejecting markers

A quoted `🤖<text>` anchor keeps its text on either action. A bare
`🤖{proposal}` inserts its text when accepted and disappears when rejected.
For `🤖~old~{new}` (or a single human replacement section), acceptance keeps
`new`, rejection keeps `old`; a bare strike accepts deletion. A strike with a
longer dialogue also accepts deletion because no single replacement is selected.
Unanchored commentary disappears on either action. These rules are implemented
by `drill_in.resolve` and tested with the shared marker parser.

## Review menu

`lua/parley/review_menu.lua` — a composite two-window float: a mode **selector**
on top (the focused window; selection = its cursor line, so `j`/`k`/arrows/mouse
move it natively; sticky-preselected to the last-used mode) + a multi-line
**instruction editor** below. `Tab`/`i` jump to the editor; in it `Enter` =
newline, `M-CR`/`C-s` submit, `Tab`/`Esc` return to the list; `Esc`/`C-c` cancel.
On submit it calls
`review.run_via_invoke(buf, { mode, instruction })`. Free-form mode requires a
non-empty instruction. Reuses `float_picker.compute_layout` for geometry (now
exported). The sidecar (`*.parley-journal.md`) is excluded from review
attachment (`is_journal_sidecar`). `<M-CR>` is free here — chat-respond's `<M-CR>`
is chat-buffer-only. The last-used mode is remembered only for the current session.

## Architecture

Review is implemented as a **skill** in the unified skill system (see the [skill system](../skills/skill-system.md)).

- **Skill module**: `lua/parley/skills/review/init.lua` — marker parsing, `run_via_invoke` (marker pre-check + resubmit), keybindings
- **System prompt**: `lua/parley/skills/review/SKILL.md`
- **Driver**: `lua/parley/skill_invoke.lua` — one tool-use exchange on the existing dispatcher, shared with other skills
- **Rendering**: `lua/parley/skill_render.lua` — diagnostics + edit highlights
- **Shim**: `lua/parley/review.lua` — backward-compatible re-exports for existing callers
- **Headless**: Direct API call, no chat buffer, no exchange model
- **Stateless**: Each submit sends full document; markers carry conversation history
- **Tool**: `propose_edits` tool with `{old_string, new_string, explain}` triples (forced via `tool_choice`)
- **Edits**: Applied to file on disk via the `propose_edits` builtin, buffer reloaded via `:edit!`
- **Feedback**: Highlights on edits (DiffChange), diagnostics from explain fields (INFO), quickfix for pending agent questions
- **Provider**: Requires a client tool wire: Anthropic or an OpenAI-compatible provider, including CLIProxyAPI routes. Direct Google AI has no wire. Agent choice follows the [skill agent cascade](../skills/skill-system.md).

## Review Modes

Review runs in a selectable **mode** (a stage of document construction). A mode is
a sub-markdown file `lua/parley/skills/review/modes/<name>.md` = YAML frontmatter
(behavior flags) + a prompt body. One skill owns all modes; there is no parallel
engine — the review skill's `source(ctx)` composes `SKILL.md ⊕ mode.body ⊕
mode.directives(flags) ⊕ operator-instruction`. No mode selected → base SKILL.md
(the legacy marker-only review).

- **`lua/parley/skills/review/mode.lua`** — `parse(content)` (PURE: frontmatter →
  `{name,scope,deletions,frontier,order,body}`), `directives(m)` (PURE: flags → prose
  the model obeys), and the thin IO seam `load(dir,name)`/`list(dir)` (sorted by
  `order` then name). Canonical name == file basename (kebab), so `load` resolves
  by the selected name; the menu prettifies for display.
- **Behavior flags:** `scope` (`whole-doc` | `markers-only`), `deletions`
  (`apply-with-gutter-why` | `propose-strike` | `apply`), `frontier` (`on` | `off`
  — when on, treat text above the topmost `🤖[]` as settled). Plus `order:` — the
  editorial-sequence position that orders the menu (developmental=1 … free-form=6).
- **Six shipped modes:** developmental, line-editing, copy-editing, proofreading,
  fact-check (inserts `🤖{}` findings only — no edits; resolution handed to the
  main agent), free-form (operator instruction governs).
- **`ctx.skill_dir` injection** (`skill_providers.lua`): the disk provider injects
  the skill's own absolute dir into `source(ctx)` (alongside `ctx.skill_md`) so the
  review skill reads its `modes/` subdir without re-deriving the path.

## Journal

Each review round is recorded to a Markdown sidecar beside the document,
`<doc>.parley-journal.md`. It records attributed diffs and rationale without
changing branches. The sidecar can be version-controlled with the document;
Parley does not commit it automatically. Native undo handles interactive text
changes, while the journal preserves a durable record across sessions.

- **`lua/parley/skills/review/journal.lua`** — PURE `serialize_entry` /
  `serialize_base` / `parse` / `diff` (`vim.diff`, unified) / `is_drift`
  (`vim.fn.sha256` compare), plus the thin IO seam `sidecar_path` / `read` /
  `append`. 4-backtick fences wrap the journal's own blocks so a 3-backtick code
  fence inside the doc or diff can't break parsing.
- **Per round** it stores: round number (derived), mode, side, ISO timestamp,
  content hash, rationale (the per-edit `explain`s), and the unified diff. Round 0
  is the base snapshot (written once, on the first round).
- **Wiring**: `skill_invoke`'s `on_done` payload carries `original` /
  `new_content` / `decorations` (pure-fed); review's `on_done` builds the entry
  and calls `journal.append` (skips no-op rounds + path-less buffers).
- **Drift**: `is_drift(recorded_hash, current)` detects an external edit (e.g.
  Claude Code resolving markers) since the last recorded round.
- **Not implemented**: durable "revert/show round N" (reconstruct via base +
  replayed diffs). The journal stores the **diff + rationale** per round, not a structured
  decoration set.

## Decoration projection — undo/redo coherence

nvim's undo reverts **text only**; review decorations are drawn once per round
and otherwise ride, so without help they go stale after an undo (esp. across the
round's `:edit!` reload). `lua/parley/skills/review/projection.lua` keeps style
coherent: a per-buffer record `{ content-hash → decoration snapshot }`, and on
each text change it **projects** the right style onto the current state —

- **undo/redo** lands on a recorded content-hash → re-render that snapshot (via
  `skill_render.snapshot`/`apply_snapshot`);
- a **novel forward edit** (manual tweak / `<M-a>` accept — behavior B) keeps the
  live decorations riding, and snapshots them under the new state so a later undo
  restores them.

A round records its **pre** state (base → empty style, so undoing across the
round clears it) and its **post** state (its decorations); records persist across
rounds for multi-round undo. `set_applying` suppresses the watcher during the
round's own reload; the watcher is attached lazily (only after the first round).
The decide rule (`projection.decide`) is pure. Session-scoped (matches nvim's
session-scoped undo); per-state snapshots aren't journaled.

## Diagnostic display

The edit "why" (the per-edit `explain`) is an INFO diagnostic on parley's
`parley_skill` namespace. `lua/parley/skills/review/diag_display.lua` controls how
it shows — scoped to that namespace, so the user's LSP/global diagnostics are
untouched. Default **on**: Parley's custom `parley/virtual_lines` diagnostic
handler renders a text-column virtual-line block headed `Diagnostics:` for the
current line. It avoids both gutter anchoring and Neovim's stock virtual-lines
indentation-by-diagnostic column, which can hide messages on long wrapped prose. The hard-wrapped why
(`skill_render.format_diagnostic_message`) **auto-expands below an edit when the
cursor is in that edit's region** (`attach_diagnostics` spans
`lnum..end_lnum`) and hides otherwise. `:ParleyShowDiagnostics` toggles it. The
built-in `]d`/`[d` (jump) and `<C-W>d` (float, wraps) still work on these
diagnostics because the underlying diagnostic spans remain unchanged. Composes
with decoration projection — re-renders on undo/redo.

The same controller also renders managed footnote diagnostics; those use a
centered non-focusable float instead of virtual lines, and show only while the
cursor is inside the term/`[^footnote]` diagnostic span.

## Progress bar

A review round runs without a chat buffer and shows a **detached progress
bar** — `lua/parley/progress.lua`, a floating bar pinned just above the
statusline with an animated spinner + message + elapsed seconds. It's a **general
reusable mechanism** (`progress.start/update/stop/is_active`, one active at a
time; pure `frame`/`format` + thin float/timer IO), not review-specific — review
is just its first user. `skill_invoke` starts it when the LLM query launches and
stops it on exit/abort/cancel (guarded by the same generation counter as the
in-flight cancel). Concurrency: triggering a review while one runs gives the
kill-or-cancel prompt (no two concurrent rounds).

## Config

```lua
review_agent = nil,             -- legacy optional pin; prefer skills config
review_highlight_duration = 2000, -- highlight fade time in ms
review_shortcut_edit   = { modes = { "n" }, shortcut = "<C-g>ve" },
review_shortcut_finder = { modes = { "n", "i" }, shortcut = "<C-g>vf" },
review_shortcut_menu   = { modes = { "n" }, shortcut = "<M-s>" },   -- skill picker
review_shortcut_next   = { modes = { "n", "i" }, shortcut = "<M-CR>" }, -- review-mode menu
-- Marker insertion: see drill_in_callbacks in lua/parley/init.lua
-- (shared <M-q> / <C-g>q binding)
```

## Key Files

- `lua/parley/skills/review/init.lua` — skill definition (+ `source(ctx)` mode composition, `mode` arg), marker parsing, `run_via_invoke` (marker pre-check + resubmit), keybindings
- `lua/parley/skills/review/mode.lua` — Mode parse/directives (PURE) + load/list IO seam
- `lua/parley/skills/review/modes/*.md` — the six review-mode prompt files
- `lua/parley/skills/review/journal.lua` — per-round journal: PURE serialize/parse/diff/drift + sidecar IO seam
- `lua/parley/review_menu.lua` — composite review-mode menu (selector + instruction editor); `<M-CR>`
- `lua/parley/skills/review/projection.lua` — decoration projection: re-render style on undo/redo per content-state
- `lua/parley/skills/review/diag_display.lua` — inline "why" display toggle (`:ParleyShowDiagnostics`, cursor-region auto-show)
- `lua/parley/progress.lua` — detached progress bar (general reusable long-op feedback; review is the first user)
- `lua/parley/skills/review/SKILL.md` — system prompt (light edit + heavy revision sections)
- `lua/parley/skill_invoke.lua` — the P2 driver (one tool-use exchange via the existing dispatcher)
- `lua/parley/skill_render.lua` — diagnostics + edit highlights
- `lua/parley/tools/builtin/propose_edits.lua` — batch edit-apply (inline `.parley-backup`)
- `lua/parley/review.lua` — backward-compatible shim
- `lua/parley/highlighter.lua` — `ParleyReviewUser`/`ParleyReviewAgent` groups
- `lua/parley/config.lua` — default keybindings and config
- `tests/unit/review_spec.lua` — unit tests for the marker parser
- `tests/integration/skill_invoke_review_spec.lua` — review's marker pre-check + resubmit
- `tests/unit/skill_edits_spec.lua` / `tests/unit/tools_builtin_propose_edits_spec.lua` — batch edit-apply
